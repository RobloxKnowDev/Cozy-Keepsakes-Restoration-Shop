local Assetservice = game:GetService("AssetService")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Tweenservice = game:GetService("TweenService")

local Cleaningconfig = require(Replicatedstorage.Shared.Config.Cleaning)
local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)
local Roundedtexture = require(Replicatedstorage.Shared.Utils.RoundedTexture)
local Facemapping = require(Replicatedstorage.Shared.Utils.FaceMapping)
local Stainlayout = require(Replicatedstorage.Shared.Utils.StainLayout)
local Surfacecast = require(Replicatedstorage.Shared.Utils.SurfaceCast)

local function Countcopies(Name: string): number
	local Count = 0
	for _, Child in ipairs(Replicatedstorage.Shared.Utils:GetChildren()) do
		if Child.Name == Name then
			Count += 1
		end
	end
	return Count
end

assert(
	Roundedtexture.GetShape and Roundedtexture.GetBounds and Roundedtexture.GetRowInset,
	string.format(
		"CleaningController: outdated RoundedTexture (%d copies in Shared.Utils, delete the duplicates in Studio)",
		Countcopies("RoundedTexture")
	)
)
assert(
	Facemapping.GetDecalPoint and Facemapping.TouchesDecal and Facemapping.ShowsDecal and Facemapping.GetBrushRadius,
	string.format(
		"CleaningController: outdated FaceMapping (%d copies in Shared.Utils, delete the duplicates in Studio)",
		Countcopies("FaceMapping")
	)
)

local Cleaningcontroller = { Name = "CleaningController", Priority = 9 }

local Cleaninterval = 0.075
local Liquidapplyinterval = 0.25
local Maxdirtstrokes = 8
local Dirtdecalnames = Cleaningconfig.DirtDecals
local Getdecalpoint = Facemapping.GetDecalPoint
local Cleanedfadeinfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Occlusionoffset = 0.02
local Occlusionlength = 64
local Activecaster = nil
local Activeobject = nil
local Activedirtstep = 0
local Activebrushradius = 0
local Stainkinds = {
	InkStain = { Kind = "Ink", Liquid = "HasSolvent", Clean = "CleanInk" },
	ScratchStain = { Kind = "Scratch", Liquid = "HasPolish", Clean = "CleanScratch" },
}

local function Getfacename(Localnormal: Vector3): string
	local Absolutex = math.abs(Localnormal.X)
	local Absolutey = math.abs(Localnormal.Y)
	local Absolutez = math.abs(Localnormal.Z)
	if Absolutex > Absolutey and Absolutex > Absolutez then
		return if Localnormal.X > 0 then "Right" else "Left"
	end
	if Absolutey > Absolutez then
		return if Localnormal.Y > 0 then "Top" else "Bottom"
	end
	return if Localnormal.Z > 0 then "Back" else "Front"
end

local function Isoccluded(Part: BasePart, Worldposition: Vector3, Face: Enum.NormalId): boolean
	local Direction = Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Face))
	return Activecaster:CastPart(Part, Worldposition + Direction * Occlusionoffset, Direction * Occlusionlength) ~= nil
end

local function Getdirtdecals(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): { Decal }
	local Decals = {}
	for _, Child in ipairs(Part:GetChildren()) do
		if
			Child:IsA("Decal")
			and Dirtdecalnames[Child.Name]
			and Facemapping.TouchesDecal(Child, Worldnormal)
			and (Facemapping.ShowsDecal(Child, Worldnormal) or not Isoccluded(Part, Worldposition, Child.Face))
		then
			table.insert(Decals, Child)
		end
	end
	return Decals
end

local Leftovers: { [Decal]: buffer } = {}
local Leftoverrequests: { [Decal]: number } = {}
local Leftoverinterval = 0.3
local Coveragegrid = Cleaningconfig.CoverageGrid
local Basefadestep = math.ceil(255 / Cleaningconfig.DirtPasses)
local Overlayimages: { [Decal]: EditableImage } = {}
local Overlaypending: { [Decal]: boolean } = {}
local Overlayscales: { [Decal]: Vector2 } = {}
local Overlaybudget = 56 * 1024 * 1024
local Preloadframebudget = 0.005
local Overlayradiusratio = 1 / 16
local Cottonscale = 4 / 3
local Brushscale = 1.5
local Toothbrushradius = Overlayradiusratio * Brushscale
local Stainsamplestep = 2
local Stainspotratio = 0.2
local Tickmarks: { [Decal]: buffer } = {}
local Lastfades: { [Decal]: { Tick: number, X: number, Y: number } } = {}
local Fadetick = 1
local Maxpendingpoints = 32
local Pingmovement = 0.002
local Dissolvekeep = { 0.45, 0.2, 0 }
local Dissolveinterval = 0.06
local Finishassist = Cleaningconfig.FinishAssist
local Staincanvassize = 512
local Stainsupersample = 2

type Pixelsource = { Pixels: buffer, Size: Vector2 }

type Stain = {
	Decal: Decal,
	Texture: ImageLabel,
	Layout: Stainlayout.Layout,
	Kind: string,
	Liquid: string,
	Clean: string,
	Canvas: Vector2,
	Radius: Vector2,
	Pixelminimum: Vector2,
	Pixelmaximum: Vector2,
	List: { Stain },
	Settled: boolean,
}

local Sourcepixels: { [string]: Pixelsource } = {}
local Sourceloading: { [string]: boolean } = {}
local Scaledpixels: { [string]: { Scale: number, Source: Pixelsource } } = {}
local Levelpixels: { [string]: { Image: string, Scale: number, Shrink: Vector2, Source: Pixelsource } } = {}
local Levelbudget = 16 * 1024 * 1024
local Stainsbypart: { [BasePart]: { Stain } } = {}
local Stainsbydecal: { [Decal]: Stain } = {}
local Surfacewaiting: { [SurfaceGui]: number } = {}
local Surfacefallback: { [SurfaceGui]: boolean } = {}
local Pendingstains: { [Decal]: { Vector2 } } = {}
local Pendingstainorder: { Decal } = {}
local Laststainpoints: { [Decal]: Vector2 } = {}
local Nostains: { Stain } = {}

export type StainCluster = {
	Decal: Decal,
	Center: Vector2,
	Spread: number,
	Radius: number,
	Scale: Vector2,
	Amount: number,
	Spot: number,
}

local function Applyoverlay(Decal: Decal, Created: EditableImage)
	Decal.TextureContent = Content.fromObject(Created)
	Overlayimages[Decal] = Created
	Overlayscales[Decal] = Vector2.one * math.min(Created.Size.X, Created.Size.Y)
	Decal.Destroying:Connect(function()
		Overlayimages[Decal] = nil
		Overlaypending[Decal] = nil
		Overlayscales[Decal] = nil
		Tickmarks[Decal] = nil
		Lastfades[Decal] = nil
		Created:Destroy()
	end)
end

local function Shrinkpixels(Source: Pixelsource, Scalex: number, Scaley: number): Pixelsource
	local Pixels = Source.Pixels
	local Sourcewidth, Sourceheight = Source.Size.X, Source.Size.Y
	local Width = math.max(math.floor(Sourcewidth * Scalex), 1)
	local Height = math.max(math.floor(Sourceheight * Scaley), 1)
	local Result = buffer.create(Width * Height * 4)
	local Minxs = table.create(Width, 0)
	local Maxxs = table.create(Width, 0)
	for X = 0, Width - 1 do
		Minxs[X + 1] = math.floor(X * Sourcewidth / Width)
		Maxxs[X + 1] = math.max(math.floor((X + 1) * Sourcewidth / Width) - 1, Minxs[X + 1])
	end
	local Started = os.clock()
	for Y = 0, Height - 1 do
		if os.clock() - Started > Preloadframebudget then
			task.wait()
			Started = os.clock()
		end
		local Miny = math.floor(Y * Sourceheight / Height)
		local Maxy = math.max(math.floor((Y + 1) * Sourceheight / Height) - 1, Miny)
		for X = 0, Width - 1 do
			local Minx = Minxs[X + 1]
			local Maxx = Maxxs[X + 1]
			local Best = Miny * Sourcewidth + Minx
			local Bestalpha = -1
			for Sourcey = Miny, Maxy do
				for Sourcex = Minx, Maxx do
					local Index = Sourcey * Sourcewidth + Sourcex
					local Alpha = buffer.readu8(Pixels, Index * 4 + 3)
					if Alpha > Bestalpha then
						Bestalpha = Alpha
						Best = Index
					end
				end
			end
			buffer.writeu32(Result, (Y * Width + X) * 4, buffer.readu32(Pixels, Best * 4))
		end
	end
	return { Pixels = Result, Size = Vector2.new(Width, Height) }
end

local function Loadsource(Image: string): Pixelsource?
	while Sourceloading[Image] do
		task.wait()
	end
	if not Sourcepixels[Image] then
		Sourceloading[Image] = true
		local Success, Result = pcall(function()
			local Editable = Assetservice:CreateEditableImageAsync(Content.fromUri(Image))
			local Source = { Pixels = Editable:ReadPixelsBuffer(Vector2.zero, Editable.Size), Size = Editable.Size }
			Editable:Destroy()
			return Source
		end)
		if Success then
			Sourcepixels[Image] = Result
		else
			warn("CleaningController: EditableImage failed for " .. Image .. ": " .. tostring(Result))
		end
		Sourceloading[Image] = nil
	end
	return Sourcepixels[Image]
end

local function Getscaled(Image: string, Source: Pixelsource, Scale: number): Pixelsource
	if Scale == 1 then
		return Source
	end
	local Cached = Scaledpixels[Image]
	if not Cached or Cached.Scale ~= Scale then
		Cached = { Scale = Scale, Source = Shrinkpixels(Source, Scale, Scale) }
		Scaledpixels[Image] = Cached
	end
	return Cached.Source
end

local function Levelkey(Image: string, Scale: number, Shrink: Vector2): string
	return Image .. "|" .. Scale .. "|" .. Shrink.X .. "|" .. Shrink.Y
end

local function Getlevel(Image: string, Scale: number, Base: Pixelsource, Shrink: Vector2): Pixelsource
	if Shrink == Vector2.one then
		return Base
	end
	local Key = Levelkey(Image, Scale, Shrink)
	local Cached = Levelpixels[Key]
	if Cached then
		return Cached.Source
	end
	local Parent, Parentshrink = Base, Vector2.one
	for _, Entry in pairs(Levelpixels) do
		if
			Entry.Image == Image
			and Entry.Scale == Scale
			and Entry.Shrink.X >= Shrink.X
			and Entry.Shrink.Y >= Shrink.Y
			and Entry.Shrink.X * Entry.Shrink.Y < Parentshrink.X * Parentshrink.Y
		then
			Parent, Parentshrink = Entry.Source, Entry.Shrink
		end
	end
	local Level = Shrinkpixels(Parent, Shrink.X / Parentshrink.X, Shrink.Y / Parentshrink.Y)
	Levelpixels[Key] = { Image = Image, Scale = Scale, Shrink = Shrink, Source = Level }
	return Level
end

local function Trimlevels(Keys: { [string]: boolean })
	local Bytes = 0
	for _, Entry in pairs(Levelpixels) do
		Bytes += buffer.len(Entry.Source.Pixels)
	end
	if Bytes <= Levelbudget then
		return
	end
	for Key in pairs(Levelpixels) do
		if not Keys[Key] then
			Levelpixels[Key] = nil
		end
	end
end

local function Settlesurface(Stain: Stain, Applied: boolean)
	if Stain.Settled then
		return
	end
	Stain.Settled = true
	local Surface = Stain.Layout.Surface
	if not Applied then
		Surfacefallback[Surface] = true
	end
	Surfacewaiting[Surface] -= 1
	if Surfacewaiting[Surface] == 0 and not Surfacefallback[Surface] then
		Surface.Enabled = false
		for Decal, Other in pairs(Stainsbydecal) do
			if Other.Layout.Surface == Surface and Overlayimages[Decal] then
				Decal.Transparency = Other.Texture.ImageTransparency
			end
		end
	end
end

local function Levelshrink(Size: number, Span: number): number
	if Span >= Size then
		return 1
	end
	return 2 ^ -math.floor(math.log(Size / Span, 2))
end

local function Planstain(Stain: Stain, Source: Pixelsource, Scale: number): (number, number, Vector2)
	local Width = math.max(math.round(Stain.Canvas.X * Scale), 1)
	local Height = math.max(math.round(Stain.Canvas.Y * Scale), 1)
	local Layout = Stain.Layout
	local Spanu = Vector2.new(Layout.Axisu.X * Width, Layout.Axisu.Y * Height).Magnitude
	local Spanv = Vector2.new(Layout.Axisv.X * Width, Layout.Axisv.Y * Height).Magnitude
	return Width, Height, Vector2.new(Levelshrink(Source.Size.X, Spanu), Levelshrink(Source.Size.Y, Spanv))
end

local function Shaperows(Texture: ImageLabel, Width: number, Height: number): ({ number }?, { number }?)
	local Shape = Roundedtexture.GetShape(Texture)
	if not Roundedtexture.IsCut(Shape) then
		return nil, nil
	end
	local Bounds = Roundedtexture.GetBounds(Width, Height, Shape)
	local Lows = table.create(Height, math.huge)
	local Highs = table.create(Height, -math.huge)
	for Y = 0, Height - 1 do
		local Rowinset = Roundedtexture.GetRowInset(Y + 0.5, Bounds)
		if Rowinset then
			Lows[Y + 1] = Bounds.Left + Rowinset - 0.5
			Highs[Y + 1] = Bounds.Right - Rowinset - 0.5
		end
	end
	return Lows, Highs
end

local function Composestain(Stain: Stain, Source: Pixelsource?, Scale: number)
	local Decal = Stain.Decal
	if not Decal.Parent or Decal:GetAttribute("Cleaned") == true then
		Overlaypending[Decal] = nil
		return
	end
	if not Source then
		Overlaypending[Decal] = false
		Settlesurface(Stain, false)
		return
	end
	local Width, Height, Shrink = Planstain(Stain, Source, Scale)
	local Level = Getlevel(Stain.Texture.Image, 1, Source, Shrink)
	if not Decal.Parent or Decal:GetAttribute("Cleaned") == true then
		Overlaypending[Decal] = nil
		return
	end
	local Success, Created = pcall(function()
		return Assetservice:CreateEditableImage({ Size = Vector2.new(Width, Height) })
	end)
	if not Success then
		Overlaypending[Decal] = false
		warn("CleaningController: EditableImage failed for " .. Decal:GetFullName() .. ": " .. tostring(Created))
		Settlesurface(Stain, false)
		return
	end
	local Layout = Stain.Layout
	local Minx = math.clamp(math.floor(Layout.Minimum.X * Width), 0, Width - 1)
	local Maxx = math.clamp(math.ceil(Layout.Maximum.X * Width) - 1, 0, Width - 1)
	local Miny = math.clamp(math.floor(Layout.Minimum.Y * Height), 0, Height - 1)
	local Maxy = math.clamp(math.ceil(Layout.Maximum.Y * Height) - 1, 0, Height - 1)
	local Regionwidth = Maxx - Minx + 1
	local Regionheight = Maxy - Miny + 1
	local Pixels = buffer.create(Regionwidth * Regionheight * 4)
	local Sourcewidth, Sourceheight = Source.Size.X, Source.Size.Y
	local Lows, Highs = Shaperows(Stain.Texture, Sourcewidth, Sourceheight)
	local Levelbuffer = Level.Pixels
	local Levelwidth, Levelheight = Level.Size.X, Level.Size.Y
	local Origin = Layout.Inverseorigin
	local Stepux, Stepuy = Layout.Inverseu.X / Width, Layout.Inverseu.Y / Width
	local Stepvx, Stepvy = Layout.Inversev.X / Height, Layout.Inversev.Y / Height
	local Samples = Stainsupersample
	local Weight = 1 / (Samples * Samples)
	local Started = os.clock()
	for Y = Miny, Maxy do
		if os.clock() - Started > Preloadframebudget then
			task.wait()
			Started = os.clock()
		end
		for X = Minx, Maxx do
			local Red, Green, Blue, Alpha = 0, 0, 0, 0
			for Suby = 1, Samples do
				local Pixely = Y + (Suby - 0.5) / Samples
				for Subx = 1, Samples do
					local Pixelx = X + (Subx - 0.5) / Samples
					local U = Origin.X + Stepux * Pixelx + Stepvx * Pixely
					local V = Origin.Y + Stepuy * Pixelx + Stepvy * Pixely
					if U >= 0 and U <= 1 and V >= 0 and V <= 1 then
						local Inside = true
						if Lows and Highs then
							local Row = math.min(math.floor(V * Sourceheight), Sourceheight - 1) + 1
							local Column = math.min(math.floor(U * Sourcewidth), Sourcewidth - 1)
							Inside = Column >= Lows[Row] and Column <= Highs[Row]
						end
						if Inside then
							local Offset = (
								math.min(math.floor(V * Levelheight), Levelheight - 1) * Levelwidth
								+ math.min(math.floor(U * Levelwidth), Levelwidth - 1)
							) * 4
							local Opacity = buffer.readu8(Levelbuffer, Offset + 3)
							if Opacity > 0 then
								Red += buffer.readu8(Levelbuffer, Offset) * Opacity
								Green += buffer.readu8(Levelbuffer, Offset + 1) * Opacity
								Blue += buffer.readu8(Levelbuffer, Offset + 2) * Opacity
								Alpha += Opacity
							end
						end
					end
				end
			end
			if Alpha > 0 then
				local Offset = ((Y - Miny) * Regionwidth + X - Minx) * 4
				buffer.writeu8(Pixels, Offset, math.round(Red / Alpha))
				buffer.writeu8(Pixels, Offset + 1, math.round(Green / Alpha))
				buffer.writeu8(Pixels, Offset + 2, math.round(Blue / Alpha))
				buffer.writeu8(Pixels, Offset + 3, math.round(Alpha * Weight))
			end
		end
	end
	if not Decal.Parent or Decal:GetAttribute("Cleaned") == true then
		Created:Destroy()
		Overlaypending[Decal] = nil
		return
	end
	Created:WritePixelsBuffer(Vector2.new(Minx, Miny), Vector2.new(Regionwidth, Regionheight), Pixels)
	Stain.Pixelminimum = Vector2.new(Minx, Miny)
	Stain.Pixelmaximum = Vector2.new(Maxx, Maxy)
	Applyoverlay(Decal, Created)
	Decal.Color3 = Stain.Texture.ImageColor3
	Settlesurface(Stain, true)
end

local function Preloaddecals(Decals: { Decal }, Stains: { Stain })
	local Shrinks: { [Decal]: Vector2 } = {}
	for _, Decal in ipairs(Decals) do
		Overlaypending[Decal] = true
		local Radius = Facemapping.GetBrushRadius(
			(Decal.Parent :: BasePart).Size,
			Decal.Face.Name,
			Toothbrushradius,
			Activebrushradius
		)
		Shrinks[Decal] = Vector2.new(
			2 ^ -math.round(math.log(Radius.X / Toothbrushradius, 2)),
			2 ^ -math.round(math.log(Radius.Y / Toothbrushradius, 2))
		)
	end
	for _, Stain in ipairs(Stains) do
		Overlaypending[Stain.Decal] = true
	end
	task.spawn(function()
		local Sources: { [string]: Pixelsource? } = {}
		local Images = {}
		for _, Decal in ipairs(Decals) do
			if not table.find(Images, Decal.Texture) then
				table.insert(Images, Decal.Texture)
			end
		end
		for _, Stain in ipairs(Stains) do
			if not table.find(Images, Stain.Texture.Image) then
				table.insert(Images, Stain.Texture.Image)
			end
		end
		local Remaining = #Images
		for _, Image in ipairs(Images) do
			task.spawn(function()
				Sources[Image] = Loadsource(Image)
				Remaining -= 1
			end)
		end
		while Remaining > 0 do
			task.wait()
		end
		local Total = 0
		for _, Decal in ipairs(Decals) do
			local Source = Sources[Decal.Texture]
			if Source then
				Total += Source.Size.X * Source.Size.Y * 4 * Shrinks[Decal].X * Shrinks[Decal].Y
			end
		end
		for _, Stain in ipairs(Stains) do
			if Sources[Stain.Texture.Image] then
				Total += Stain.Canvas.X * Stain.Canvas.Y * 4
			end
		end
		local Scale = math.min(1, math.sqrt(Overlaybudget / math.max(Total, 1)))
		local Keys = {}
		for _, Decal in ipairs(Decals) do
			Keys[Levelkey(Decal.Texture, Scale, Shrinks[Decal])] = true
		end
		for _, Stain in ipairs(Stains) do
			local Source = Sources[Stain.Texture.Image]
			if Source then
				local _, _, Shrink = Planstain(Stain, Source, Scale)
				Keys[Levelkey(Stain.Texture.Image, 1, Shrink)] = true
			end
		end
		Trimlevels(Keys)
		local Order = table.clone(Decals)
		table.sort(Order, function(First, Second)
			return Shrinks[First].X * Shrinks[First].Y > Shrinks[Second].X * Shrinks[Second].Y
		end)
		local Started = os.clock()
		for _, Decal in ipairs(Order) do
			if os.clock() - Started > Preloadframebudget then
				task.wait()
				Started = os.clock()
			end
			local Image = Decal.Texture
			local Source = Sources[Image]
			if not Source then
				Overlaypending[Decal] = false
			elseif Decal.Parent then
				local Base = Getscaled(Image, Source, Scale)
				local Level = Getlevel(Image, Scale, Base, Shrinks[Decal])
				if Decal.Parent then
					local Success, Created = pcall(function()
						local Overlay = Assetservice:CreateEditableImage({ Size = Level.Size })
						Overlay:WritePixelsBuffer(Vector2.zero, Level.Size, Level.Pixels)
						return Overlay
					end)
					if Success then
						Applyoverlay(Decal, Created)
						Overlayscales[Decal] = Level.Size / Base.Size * math.min(Base.Size.X, Base.Size.Y)
					else
						Overlaypending[Decal] = false
						warn("CleaningController: EditableImage failed for " .. Decal:GetFullName() .. ": " .. tostring(Created))
					end
				end
			end
			if not Decal.Parent then
				Overlaypending[Decal] = nil
			end
		end
		for _, Stain in ipairs(Stains) do
			Composestain(Stain, Sources[Stain.Texture.Image], Scale)
		end
	end)
end

local function Getoverlayimage(Decal: Decal): EditableImage?
	local Editable = Overlayimages[Decal]
	if Editable then return Editable end
	if Overlaypending[Decal] ~= nil then return nil end
	Overlaypending[Decal] = true
	task.spawn(function()
		local Success, Created = pcall(function()
			return Assetservice:CreateEditableImageAsync(Content.fromUri(Decal.Texture))
		end)
		if not Success then
			Overlaypending[Decal] = false
			warn("CleaningController: EditableImage failed for " .. Decal:GetFullName() .. ": " .. tostring(Created))
			return
		end
		Applyoverlay(Decal, Created)
	end)
	return nil
end

local function Dissolvecells(Decal: Decal, Cells: buffer)
	local Mask = Leftovers[Decal]
	local Editable = Overlayimages[Decal]
	local Indices = {}
	for Offset = 0, buffer.len(Cells) - 2, 2 do
		local Index = buffer.readu16(Cells, Offset)
		table.insert(Indices, Index)
		if Mask then buffer.writeu8(Mask, Index, 0) end
	end
	if not Editable then return end
	task.spawn(function()
		for _, Keep in ipairs(Dissolvekeep) do
			if Overlayimages[Decal] ~= Editable then return end
			local Size = Editable.Size
			for _, Index in ipairs(Indices) do
				local Column, Row = Index % Coveragegrid, Index // Coveragegrid
				local Corner = Vector2.new(math.floor(Column * Size.X / Coveragegrid), math.floor(Row * Size.Y / Coveragegrid))
				local Region = Vector2.new(
					math.floor((Column + 1) * Size.X / Coveragegrid) - Corner.X,
					math.floor((Row + 1) * Size.Y / Coveragegrid) - Corner.Y
				)
				if Region.X > 0 and Region.Y > 0 then
					local Pixels = Editable:ReadPixelsBuffer(Corner, Region)
					for Offset = 3, Region.X * Region.Y * 4 - 1, 4 do
						buffer.writeu8(Pixels, Offset, math.floor(buffer.readu8(Pixels, Offset) * Keep))
					end
					Editable:WritePixelsBuffer(Corner, Region, Pixels)
				end
			end
			task.wait(Dissolveinterval)
		end
	end)
end

local Pendingdirt: { [Decal]: { Vector2 } } = {}
local Pendingticks: { [Decal]: number } = {}
local Pendingorder: { Decal } = {}

local function Fadedecal(Decal: Decal, Localpoint: Vector2, Radius: Vector2)
	if Localpoint.X < 0 or Localpoint.Y < 0 or Localpoint.X > 1 or Localpoint.Y > 1 then return end
	local Editable = Getoverlayimage(Decal)
	if not Editable and Overlaypending[Decal] then return end
	local Points = Pendingdirt[Decal]
	if not Points then
		Points = {}
		Pendingdirt[Decal] = Points
		Pendingticks[Decal] = Fadetick
		table.insert(Pendingorder, Decal)
	end
	if #Points >= Maxpendingpoints then return end
	table.insert(Points, Localpoint)
	if not Editable then return end
	local Size = Editable.Size
	local Width, Height = Size.X, Size.Y
	local Centerx = math.round(Localpoint.X * Width)
	local Centery = math.round(Localpoint.Y * Height)
	local Tick = Pendingticks[Decal]
	local Last = Lastfades[Decal]
	if Last and Last.Tick == Tick and Last.X == Centerx and Last.Y == Centery then return end
	Lastfades[Decal] = { Tick = Tick, X = Centerx, Y = Centery }
	local Pixelscale = Overlayscales[Decal]
	local Radiusx = math.max(math.round(Radius.X * Pixelscale.X), 2)
	local Radiusy = math.max(math.round(Radius.Y * Pixelscale.Y), 2)
	local Minx = math.max(Centerx - Radiusx, 0)
	local Miny = math.max(Centery - Radiusy, 0)
	local Maxx = math.min(Centerx + Radiusx, Width - 1)
	local Maxy = math.min(Centery + Radiusy, Height - 1)
	if Minx > Maxx or Miny > Maxy then return end
	local Regionwidth = Maxx - Minx + 1
	local Regionheight = Maxy - Miny + 1
	local Pixels = Editable:ReadPixelsBuffer(Vector2.new(Minx, Miny), Vector2.new(Regionwidth, Regionheight))
	local Marks = Tickmarks[Decal]
	if not Marks then
		Marks = buffer.create(Width * Height * 2)
		Tickmarks[Decal] = Marks
	end
	local Radiusxsquared = Radiusx * Radiusx
	local Radiusysquared = Radiusy * Radiusy
	local Ellipselimit = Radiusxsquared * Radiusysquared
	local Changed = false
	for Y = Miny, Maxy do
		local Dy = Y - Centery
		local Rowlimit = Ellipselimit - Dy * Dy * Radiusxsquared
		for X = Minx, Maxx do
			local Dx = X - Centerx
			if Dx * Dx * Radiusysquared <= Rowlimit then
				local Markoffset = (Y * Width + X) * 2
				if buffer.readu16(Marks, Markoffset) ~= Tick then
					buffer.writeu16(Marks, Markoffset, Tick)
					local Alphaoffset = ((Y - Miny) * Regionwidth + (X - Minx)) * 4 + 3
					local Alpha = buffer.readu8(Pixels, Alphaoffset)
					if Alpha > 0 then
						buffer.writeu8(Pixels, Alphaoffset, math.max(Alpha - Activedirtstep, 0))
						Changed = true
					end
				end
			end
		end
	end
	if Changed then
		Editable:WritePixelsBuffer(Vector2.new(Minx, Miny), Vector2.new(Regionwidth, Regionheight), Pixels)
	end
end

local function Erasestain(Stain: Stain, Facepoint: Vector2)
	local Decal = Stain.Decal
	local Editable = Overlayimages[Decal]
	if not Editable and Overlaypending[Decal] then return end
	if Laststainpoints[Decal] == Facepoint then return end
	local Points = Pendingstains[Decal]
	if not Points then
		Points = {}
		Pendingstains[Decal] = Points
		table.insert(Pendingstainorder, Decal)
	end
	if #Points >= Maxpendingpoints then return end
	table.insert(Points, Facepoint)
	Laststainpoints[Decal] = Facepoint
	if not Editable then return end
	local Size = Editable.Size
	local Centerx, Centery = Facepoint.X * Size.X, Facepoint.Y * Size.Y
	local Radiusx, Radiusy = Stain.Radius.X * Size.X, Stain.Radius.Y * Size.Y
	local Minx = math.max(math.ceil(Centerx - Radiusx - 0.5), Stain.Pixelminimum.X)
	local Maxx = math.min(math.floor(Centerx + Radiusx - 0.5), Stain.Pixelmaximum.X)
	local Miny = math.max(math.ceil(Centery - Radiusy - 0.5), Stain.Pixelminimum.Y)
	local Maxy = math.min(math.floor(Centery + Radiusy - 0.5), Stain.Pixelmaximum.Y)
	if Minx > Maxx or Miny > Maxy then return end
	local Corner = Vector2.new(Minx, Miny)
	local Region = Vector2.new(Maxx - Minx + 1, Maxy - Miny + 1)
	local Pixels = Editable:ReadPixelsBuffer(Corner, Region)
	local Changed = false
	for Y = Miny, Maxy do
		local Dy = (Y + 0.5 - Centery) / Radiusy
		local Rowlimit = 1 - Dy * Dy
		local Rowoffset = (Y - Miny) * Region.X - Minx
		for X = Minx, Maxx do
			local Dx = (X + 0.5 - Centerx) / Radiusx
			if Dx * Dx <= Rowlimit then
				local Alphaoffset = (Rowoffset + X) * 4 + 3
				if buffer.readu8(Pixels, Alphaoffset) > 0 then
					buffer.writeu8(Pixels, Alphaoffset, 0)
					Changed = true
				end
			end
		end
	end
	if Changed then
		Editable:WritePixelsBuffer(Corner, Region, Pixels)
	end
end

local function Touchesstain(Stain: Stain, Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): boolean
	if not Part:IsA("TriangleMeshPart") then
		return Getfacename(Part.CFrame:VectorToObjectSpace(Worldnormal)) == Stain.Layout.Facename
	end
	local Decal = Stain.Decal
	return Facemapping.TouchesDecal(Decal, Worldnormal)
		and (Facemapping.ShowsDecal(Decal, Worldnormal) or not Isoccluded(Part, Worldposition, Decal.Face))
end

local function Showsstain(Stain: Stain, Part: BasePart, Worldnormal: Vector3): boolean
	if not Part:IsA("TriangleMeshPart") then
		return true
	end
	return Facemapping.ShowsDecal(Stain.Decal, Worldnormal)
end

local function Newstain(Decal: Decal): Stain
	local Definition = Stainkinds[Decal.Name]
	local Texture = (Decal:WaitForChild("Source") :: ObjectValue).Value :: ImageLabel
	local Layout = Stainlayout.GetLayout(Texture)
	assert(
		Decal.Parent == Layout.Part and Decal.Face == Layout.Face,
		"CleaningController: " .. Decal:GetFullName() .. " must sit on the face of " .. Layout.Surface:GetFullName()
	)
	local Extent = Facemapping.GetDecalSize(Layout.Part.Size, Layout.Facename)
	local Longest = math.max(Extent.X, Extent.Y)
	local List = Stainsbypart[Layout.Part]
	if not List then
		List = {}
		Stainsbypart[Layout.Part] = List
	end
	return {
		Decal = Decal,
		Texture = Texture,
		Layout = Layout,
		Kind = Definition.Kind,
		Liquid = Definition.Liquid,
		Clean = Definition.Clean,
		Canvas = Vector2.new(
			math.max(math.round(Staincanvassize * Extent.X / Longest), 1),
			math.max(math.round(Staincanvassize * Extent.Y / Longest), 1)
		),
		Radius = Facemapping.GetBrushRadius(Layout.Part.Size, Layout.Facename, Toothbrushradius, Activebrushradius),
		Pixelminimum = Vector2.zero,
		Pixelmaximum = -Vector2.one,
		List = List,
		Settled = false,
	}
end

local function Dropstain(Stain: Stain)
	local Decal = Stain.Decal
	local Position = table.find(Stain.List, Stain)
	if Position then
		table.remove(Stain.List, Position)
	end
	if Stainsbydecal[Decal] == Stain then
		Stainsbydecal[Decal] = nil
	end
	Pendingstains[Decal] = nil
	Laststainpoints[Decal] = nil
end

local function Finishstain(Stain: Stain)
	Stain.Layout.Frame.Visible = false
	Dropstain(Stain)
	Settlesurface(Stain, true)
end

local function Trackstain(Stain: Stain): boolean
	local Decal = Stain.Decal
	if Decal:GetAttribute("Cleaned") == true then
		Finishstain(Stain)
		return false
	end
	table.insert(Stain.List, Stain)
	Stainsbydecal[Decal] = Stain
	Decal:GetAttributeChangedSignal("Cleaned"):Connect(function()
		if Decal:GetAttribute("Cleaned") == true then
			Tweenservice:Create(Decal, Cleanedfadeinfo, { Transparency = 1 }):Play()
			Finishstain(Stain)
		end
	end)
	Decal.Destroying:Connect(function()
		Dropstain(Stain)
		Settlesurface(Stain, true)
	end)
	return true
end

function Cleaningcontroller:PreloadOverlays(Object: Model | BasePart)
	table.clear(Pendingdirt)
	table.clear(Pendingticks)
	table.clear(Pendingorder)
	table.clear(Leftovers)
	table.clear(Leftoverrequests)
	for _, Stain in pairs(Stainsbydecal) do
		Stain.Settled = true
	end
	table.clear(Stainsbypart)
	table.clear(Stainsbydecal)
	table.clear(Surfacewaiting)
	table.clear(Surfacefallback)
	table.clear(Pendingstains)
	table.clear(Pendingstainorder)
	table.clear(Laststainpoints)
	if Activecaster then
		Activecaster:Destroy()
	end
	local Caster = Surfacecast.new(Object)
	Activecaster = Caster
	Activeobject = Object
	Activedirtstep = Object:GetAttribute("DirtStep") :: number
	Activebrushradius = Object:GetAttribute("BrushRadius") :: number
	Object.Destroying:Connect(function()
		Caster:Destroy()
	end)
	if (Object:GetAttribute("DirtVersion") :: number) >= 3 then
		task.spawn(function()
			Caster:Load()
		end)
	end
	local Decals = {}
	local Staindecals = {}
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("Decal") and Dirtdecalnames[Descendant.Name] then
			table.insert(Decals, Descendant)
			Descendant:GetAttributeChangedSignal("Cleaned"):Connect(function()
				if Descendant:GetAttribute("Cleaned") == true then
					Tweenservice:Create(Descendant, Cleanedfadeinfo, { Transparency = 1 }):Play()
				end
			end)
		elseif Descendant:IsA("Decal") and Stainkinds[Descendant.Name] then
			table.insert(Staindecals, Descendant)
		end
	end
	local Stains = {}
	for _, Decal in ipairs(Staindecals) do
		local Stain = Newstain(Decal)
		local Surface = Stain.Layout.Surface
		Surfacewaiting[Surface] = (Surfacewaiting[Surface] or 0) + 1
		table.insert(Stains, Stain)
	end
	local Active = {}
	for _, Stain in ipairs(Stains) do
		if Trackstain(Stain) then
			table.insert(Active, Stain)
		end
	end
	Preloaddecals(Decals, Active)
end

function Cleaningcontroller:CastSurface(Origin: Vector3, Vector: Vector3): Surfacecast.Hit?
	return Activecaster:Cast(Origin, Vector)
end

function Cleaningcontroller:EraseDirtOverlay(
	Part: BasePart,
	Worldposition: Vector3,
	Worldnormal: Vector3,
	Radiusscale: number
): boolean
	local Touched = false
	local Base = Overlayradiusratio * Radiusscale
	local Minimum = Activebrushradius * Base / Toothbrushradius
	for _, Decal in ipairs(Getdirtdecals(Part, Worldposition, Worldnormal)) do
		if Decal:GetAttribute("Cleaned") ~= true then
			Touched = true
			local Facename = Decal.Face.Name
			Fadedecal(
				Decal,
				Getdecalpoint(Part, Worldposition, Facename),
				Facemapping.GetBrushRadius(Part.Size, Facename, Base, Minimum)
			)
		end
	end
	return Touched
end

function Cleaningcontroller:EraseStains(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): boolean
	local Stains = Stainsbypart[Part]
	if not Stains then return false end
	local Touched = false
	for _, Stain in ipairs(Stains) do
		if Stain.Texture:GetAttribute(Stain.Liquid) == true then
			local Facepoint = Getdecalpoint(Part, Worldposition, Stain.Layout.Facename)
			if Stainlayout.Touches(Stain.Layout, Facepoint, Stain.Radius) and Touchesstain(Stain, Part, Worldposition, Worldnormal) then
				Touched = true
				Erasestain(Stain, Facepoint)
			end
		end
	end
	return Touched
end

function Cleaningcontroller:QueuePing(Worldposition: Vector3)
	local Moved = (Worldposition - self.lastPingPosition).Magnitude > Pingmovement
	self.lastPingPosition = Worldposition
	local Ratio = Activeobject:GetAttribute("Cleaned_Dirt") / Activeobject:GetAttribute("Total_Dirt")
	if Moved and Ratio >= math.min(Finishassist.Start, Finishassist.StallStart) and Ratio < 1 then
		self.pingPending = true
	end
end

function Cleaningcontroller:SendDirt(Toolname: string)
	if os.clock() - self.lastRequest < Cleaninterval then return end
	local Strokes = {}
	while #Strokes < Maxdirtstrokes and #Pendingorder > 0 do
		local Decal = table.remove(Pendingorder, 1) :: Decal
		if Decal.Parent and Decal:GetAttribute("Cleaned") ~= true then
			table.insert(Strokes, { Target = Decal, Points = Pendingdirt[Decal] })
		end
		Pendingdirt[Decal] = nil
		Pendingticks[Decal] = nil
	end
	if #Strokes == 0 and not self.pingPending then return end
	self.pingPending = false
	self.lastRequest = os.clock()
	Fadetick = Fadetick % 65535 + 1
	Remotemanager:FireServer("RestorationService", "CleanDirt", Toolname, Strokes)
end

function Cleaningcontroller:SendStain(): boolean
	if os.clock() - self.lastRequest < Cleaninterval then return false end
	while #Pendingstainorder > 0 do
		local Decal = table.remove(Pendingstainorder, 1) :: Decal
		local Points = Pendingstains[Decal]
		Pendingstains[Decal] = nil
		if Points then
			self.lastRequest = os.clock()
			Remotemanager:FireServer("RestorationService", Stainkinds[Decal.Name].Clean, Decal, Points)
			return true
		end
	end
	return false
end

function Cleaningcontroller:SendCotton()
	if os.clock() - self.lastRequest < Cleaninterval then return end
	if self.stainTurn and self:SendStain() then
		self.stainTurn = false
		return
	end
	local Previous = self.lastRequest
	self:SendDirt("CottonTip")
	if self.lastRequest ~= Previous then
		self.stainTurn = true
	elseif self:SendStain() then
		self.stainTurn = false
	end
end

function Cleaningcontroller:Init()
	self.lastRequest = 0
	self.lastCotton = 0
	self.lastInkSolventRequest = 0
	self.lastScratchPolishRequest = 0
	self.stainTurn = false
	self.pingPending = false
	self.lastPingPosition = Vector3.zero
end

function Cleaningcontroller:Start()
	Remotemanager:OnClientEvent("RestorationService", "LeftoversCleared", Dissolvecells)
	Runservice.Heartbeat:Connect(function()
		if #Pendingstainorder > 0 and os.clock() - self.lastCotton >= Cleaninterval then
			self:SendStain()
		end
	end)
end

function Cleaningcontroller:WarmDirtTextures()
	for _, Texture in ipairs(Cleaningconfig.DirtTextures) do
		Loadsource(Texture.Image)
	end
end

local function Scanpixels(Editable: EditableImage, Localpoint: Vector2, Radiusscale: number, Pixelscale: Vector2)
	if Localpoint.X < 0 or Localpoint.Y < 0 or Localpoint.X > 1 or Localpoint.Y > 1 then return nil end
	local Size = Editable.Size
	local Width, Height = Size.X, Size.Y
	local Centerx = math.round(Localpoint.X * Width)
	local Centery = math.round(Localpoint.Y * Height)
	local Radiusx = math.max(math.round(Pixelscale.X * Overlayradiusratio * Radiusscale), 2)
	local Radiusy = math.max(math.round(Pixelscale.Y * Overlayradiusratio * Radiusscale), 2)
	local Stretch = Radiusx / Radiusy
	local Stepx = math.max(math.round(Stainsamplestep * Radiusx / math.max(Radiusx, Radiusy)), 1)
	local Stepy = math.max(math.round(Stainsamplestep * Radiusy / math.max(Radiusx, Radiusy)), 1)
	local Minx = math.max(Centerx - Radiusx, 0)
	local Miny = math.max(Centery - Radiusy, 0)
	local Maxx = math.min(Centerx + Radiusx, Width - 1)
	local Maxy = math.min(Centery + Radiusy, Height - 1)
	if Minx > Maxx or Miny > Maxy then return nil end
	local Regionwidth = Maxx - Minx + 1
	local Regionheight = Maxy - Miny + 1
	local Pixels = Editable:ReadPixelsBuffer(Vector2.new(Minx, Miny), Vector2.new(Regionwidth, Regionheight))
	local Radiussquared = Radiusx * Radiusx
	local Spotradiussquared = (Radiusx * Stainspotratio) ^ 2
	local Samples, Weight, Spotweight, Sumx, Sumy, Sumxx, Sumyy = 0, 0, 0, 0, 0, 0, 0
	for Y = Miny, Maxy, Stepy do
		local Dy = (Y - Centery) * Stretch
		for X = Minx, Maxx, Stepx do
			local Dx = X - Centerx
			local Distancesquared = Dx * Dx + Dy * Dy
			if Distancesquared <= Radiussquared then
				Samples += 1
				local Alpha = buffer.readu8(Pixels, ((Y - Miny) * Regionwidth + (X - Minx)) * 4 + 3)
				if Alpha > 0 then
					Weight += Alpha
					Sumx += X * Alpha
					Sumy += Y * Alpha
					Sumxx += X * X * Alpha
					Sumyy += Y * Y * Alpha
					if Distancesquared <= Spotradiussquared then Spotweight += Alpha end
				end
			end
		end
	end
	if Spotweight == 0 then return nil end
	local Meanx, Meany = Sumx / Weight, Sumy / Weight
	local Variance = math.max(Sumxx / Weight - Meanx * Meanx + (Sumyy / Weight - Meany * Meany) * Stretch * Stretch, 0)
	return {
		Mean = Vector2.new(Meanx, Meany),
		Spread = math.sqrt(Variance),
		Radius = Radiusx,
		Aspect = Vector2.new(1, Radiusy / Radiusx),
		Amount = Weight / (Samples * 255),
		Spot = Spotweight,
	}
end

local function Scandecal(Decal: Decal, Facepoint: Vector2, Radiusscale: number): StainCluster?
	local Editable = Overlayimages[Decal]
	if not Editable then return nil end
	local Scan = Scanpixels(Editable, Facepoint, Radiusscale, Overlayscales[Decal])
	if not Scan then return nil end
	return {
		Decal = Decal,
		Center = Scan.Mean / Editable.Size,
		Spread = Scan.Spread,
		Radius = Scan.Radius,
		Scale = Scan.Aspect / Editable.Size,
		Amount = Scan.Amount,
		Spot = Scan.Spot,
	}
end

local function Refreshleftovers(Decals: { Decal })
	local Now = os.clock()
	local Requested = {}
	for _, Decal in ipairs(Decals) do
		if #Requested < Maxdirtstrokes and Now - (Leftoverrequests[Decal] or 0) >= Leftoverinterval then
			Leftoverrequests[Decal] = Now
			table.insert(Requested, Decal)
		end
	end
	if #Requested == 0 then return end
	task.spawn(function()
		local Masks = Remotemanager:InvokeServer("RestorationService", "GetLeftovers", Requested)
		for Index, Decal in ipairs(Requested) do
			Leftovers[Decal] = Masks[Index]
		end
	end)
end

function Cleaningcontroller:FindLeftovers(
	Part: BasePart,
	Worldposition: Vector3,
	Worldnormal: Vector3,
	Radius: number
): (Decal?, { Vector3 })
	local Decals = {}
	local Facedecal: Decal? = nil
	for _, Decal in ipairs(Getdirtdecals(Part, Worldposition, Worldnormal)) do
		if Decal:GetAttribute("Cleaned") ~= true then
			table.insert(Decals, Decal)
			if not Facedecal or Facemapping.ShowsDecal(Decal, Worldnormal) then
				Facedecal = Decal
			end
		end
	end
	for _, Stain in ipairs(Stainsbypart[Part] or Nostains) do
		if Touchesstain(Stain, Part, Worldposition, Worldnormal) then
			table.insert(Decals, Stain.Decal)
			if not Facedecal or Showsstain(Stain, Part, Worldnormal) then
				Facedecal = Stain.Decal
			end
		end
	end
	local Spots = {}
	if not Facedecal then return nil, Spots end
	Refreshleftovers(Decals)
	local Point = Getdecalpoint(Part, Worldposition, Facedecal.Face.Name)
	for _, Decal in ipairs(Decals) do
		local Mask = Leftovers[Decal]
		if Mask and Decal.Face == Facedecal.Face then
			local Stained = Stainsbydecal[Decal] ~= nil
			for Cell = 0, Coveragegrid * Coveragegrid - 1 do
				local Remaining = buffer.readu8(Mask, Cell)
				if Remaining > 0 then
					local Center = Vector2.new((Cell % Coveragegrid + 0.5) / Coveragegrid, (Cell // Coveragegrid + 0.5) / Coveragegrid)
					if (Center - Point).Magnitude <= Radius then
						local Passes = if Stained
							then Cleaningconfig.DirtPasses
							else math.min(math.ceil(Remaining * Activedirtstep / Basefadestep), Cleaningconfig.DirtPasses)
						table.insert(Spots, Vector3.new(Center.X, Center.Y, Passes))
					end
				end
			end
		end
	end
	return Facedecal, Spots
end

function Cleaningcontroller:FindStainAround(
	Part: BasePart,
	Worldposition: Vector3,
	Worldnormal: Vector3,
	Radiusscale: number
): StainCluster?
	local Best: StainCluster? = nil
	for _, Decal in ipairs(Getdirtdecals(Part, Worldposition, Worldnormal)) do
		if Decal:GetAttribute("Cleaned") ~= true then
			local Cluster = Scandecal(Decal, Getdecalpoint(Part, Worldposition, Decal.Face.Name), Radiusscale)
			if Cluster and (not Best or Cluster.Spot > Best.Spot) then Best = Cluster end
		end
	end
	for _, Stain in ipairs(Stainsbypart[Part] or Nostains) do
		if Touchesstain(Stain, Part, Worldposition, Worldnormal) then
			local Cluster = Scandecal(Stain.Decal, Getdecalpoint(Part, Worldposition, Stain.Layout.Facename), Radiusscale)
			if Cluster and (not Best or Cluster.Spot > Best.Spot) then Best = Cluster end
		end
	end
	return Best
end

local function Findliquidtarget(Kind: string, Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): (ImageLabel?, ImageLabel?)
	local Found: ImageLabel? = nil
	local Dry: ImageLabel? = nil
	for _, Stain in ipairs(Stainsbypart[Part] or Nostains) do
		if
			Stain.Kind == Kind
			and Stainlayout.Contains(Stain.Layout, Getdecalpoint(Part, Worldposition, Stain.Layout.Facename))
			and Touchesstain(Stain, Part, Worldposition, Worldnormal)
		then
			Found = Found or Stain.Texture
			if not Dry and Stain.Texture:GetAttribute(Stain.Liquid) ~= true then
				Dry = Stain.Texture
			end
		end
	end
	return Found, Dry
end

function Cleaningcontroller:TryApplyInkSolvent(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Found, Dry = Findliquidtarget("Ink", Part, Worldposition, Worldnormal)
	if Dry and os.clock() - self.lastInkSolventRequest >= Liquidapplyinterval then
		self.lastInkSolventRequest = os.clock()
		Remotemanager:FireServer("RestorationService", "ApplyInkSolvent", Dry)
	end
	return Found
end

function Cleaningcontroller:TryApplyScratchPolish(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Found, Dry = Findliquidtarget("Scratch", Part, Worldposition, Worldnormal)
	if Dry and os.clock() - self.lastScratchPolishRequest >= Liquidapplyinterval then
		self.lastScratchPolishRequest = os.clock()
		Remotemanager:FireServer("RestorationService", "ApplyScratchPolish", Dry)
	end
	return Found
end

function Cleaningcontroller:TryCleanDirt(Hit: Surfacecast.Hit, Toolname: string)
	if Core:GetController("InspectionCameraController"):IsDragging() then return end
	local Radiusscale = if Toolname == "CottonTip" then Cottonscale else Brushscale
	if not self:EraseDirtOverlay(Hit.Instance, Hit.Position, Hit.DecalNormal, Radiusscale) then
		self:QueuePing(Hit.Position)
	end
	self:SendDirt(Toolname)
end

function Cleaningcontroller:TryCleanCotton(Hit: Surfacecast.Hit)
	if Core:GetController("InspectionCameraController"):IsDragging() then return end
	self.lastCotton = os.clock()
	local Stained = self:EraseStains(Hit.Instance, Hit.Position, Hit.DecalNormal)
	if not self:EraseDirtOverlay(Hit.Instance, Hit.Position, Hit.DecalNormal, Cottonscale) and not Stained then
		self:QueuePing(Hit.Position)
	end
	self:SendCotton()
end

return Cleaningcontroller
