local Assetservice = game:GetService("AssetService")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Tweenservice = game:GetService("TweenService")

local Cleaningconfig = require(Replicatedstorage.Shared.Config.Cleaning)
local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)
local Roundedtexture = require(Replicatedstorage.Shared.Utils.RoundedTexture)
local Facemapping = require(Replicatedstorage.Shared.Utils.FaceMapping)
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
	Facemapping.GetDecalPoint and Facemapping.TouchesDecal and Facemapping.ShowsDecal,
	string.format(
		"CleaningController: outdated FaceMapping (%d copies in Shared.Utils, delete the duplicates in Studio)",
		Countcopies("FaceMapping")
	)
)

local Cleaningcontroller = { Name = "CleaningController", Priority = 9 }

local Cleaninterval = 0.075
local Scratchcleaninterval = Cleaninterval
local Inkcleaninterval = Cleaninterval
local Liquidapplyinterval = 0.25
local Maxdirtstrokes = 8
local Dirtdecalnames = Cleaningconfig.DirtDecals
local Getfacepoint = Facemapping.GetPoint
local Getdecalpoint = Facemapping.GetDecalPoint
local Cleanedfadeinfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Occlusionoffset = 0.02
local Occlusionlength = 64
local Activecaster = nil
local Activeobject = nil

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

local function Getinkimage(Surface: SurfaceGui, Facepoint: Vector2): ImageLabel?
	local Inkframe = Surface:FindFirstChild("Ink")
	if not Inkframe then return nil end
	assert(Inkframe:IsA("GuiObject"), "CleaningController: " .. Inkframe:GetFullName() .. " must be a GuiObject")
	if not Inkframe.Visible or Inkframe:GetAttribute("Cleaned") == true then return nil end
	local Texture = Inkframe:FindFirstChild("Texture")
	if not Texture or not Texture:IsA("ImageLabel") then return nil end
	if (Texture:GetAttribute("Remaining") or 0) <= 0 then return nil end
	local Canvaspoint = Surface.AbsolutePosition
		+ Vector2.new(Facepoint.X * Surface.AbsoluteSize.X, Facepoint.Y * Surface.AbsoluteSize.Y)
	local Minimum = Texture.AbsolutePosition
	local Maximum = Minimum + Texture.AbsoluteSize
	if Canvaspoint.X < Minimum.X or Canvaspoint.Y < Minimum.Y or Canvaspoint.X > Maximum.X or Canvaspoint.Y > Maximum.Y then
		return nil
	end
	return Texture
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

local function Getscratchimage(Surface: SurfaceGui, Facepoint: Vector2): ImageLabel?
	local Canvaspoint = Surface.AbsolutePosition
		+ Vector2.new(Facepoint.X * Surface.AbsoluteSize.X, Facepoint.Y * Surface.AbsoluteSize.Y)
	for _, Scratchframe in ipairs(Surface:GetChildren()) do
		if Scratchframe.Name == "ScratchesFrame" then
			assert(Scratchframe:IsA("GuiObject"), "CleaningController: " .. Scratchframe:GetFullName() .. " must be a GuiObject")
			if not Scratchframe.Visible or Scratchframe:GetAttribute("Cleaned") == true then continue end
			local Texture = Scratchframe:FindFirstChild("Texture")
			if not Texture or not Texture:IsA("ImageLabel") then continue end
			if (Texture:GetAttribute("Remaining") or 0) <= 0 then continue end
			local Minimum = Texture.AbsolutePosition
			local Maximum = Minimum + Texture.AbsoluteSize
			if
				Canvaspoint.X >= Minimum.X
				and Canvaspoint.Y >= Minimum.Y
				and Canvaspoint.X <= Maximum.X
				and Canvaspoint.Y <= Maximum.Y
			then
				return Texture
			end
		end
	end
	return nil
end

local Leftovers: { [Decal]: buffer } = {}
local Leftoverrequests: { [Decal]: number } = {}
local Leftoverinterval = 0.3
local Coveragegrid = Cleaningconfig.CoverageGrid
local Overlayimages: { [Instance]: EditableImage } = {}
local Overlaypending: { [Instance]: boolean } = {}
local Overlaybudget = 56 * 1024 * 1024
local Preloadframebudget = 0.005
local Overlayradiusratio = 1 / 16
local Cottonscale = 4 / 3
local Brushscale = 1.5
local Dirtfadestep = math.ceil(255 / Cleaningconfig.DirtPasses)
local Stainsamplestep = 2
local Stainspotratio = 0.2
local Tickmarks: { [Instance]: buffer } = {}
local Lastfades: { [Instance]: { Tick: number, X: number, Y: number } } = {}
local Fadetick = 1
local Maxpendingpoints = 32
local Pingmovement = 0.002
local Dissolvekeep = { 0.45, 0.2, 0 }
local Dissolveinterval = 0.06
local Finishassist = Cleaningconfig.FinishAssist

export type StainCluster = {
	Surface: SurfaceGui?,
	Decal: Decal?,
	Center: Vector2,
	Spread: number,
	Radius: number,
	Scale: Vector2,
	Amount: number,
	Spot: number,
}
local function Roundcorners(Editable: EditableImage, Shape)
	if not Roundedtexture.IsCut(Shape) then
		return
	end
	local Size = Editable.Size
	local Width, Height = Size.X, Size.Y
	local Bounds = Roundedtexture.GetBounds(Width, Height, Shape)
	local Pixels = Editable:ReadPixelsBuffer(Vector2.zero, Size)
	for Y = 0, Height - 1 do
		local Rowinset = Roundedtexture.GetRowInset(Y + 0.5, Bounds)
		local Startx, Endx = 0, 0
		if Rowinset then
			Startx = math.clamp(math.floor(Bounds.Left + Rowinset), 0, Width)
			Endx = math.clamp(math.ceil(Bounds.Right - Rowinset), Startx, Width)
		end
		local Rowoffset = Y * Width * 4
		if Startx > 0 then
			buffer.fill(Pixels, Rowoffset, 0, Startx * 4)
		end
		if Endx < Width then
			buffer.fill(Pixels, Rowoffset + Endx * 4, 0, (Width - Endx) * 4)
		end
	end
	Editable:WritePixelsBuffer(Vector2.zero, Size, Pixels)
end

local function Applyoverlay(Test: ImageLabel | Decal, Created: EditableImage)
	if Test:IsA("Decal") then
		Test.TextureContent = Content.fromObject(Created)
	else
		Roundcorners(Created, Roundedtexture.GetShape(Test))
		Test.ImageContent = Content.fromObject(Created)
	end
	Overlayimages[Test] = Created
	Test.Destroying:Connect(function()
		Overlayimages[Test] = nil
		Overlaypending[Test] = nil
		Tickmarks[Test] = nil
		Lastfades[Test] = nil
		Created:Destroy()
	end)
end

local function Shrinkpixels(Pixels: buffer, Size: Vector2, Scale: number): (buffer, Vector2)
	local Sourcewidth, Sourceheight = Size.X, Size.Y
	local Width = math.max(math.floor(Sourcewidth * Scale), 1)
	local Height = math.max(math.floor(Sourceheight * Scale), 1)
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
	return Result, Vector2.new(Width, Height)
end

local function Preloaddecals(Decals: { Decal }, Caster)
	for _, Decal in ipairs(Decals) do
		Overlaypending[Decal] = true
	end
	task.spawn(function()
		local Sources: { [string]: EditableImage } = {}
		local Images = {}
		for _, Decal in ipairs(Decals) do
			if not table.find(Images, Decal.Texture) then
				table.insert(Images, Decal.Texture)
			end
		end
		local Remaining = #Images
		for _, Image in ipairs(Images) do
			task.spawn(function()
				local Success, Created = pcall(function()
					return Assetservice:CreateEditableImageAsync(Content.fromUri(Image))
				end)
				if Success then
					Sources[Image] = Created
				else
					warn("CleaningController: EditableImage failed for " .. Image .. ": " .. tostring(Created))
				end
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
				Total += Source.Size.X * Source.Size.Y * 4
			end
		end
		local Scale = math.min(1, math.sqrt(Overlaybudget / math.max(Total, 1)))
		local Pixels: { [string]: buffer } = {}
		local Sizes: { [string]: Vector2 } = {}
		for Image, Source in pairs(Sources) do
			local Full = Source:ReadPixelsBuffer(Vector2.zero, Source.Size)
			if Scale < 1 then
				Pixels[Image], Sizes[Image] = Shrinkpixels(Full, Source.Size, Scale)
			else
				Pixels[Image], Sizes[Image] = Full, Source.Size
			end
			Source:Destroy()
		end
		local Started = os.clock()
		for _, Decal in ipairs(Decals) do
			if os.clock() - Started > Preloadframebudget then
				task.wait()
				Started = os.clock()
			end
			local Image = Decal.Texture
			if Decal.Parent and Pixels[Image] then
				local Success, Created = pcall(function()
					local Overlay = Assetservice:CreateEditableImage({ Size = Sizes[Image] })
					Overlay:WritePixelsBuffer(Vector2.zero, Sizes[Image], Pixels[Image])
					return Overlay
				end)
				if Success then
					Applyoverlay(Decal, Created)
				else
					warn("CleaningController: EditableImage failed for " .. Decal:GetFullName() .. ": " .. tostring(Created))
				end
			end
		end
		if Caster then
			Caster:Load()
		end
	end)
end

local function Getoverlayimage(Test: ImageLabel | Decal): EditableImage?
	local Editable = Overlayimages[Test]
	if Editable then return Editable end
	if Overlaypending[Test] then return nil end
	Overlaypending[Test] = true
	task.spawn(function()
		local Source = if Test:IsA("Decal") then Test.Texture else Test.Image
		local Success, Created = pcall(function()
			return Assetservice:CreateEditableImageAsync(Content.fromUri(Source))
		end)
		if not Success then
			warn("CleaningController: EditableImage failed for " .. Test:GetFullName() .. ": " .. tostring(Created))
			return
		end
		Applyoverlay(Test, Created)
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

local Pendingpoints: { [ImageLabel]: { Vector2 } } = {}
local Pendingdirt: { [Decal]: { Vector2 } } = {}

local function Takepoints(Texture: ImageLabel): { Vector2 }?
	local Points = Pendingpoints[Texture]
	Pendingpoints[Texture] = nil
	return Points
end

local function Erasetexture(Texture: ImageLabel, Surface: SurfaceGui, Facepoint: Vector2, Radiusscale: number)
	local Canvaspoint = Surface.AbsolutePosition
		+ Vector2.new(Facepoint.X * Surface.AbsoluteSize.X, Facepoint.Y * Surface.AbsoluteSize.Y)
	local Localpoint = (Canvaspoint - Texture.AbsolutePosition) / Texture.AbsoluteSize
	if Localpoint.X < 0 or Localpoint.Y < 0 or Localpoint.X > 1 or Localpoint.Y > 1 then return end
	local Points = Pendingpoints[Texture]
	if not Points then
		Points = {}
		Pendingpoints[Texture] = Points
	end
	if #Points < 16 then table.insert(Points, Localpoint) end
	local Editable = Getoverlayimage(Texture)
	if not Editable then return end
	local Size = Editable.Size
	local Center = Vector2.new(math.round(Localpoint.X * Size.X), math.round(Localpoint.Y * Size.Y))
	local Radius = math.max(math.round(math.min(Size.X, Size.Y) * Overlayradiusratio * Radiusscale), 2)
	Editable:DrawCircle(Center, Radius, Color3.new(0, 0, 0), 1, Enum.ImageCombineType.Overwrite)
end

local function Fadedecal(Decal: Decal, Localpoint: Vector2, Radiusscale: number)
	if Localpoint.X < 0 or Localpoint.Y < 0 or Localpoint.X > 1 or Localpoint.Y > 1 then return end
	local Points = Pendingdirt[Decal]
	if not Points then
		Points = {}
		Pendingdirt[Decal] = Points
	end
	if #Points < Maxpendingpoints then table.insert(Points, Localpoint) end
	local Editable = Getoverlayimage(Decal)
	if not Editable then return end
	local Size = Editable.Size
	local Width, Height = Size.X, Size.Y
	local Centerx = math.round(Localpoint.X * Width)
	local Centery = math.round(Localpoint.Y * Height)
	local Tick = Fadetick
	local Last = Lastfades[Decal]
	if Last and Last.Tick == Tick and Last.X == Centerx and Last.Y == Centery then return end
	Lastfades[Decal] = { Tick = Tick, X = Centerx, Y = Centery }
	local Radius = math.max(math.round(math.min(Width, Height) * Overlayradiusratio * Radiusscale), 2)
	local Minx = math.max(Centerx - Radius, 0)
	local Miny = math.max(Centery - Radius, 0)
	local Maxx = math.min(Centerx + Radius, Width - 1)
	local Maxy = math.min(Centery + Radius, Height - 1)
	if Minx > Maxx or Miny > Maxy then return end
	local Regionwidth = Maxx - Minx + 1
	local Regionheight = Maxy - Miny + 1
	local Pixels = Editable:ReadPixelsBuffer(Vector2.new(Minx, Miny), Vector2.new(Regionwidth, Regionheight))
	local Marks = Tickmarks[Decal]
	if not Marks then
		Marks = buffer.create(Width * Height * 2)
		Tickmarks[Decal] = Marks
	end
	local Radiussquared = Radius * Radius
	local Changed = false
	for Y = Miny, Maxy do
		local Dy = Y - Centery
		for X = Minx, Maxx do
			local Dx = X - Centerx
			if Dx * Dx + Dy * Dy <= Radiussquared then
				local Markoffset = (Y * Width + X) * 2
				if buffer.readu16(Marks, Markoffset) ~= Tick then
					buffer.writeu16(Marks, Markoffset, Tick)
					local Alphaoffset = ((Y - Miny) * Regionwidth + (X - Minx)) * 4 + 3
					local Alpha = buffer.readu8(Pixels, Alphaoffset)
					if Alpha > 0 then
						buffer.writeu8(Pixels, Alphaoffset, math.max(Alpha - Dirtfadestep, 0))
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

local Overlayframenames = { Ink = true, ScratchesFrame = true }

function Cleaningcontroller:PreloadOverlays(Object: Model | BasePart)
	table.clear(Pendingpoints)
	table.clear(Pendingdirt)
	table.clear(Leftovers)
	table.clear(Leftoverrequests)
	if Activecaster then
		Activecaster:Destroy()
	end
	local Caster = Surfacecast.new(Object)
	Activecaster = Caster
	Activeobject = Object
	Object.Destroying:Connect(function()
		Caster:Destroy()
	end)
	local Decals = {}
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if
			Descendant:IsA("ImageLabel")
			and Descendant.Name == "Texture"
			and Descendant.Parent:IsA("GuiObject")
			and Overlayframenames[Descendant.Parent.Name]
			and Descendant.Parent.Visible
		then
			Getoverlayimage(Descendant)
		elseif Descendant:IsA("Decal") and Dirtdecalnames[Descendant.Name] then
			table.insert(Decals, Descendant)
			Descendant:GetAttributeChangedSignal("Cleaned"):Connect(function()
				if Descendant:GetAttribute("Cleaned") == true then
					Tweenservice:Create(Descendant, Cleanedfadeinfo, { Transparency = 1 }):Play()
				end
			end)
		end
	end
	Preloaddecals(Decals, if (Object:GetAttribute("DirtVersion") :: number) >= 3 then Caster else nil)
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
	for _, Decal in ipairs(Getdirtdecals(Part, Worldposition, Worldnormal)) do
		if Decal:GetAttribute("Cleaned") ~= true then
			Touched = true
			Fadedecal(Decal, Getdecalpoint(Part, Worldposition, Decal.Face.Name), Radiusscale)
		end
	end
	return Touched
end

function Cleaningcontroller:QueuePing(Worldposition: Vector3)
	local Moved = (Worldposition - self.lastPingPosition).Magnitude > Pingmovement
	self.lastPingPosition = Worldposition
	local Ratio = Activeobject:GetAttribute("CleanedSpots") / Activeobject:GetAttribute("TotalSpots")
	if Moved and Ratio >= Finishassist.PingStart and Ratio < 1 then
		self.pingPending = true
	end
end

function Cleaningcontroller:SendDirt(Toolname: string)
	if os.clock() - self.lastRequest < Cleaninterval then return end
	local Strokes = {}
	for Decal, Points in pairs(Pendingdirt) do
		if Decal.Parent and Decal:GetAttribute("Cleaned") ~= true and #Strokes < Maxdirtstrokes then
			table.insert(Strokes, { Target = Decal, Points = Points })
		end
	end
	table.clear(Pendingdirt)
	if #Strokes == 0 and not self.pingPending then return end
	self.pingPending = false
	self.lastRequest = os.clock()
	Fadetick = Fadetick % 65535 + 1
	Remotemanager:FireServer("RestorationService", "CleanDirt", Toolname, Strokes)
end

function Cleaningcontroller:EraseTextureAt(
	Part: BasePart,
	Worldposition: Vector3,
	Worldnormal: Vector3,
	Texture: ImageLabel,
	Radiusscale: number
)
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Facename = Getfacename(Localnormal)
	local Surface = Part:FindFirstChild("Ui" .. Facename)
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled then return end
	Erasetexture(Texture, Surface, Getfacepoint(Part, Worldposition, Facename), Radiusscale)
end

function Cleaningcontroller:EraseCleanedLeftovers(
	Part: BasePart,
	Worldposition: Vector3,
	Worldnormal: Vector3,
	Radiusscale: number
)
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Facename = Getfacename(Localnormal)
	local Surface = Part:FindFirstChild("Ui" .. Facename)
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled then return end
	local Facepoint = Getfacepoint(Part, Worldposition, Facename)
	for _, Frame in ipairs(Surface:GetChildren()) do
		if
			(Frame.Name == "Ink" or Frame.Name == "ScratchesFrame")
			and Frame:IsA("GuiObject")
			and Frame.Visible
			and Frame:GetAttribute("Cleaned") == true
		then
			local Texture = Frame:FindFirstChild("Texture")
			if Texture and Texture:IsA("ImageLabel") then
				Erasetexture(Texture, Surface, Facepoint, Radiusscale)
			end
		end
	end
end

function Cleaningcontroller:Init()
	self.lastRequest = 0
	self.lastScratchRequest = 0
	self.lastInkRequest = 0
	self.lastInkSolventRequest = 0
	self.lastScratchPolishRequest = 0
	self.pingPending = false
	self.lastPingPosition = Vector3.zero
end

function Cleaningcontroller:Start()
	Remotemanager:OnClientEvent("RestorationService", "LeftoversCleared", Dissolvecells)
end

local function Scanpixels(Editable: EditableImage, Localpoint: Vector2, Radiusscale: number)
	if Localpoint.X < 0 or Localpoint.Y < 0 or Localpoint.X > 1 or Localpoint.Y > 1 then return nil end
	local Size = Editable.Size
	local Width, Height = Size.X, Size.Y
	local Centerx = math.round(Localpoint.X * Width)
	local Centery = math.round(Localpoint.Y * Height)
	local Radius = math.max(math.round(math.min(Width, Height) * Overlayradiusratio * Radiusscale), 2)
	local Minx = math.max(Centerx - Radius, 0)
	local Miny = math.max(Centery - Radius, 0)
	local Maxx = math.min(Centerx + Radius, Width - 1)
	local Maxy = math.min(Centery + Radius, Height - 1)
	if Minx > Maxx or Miny > Maxy then return nil end
	local Regionwidth = Maxx - Minx + 1
	local Regionheight = Maxy - Miny + 1
	local Pixels = Editable:ReadPixelsBuffer(Vector2.new(Minx, Miny), Vector2.new(Regionwidth, Regionheight))
	local Radiussquared = Radius * Radius
	local Spotradiussquared = (Radius * Stainspotratio) ^ 2
	local Samples, Weight, Spotweight, Sumx, Sumy, Sumxx, Sumyy = 0, 0, 0, 0, 0, 0, 0
	for Y = Miny, Maxy, Stainsamplestep do
		local Dy = Y - Centery
		for X = Minx, Maxx, Stainsamplestep do
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
	local Variance = math.max(Sumxx / Weight - Meanx * Meanx + Sumyy / Weight - Meany * Meany, 0)
	return {
		Mean = Vector2.new(Meanx, Meany),
		Spread = math.sqrt(Variance),
		Radius = Radius,
		Amount = Weight / (Samples * 255),
		Spot = Spotweight,
	}
end

local function Scanstain(Texture: ImageLabel, Surface: SurfaceGui, Facepoint: Vector2, Radiusscale: number): StainCluster?
	local Editable = Overlayimages[Texture]
	if not Editable then return nil end
	local Canvaspoint = Surface.AbsolutePosition
		+ Vector2.new(Facepoint.X * Surface.AbsoluteSize.X, Facepoint.Y * Surface.AbsoluteSize.Y)
	local Scan = Scanpixels(Editable, (Canvaspoint - Texture.AbsolutePosition) / Texture.AbsoluteSize, Radiusscale)
	if not Scan then return nil end
	local Pixelscale = Texture.AbsoluteSize / Editable.Size
	local Canvascenter = Texture.AbsolutePosition - Surface.AbsolutePosition + Scan.Mean * Pixelscale
	return {
		Surface = Surface,
		Center = Canvascenter / Surface.AbsoluteSize,
		Spread = Scan.Spread,
		Radius = Scan.Radius,
		Scale = Pixelscale / Surface.AbsoluteSize,
		Amount = Scan.Amount,
		Spot = Scan.Spot,
	}
end

local function Scandecal(Decal: Decal, Facepoint: Vector2, Radiusscale: number): StainCluster?
	local Editable = Overlayimages[Decal]
	if not Editable then return nil end
	local Scan = Scanpixels(Editable, Facepoint, Radiusscale)
	if not Scan then return nil end
	return {
		Decal = Decal,
		Center = Scan.Mean / Editable.Size,
		Spread = Scan.Spread,
		Radius = Scan.Radius,
		Scale = Vector2.one / Editable.Size,
		Amount = Scan.Amount,
		Spot = Scan.Spot,
	}
end

local function Refreshleftovers(Decals: { Decal })
	local Now = os.clock()
	local Requested = {}
	for _, Decal in ipairs(Decals) do
		if Now - (Leftoverrequests[Decal] or 0) >= Leftoverinterval then
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
	local Spots = {}
	if not Facedecal then return nil, Spots end
	Refreshleftovers(Decals)
	local Point = Getdecalpoint(Part, Worldposition, Facedecal.Face.Name)
	for _, Decal in ipairs(Decals) do
		local Mask = Leftovers[Decal]
		if Mask and Decal.Face == Facedecal.Face then
			for Cell = 0, Coveragegrid * Coveragegrid - 1 do
				local Remaining = buffer.readu8(Mask, Cell)
				if Remaining > 0 then
					local Center = Vector2.new((Cell % Coveragegrid + 0.5) / Coveragegrid, (Cell // Coveragegrid + 0.5) / Coveragegrid)
					if (Center - Point).Magnitude <= Radius then
						table.insert(Spots, Vector3.new(Center.X, Center.Y, Remaining))
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
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Facename = Getfacename(Localnormal)
	local Surface = Part:FindFirstChild("Ui" .. Facename)
	if Surface and Surface:IsA("SurfaceGui") and Surface.Enabled then
		local Facepoint = Getfacepoint(Part, Worldposition, Facename)
		local Candidates = {}
		local Ink = Getinkimage(Surface, Facepoint)
		if Ink then table.insert(Candidates, Ink) end
		local Scratch = Getscratchimage(Surface, Facepoint)
		if Scratch then table.insert(Candidates, Scratch) end
		for _, Texture in ipairs(Candidates) do
			local Cluster = Scanstain(Texture, Surface, Facepoint, Radiusscale)
			if Cluster and (not Best or Cluster.Spot > Best.Spot) then Best = Cluster end
		end
	end
	for _, Decal in ipairs(Getdirtdecals(Part, Worldposition, Worldnormal)) do
		if Decal:GetAttribute("Cleaned") ~= true then
			local Cluster = Scandecal(Decal, Getdecalpoint(Part, Worldposition, Decal.Face.Name), Radiusscale)
			if Cluster and (not Best or Cluster.Spot > Best.Spot) then Best = Cluster end
		end
	end
	return Best
end

function Cleaningcontroller:GetScratchImage(
	Part: BasePart,
	Worldposition: Vector3,
	Worldnormal: Vector3
): ImageLabel?
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Facename = Getfacename(Localnormal)
	local Surface = Part:FindFirstChild("Ui" .. Facename)
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled then return nil end
	assert(Surface.Face.Name == Facename, "CleaningController: " .. Surface:GetFullName() .. " must use the face " .. Facename)
	return Getscratchimage(Surface, Getfacepoint(Part, Worldposition, Facename))
end

function Cleaningcontroller:GetInkImage(
	Part: BasePart,
	Worldposition: Vector3,
	Worldnormal: Vector3
): ImageLabel?
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Facename = Getfacename(Localnormal)
	local Surface = Part:FindFirstChild("Ui" .. Facename)
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled then return nil end
	assert(Surface.Face.Name == Facename, "CleaningController: " .. Surface:GetFullName() .. " must use the face " .. Facename)
	return Getinkimage(Surface, Getfacepoint(Part, Worldposition, Facename))
end

function Cleaningcontroller:TryApplyInkSolvent(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Image = self:GetInkImage(Part, Worldposition, Worldnormal)
	if not Image then return nil end
	if Image:GetAttribute("HasSolvent") ~= true and os.clock() - self.lastInkSolventRequest >= Liquidapplyinterval then
		self.lastInkSolventRequest = os.clock()
		Remotemanager:FireServer("RestorationService", "ApplyInkSolvent", Image)
	end
	return Image
end

function Cleaningcontroller:TryApplyScratchPolish(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Image = self:GetScratchImage(Part, Worldposition, Worldnormal)
	if not Image then return nil end
	if Image:GetAttribute("HasPolish") ~= true and os.clock() - self.lastScratchPolishRequest >= Liquidapplyinterval then
		self.lastScratchPolishRequest = os.clock()
		Remotemanager:FireServer("RestorationService", "ApplyScratchPolish", Image)
	end
	return Image
end

function Cleaningcontroller:TryCleanInk(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Image = self:GetInkImage(Part, Worldposition, Worldnormal)
	if not Image then return nil end
	if os.clock() - self.lastInkRequest >= Inkcleaninterval then
		local Points = Takepoints(Image)
		if Points then
			self.lastInkRequest = os.clock()
			Remotemanager:FireServer("RestorationService", "CleanInk", Image, Points)
		end
	end
	return Image
end

function Cleaningcontroller:TryCleanScratch(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Image = self:GetScratchImage(Part, Worldposition, Worldnormal)
	if not Image then return nil end
	if os.clock() - self.lastScratchRequest >= Scratchcleaninterval then
		local Points = Takepoints(Image)
		if Points then
			self.lastScratchRequest = os.clock()
			Remotemanager:FireServer("RestorationService", "CleanScratch", Image, Points)
		end
	end
	return Image
end

function Cleaningcontroller:TryCleanDirt(Hit: Surfacecast.Hit, Toolname: string)
	if Core:GetController("InspectionCameraController"):IsDragging() then return end
	local Radiusscale = if Toolname == "CottonTip" then Cottonscale else Brushscale
	self:EraseCleanedLeftovers(Hit.Instance, Hit.Position, Hit.DecalNormal, Radiusscale)
	if not self:EraseDirtOverlay(Hit.Instance, Hit.Position, Hit.DecalNormal, Radiusscale) then
		self:QueuePing(Hit.Position)
	end
	self:SendDirt(Toolname)
end

function Cleaningcontroller:TryCleanCotton(Hit: Surfacecast.Hit)
	if Core:GetController("InspectionCameraController"):IsDragging() then return end

	self:EraseCleanedLeftovers(Hit.Instance, Hit.Position, Hit.DecalNormal, Brushscale)
	local Ink = self:GetInkImage(Hit.Instance, Hit.Position, Hit.DecalNormal)
	if Ink then
		if Ink:GetAttribute("HasSolvent") ~= true then return end
		self:EraseTextureAt(Hit.Instance, Hit.Position, Hit.DecalNormal, Ink, Brushscale)
		self:TryCleanInk(Hit.Instance, Hit.Position, Hit.DecalNormal)
		return
	end

	local Scratch = self:GetScratchImage(Hit.Instance, Hit.Position, Hit.DecalNormal)
	if Scratch then
		if Scratch:GetAttribute("HasPolish") ~= true then return end
		self:EraseTextureAt(Hit.Instance, Hit.Position, Hit.DecalNormal, Scratch, Brushscale)
		self:TryCleanScratch(Hit.Instance, Hit.Position, Hit.DecalNormal)
		return
	end

	if not self:EraseDirtOverlay(Hit.Instance, Hit.Position, Hit.DecalNormal, Cottonscale) then
		self:QueuePing(Hit.Position)
	end
	self:SendDirt("CottonTip")
end

function Cleaningcontroller:TryClean(Hit: Surfacecast.Hit?, Toolname: string)
	if os.clock() - self.lastRequest < 0.05 then return end
	if Core:GetController("InspectionCameraController"):IsDragging() then return end
	if Hit and Hit.Instance:GetAttribute("SpotKind") then
		self.lastRequest = os.clock()
		Remotemanager:FireServer("RestorationService", "CleanSpot", Hit.Instance, Toolname)
	end
end

return Cleaningcontroller
