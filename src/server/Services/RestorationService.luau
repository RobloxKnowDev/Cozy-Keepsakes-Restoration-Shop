local Assetservice = game:GetService("AssetService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Serverstorage = game:GetService("ServerStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Cleaningconfig = require(Replicatedstorage.Shared.Config.Cleaning)
local Config = require(Replicatedstorage.Shared.Config.Object)
local Mutationconfig = require(Replicatedstorage.Shared.Config.Mutation)
local Mutationvfx = require(Replicatedstorage.Shared.Utils.MutationVfx)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)
local Getobjectrotation = require(Replicatedstorage.Shared.Utils.ObjectRotation)
local Roundedtexture = require(Replicatedstorage.Shared.Utils.RoundedTexture)
local Facemapping = require(Replicatedstorage.Shared.Utils.FaceMapping)
local Restorationpercent = require(Replicatedstorage.Shared.Utils.RestorationPercent)
local Stainlayout = require(Replicatedstorage.Shared.Utils.StainLayout)
local Surfacecast = require(Replicatedstorage.Shared.Utils.SurfaceCast)

local Restorationservice = {
	Name = "RestorationService",
	Priority = 10,
	Remotes = {
		BeginSession = "Function",
		BeginItem = "Function",
		BeginPeel = "Function",
		ApplyInkSolvent = "Event",
		ApplyScratchPolish = "Event",
		CleanInk = "Event",
		CleanDirt = "Event",
		GetLeftovers = "Function",
		LeftoversCleared = "Event",
		CleanScratch = "Event",
		CompleteRestoration = "Function",
		CompletePeel = "Event",
		CancelPeel = "Event",
		SessionEnded = "Event",
		UseCleanAll = "Function",
	},
}

local Dirtcleaninterval = 0.05
local Dirtburst = 3
local Stainburst = 16
local Coveragegridwidth = Cleaningconfig.CoverageGrid
local Coveragecellcount = Coveragegridwidth * Coveragegridwidth
local Brushradii = { CottonTip = 1 / 12, ToothBrush = 3 / 32 }
local Stainbrushradius = Brushradii.ToothBrush
local Maxcleanpoints = 32
local Maxdirtstrokes = 8
local Finishassist = Cleaningconfig.FinishAssist
local Pingstart = math.min(Finishassist.Start, Finishassist.StallStart)
local Dirtversion = 5
local Scratchversion = 5
local Meshcastversion = 3
local Mindirtshareversion = 4
local Premarkframebudget = 0.005
local Dirtsurfacenames = {
	UiTop = true,
	UiBottom = true,
	UiLeft = true,
	UiRight = true,
	UiFront = true,
	UiBack = true,
}
local Dirtdecalnames = Cleaningconfig.DirtDecals
local Dirttools = { CottonTip = true, ToothBrush = true }
local Cleanalltool = "CleanAll"
local Dirttargetfloor = 0.4
local Dirtzindex = 0
for _, Texture in ipairs(Cleaningconfig.DirtTextures) do
	Dirtzindex = math.max(Dirtzindex, Texture.ZIndex)
end
local Stainframes = { Ink = "Ink", ScratchesFrame = "Scratch" }
local Stainkinds = {
	Ink = { Decal = "InkStain", Liquid = "HasSolvent", Zindex = Dirtzindex + 2 },
	Scratch = { Decal = "ScratchStain", Liquid = "HasPolish", Zindex = Dirtzindex + 1 },
}
local Stainedge = 1e-6
local Stampslack = 1e-6
local Stainmaximumspan = 2
local Randomscratch = Cleaningconfig.RandomScratch
local Scratchtextures = Cleaningconfig.ScratchTextures
local Scratchshape = { Ratio = 0, Inset = 0 }
local Scratchseedoffset = 2654435769
local Scratchpixelsperstud = 100
local Scratchfallbackcells = math.max(1, math.ceil(Randomscratch.MinCells / 2))
local Downwardlimit = -0.5
local Turnedfaces = { Top = true, Bottom = true }
type CoverageEntry = {
	Cells: { number },
	Hits: number,
	Free: number,
	Premarked: number,
	Passes: number,
	Units: number,
	Alpha: { number },
	Kind: string?,
	Source: ImageLabel?,
}
local Coverage: { [RestorationObject]: { [Instance]: CoverageEntry } } = {}

type CoverageMask = { Alpha: { number }, Premarked: number }
local Visiblealpha = 32
local Dirtfadestep = math.ceil(255 / Cleaningconfig.DirtPasses)
local Strokeinterval = 0.075
local Strokeefficiency = 0.55
local Maskcache: { [string]: CoverageMask } = {}
local Solidalpha = table.create(Coveragecellcount, 255)
local Reachability: { [string]: buffer } = {}
local Warmqueue: { string } = {}
local Coldtemplates: { [string]: boolean } = {}
local Warming = false
local Objecttemplates: Folder
local Warmworld: WorldModel
local Frontfacerank = { Front = 1, Back = 2, Top = 3, Left = 4, Right = 5, Bottom = 6 }
local Workbenchturndegrees = -90

local function Buildmask(Image: string, Shape): CoverageMask
	local Key = Image .. "|" .. Roundedtexture.GetKey(Shape)
	local Cached = Maskcache[Key]
	if Cached then
		return Cached
	end
	local Editable = Assetservice:CreateEditableImageAsync(Content.fromUri(Image))
	local Size = Editable.Size
	local Pixels = Editable:ReadPixelsBuffer(Vector2.zero, Size)
	Editable:Destroy()
	local Width, Height = Size.X, Size.Y
	local Iscut = Roundedtexture.IsCut(Shape)
	local Bounds = Roundedtexture.GetBounds(Width, Height, Shape)
	local Alpha = table.create(Coveragecellcount, 0)
	local Premarked = 0
	for Row = 0, Coveragegridwidth - 1 do
		local Minpixely = math.floor(Row * Height / Coveragegridwidth)
		local Maxpixely = math.floor((Row + 1) * Height / Coveragegridwidth) - 1
		for Column = 0, Coveragegridwidth - 1 do
			local Minpixelx = math.floor(Column * Width / Coveragegridwidth)
			local Maxpixelx = math.floor((Column + 1) * Width / Coveragegridwidth) - 1
			local Darkest = 0
			for Y = Minpixely, Maxpixely, 2 do
				for X = Minpixelx, Maxpixelx, 2 do
					local Value = buffer.readu8(Pixels, (Y * Width + X) * 4 + 3)
					if Value > Darkest and (not Iscut or not Roundedtexture.IsOutside(X, Y, Bounds)) then
						Darkest = Value
					end
				end
			end
			Alpha[Row * Coveragegridwidth + Column + 1] = Darkest
			if Darkest <= Visiblealpha then
				Premarked += 1
			end
		end
	end
	local Mask = { Alpha = Alpha, Premarked = Premarked }
	Maskcache[Key] = Mask
	return Mask
end

local function Warmmasks(Object: RestorationObject)
	local Missing = {}
	local Remaining = 0
	local function Addmissing(Image: string, Shape)
		local Key = Image .. "|" .. Roundedtexture.GetKey(Shape)
		if not Maskcache[Key] and not Missing[Key] then
			Missing[Key] = { Image = Image, Shape = Shape }
			Remaining += 1
		end
	end
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("ImageLabel") and Descendant.Name == "Texture" and Stainframes[Descendant.Parent.Name] then
			Addmissing(Descendant.Image, Roundedtexture.GetShape(Descendant))
		elseif Descendant:IsA("Decal") and Dirtdecalnames[Descendant.Name] then
			local Shape = Roundedtexture.GetShape(Descendant)
			Addmissing(Descendant.Texture, Shape)
			for _, Texture in ipairs(Cleaningconfig.DirtTextures) do
				Addmissing(Texture.Image, Shape)
			end
		end
	end
	if Remaining == 0 then
		return
	end
	for _, Entry in pairs(Missing) do
		task.spawn(function()
			pcall(Buildmask, Entry.Image, Entry.Shape)
			Remaining -= 1
		end)
	end
	local Deadline = os.clock() + 5
	while Remaining > 0 and os.clock() < Deadline do
		task.wait()
	end
end

local function Buildcoverageentry(Source: Instance, Image: string, Passes: number, Units: number): CoverageEntry
	local Success, Mask = pcall(Buildmask, Image, Roundedtexture.GetShape(Source))
	if not Success then
		warn("RestorationService: could not read " .. Image .. ": " .. tostring(Mask))
		return {
			Cells = table.create(Coveragecellcount, 0),
			Hits = 0,
			Free = 0,
			Premarked = 0,
			Passes = Passes,
			Units = Units,
			Alpha = table.create(Coveragecellcount, 255),
		}
	end
	assert(Mask.Premarked < Coveragecellcount, "RestorationService: " .. Source:GetFullName() .. " is fully transparent")
	local Cells = table.create(Coveragecellcount, 0)
	local Free = 0
	for Index, Alpha in ipairs(Mask.Alpha) do
		local Needed = if Alpha > Visiblealpha then math.min(math.ceil((Alpha - Visiblealpha) / Dirtfadestep), Passes) else 0
		Cells[Index] = Passes - Needed
		Free += Passes - Needed
	end
	return { Cells = Cells, Hits = Free, Free = Free, Premarked = Mask.Premarked, Passes = Passes, Units = Units, Alpha = Mask.Alpha }
end

local function Stainseparated(Origin: Vector2, Along: Vector2, Across: Vector2, Maskcolumn: number, Maskrow: number): boolean
	local Normalx, Normaly = -Along.Y, Along.X
	local Scale = math.sqrt(Normalx * Normalx + Normaly * Normaly) * Coveragegridwidth
	local Low = (Origin.X * Normalx + Origin.Y * Normaly) * Coveragegridwidth / Scale
	local Span = (Across.X * Normalx + Across.Y * Normaly) / Scale
	local Middle = ((Maskcolumn + 0.5) * Normalx + (Maskrow + 0.5) * Normaly) / Scale
	local Reach = 0.5 * (math.abs(Normalx) + math.abs(Normaly)) / Scale
	return math.min(Low + math.max(Span, 0), Middle + Reach) - math.max(Low + math.min(Span, 0), Middle - Reach) <= Stainedge
end

local function Stainalpha(Layout: Stainlayout.Layout, Alpha: { number }, Column: number, Row: number): number
	local Origin = Stainlayout.GetTexturePoint(Layout, Vector2.new(Column / Coveragegridwidth, Row / Coveragegridwidth))
	local Lowu, Lowv, Highu, Highv = math.huge, math.huge, -math.huge, -math.huge
	for Corner = 0, 3 do
		local Point = Stainlayout.GetTexturePoint(
			Layout,
			Vector2.new((Column + Corner % 2) / Coveragegridwidth, (Row + Corner // 2) / Coveragegridwidth)
		)
		Lowu, Highu = math.min(Lowu, Point.X), math.max(Highu, Point.X)
		Lowv, Highv = math.min(Lowv, Point.Y), math.max(Highv, Point.Y)
	end
	Lowu, Lowv = math.max(Lowu, 0) + Stainedge, math.max(Lowv, 0) + Stainedge
	Highu, Highv = math.min(Highu, 1) - Stainedge, math.min(Highv, 1) - Stainedge
	if Lowu >= Highu or Lowv >= Highv then
		return 0
	end
	local Darkest = 0
	for Maskrow = math.floor(Lowv * Coveragegridwidth), math.ceil(Highv * Coveragegridwidth) - 1 do
		for Maskcolumn = math.floor(Lowu * Coveragegridwidth), math.ceil(Highu * Coveragegridwidth) - 1 do
			local Value = Alpha[Maskrow * Coveragegridwidth + Maskcolumn + 1]
			if
				Value > Darkest
				and not Stainseparated(Origin, Layout.Inverseu, Layout.Inversev, Maskcolumn, Maskrow)
				and not Stainseparated(Origin, Layout.Inversev, Layout.Inverseu, Maskcolumn, Maskrow)
			then
				Darkest = Value
			end
		end
	end
	return Darkest
end

local function Buildstainentry(Layout: Stainlayout.Layout, Kind: string, Alpha: { number }): CoverageEntry
	local Cells = table.create(Coveragecellcount, 1)
	local Facealpha = table.create(Coveragecellcount, 0)
	local Free = Coveragecellcount
	local Minimum, Maximum = Layout.Minimum, Layout.Maximum
	local Firstcolumn = math.max(math.floor(Minimum.X * Coveragegridwidth), 0)
	local Lastcolumn = math.min(math.ceil(Maximum.X * Coveragegridwidth), Coveragegridwidth) - 1
	for Row = math.max(math.floor(Minimum.Y * Coveragegridwidth), 0), math.min(math.ceil(Maximum.Y * Coveragegridwidth), Coveragegridwidth) - 1 do
		for Column = Firstcolumn, Lastcolumn do
			local Index = Row * Coveragegridwidth + Column + 1
			Facealpha[Index] = Stainalpha(Layout, Alpha, Column, Row)
			if Facealpha[Index] > Visiblealpha then
				Cells[Index] = 0
				Free -= 1
			end
		end
	end
	return { Cells = Cells, Hits = Free, Free = Free, Premarked = Free, Passes = 1, Units = 1, Alpha = Facealpha, Kind = Kind, Source = Layout.Texture }
end

local function Brushfootprint(Entry: CoverageEntry, Radius: Vector2): number
	local Required = 0
	for Index = 1, Coveragecellcount do
		if Entry.Cells[Index] < Entry.Passes then
			Required += 1
		end
	end
	local Half = Coveragegridwidth / 2
	local Ellipse = math.pi * math.min(Radius.X * Coveragegridwidth, Half) * math.min(Radius.Y * Coveragegridwidth, Half)
	return math.min(Ellipse, math.max(Required, 1))
end

local function Dirtstep(Entries: { CoverageEntry }, Footprints: { number }, Target: number): number
	local Speed = Cleaningconfig.CleaningSpeed
	local Weights = table.create(255 - Visiblealpha, 0)
	for Position, Entry in ipairs(Entries) do
		for Index, Alpha in ipairs(Entry.Alpha) do
			if Entry.Cells[Index] < Entry.Passes then
				Weights[Alpha - Visiblealpha] += 1 / Footprints[Position]
			end
		end
	end
	local function Duration(Step: number): number
		local Total = 0
		for Depth, Weight in ipairs(Weights) do
			Total += Weight * math.ceil(Depth / Step)
		end
		return Total * Strokeinterval / Strokeefficiency
	end
	local Baseduration = Duration(Dirtfadestep)
	if Baseduration <= 0 then
		return Dirtfadestep
	end
	local Multiplier = math.clamp(
		Speed.BaseCleaningSpeed * Baseduration / Target,
		Speed.MinCleaningMultiplier,
		Speed.MaxCleaningMultiplier
	)
	local Wanted = Baseduration / Multiplier
	local Low, High = 1, 255
	while Low < High do
		local Middle = (Low + High) // 2
		if Duration(Middle) <= Wanted then
			High = Middle
		else
			Low = Middle + 1
		end
	end
	return Low
end

local function Restepentry(Entry: CoverageEntry, Step: number)
	local Passes = math.ceil((255 - Visiblealpha) / Step)
	local Free = 0
	for Index, Alpha in ipairs(Entry.Alpha) do
		local Credited = if Entry.Cells[Index] < Entry.Passes then Passes - math.ceil((Alpha - Visiblealpha) / Step) else Passes
		Entry.Cells[Index] = Credited
		Free += Credited
	end
	Entry.Passes = Passes
	Entry.Free = Free
	Entry.Hits = Free
end

local function Lazycaster(Object: RestorationObject, Version: number)
	local Caster: any = nil
	local Complete = true
	local function Get(): (any, boolean)
		if not Caster then
			local Created = Surfacecast.new(Object)
			if Version >= Meshcastversion then
				Complete = Created:Load()
			end
			Caster = Created
		end
		return Caster, Complete
	end
	local function Release(): boolean
		if not Caster then
			return false
		end
		Caster:Destroy()
		return true
	end
	return Get, Release
end

local function Knownbuffer(Key: string): buffer
	local Known = Reachability[Key]
	if not Known then
		Known = buffer.create(Coveragecellcount)
		Reachability[Key] = Known
	end
	return Known
end

local function Knowncells(Objectkey: string, Version: number, Decal: Decal): buffer
	return Knownbuffer(Objectkey .. "|" .. math.min(Version, Meshcastversion) .. "|" .. (Decal:GetAttribute("DirtSlot") :: number))
end

local function Stainknowncells(Objectkey: string, Version: number, Surface: SurfaceGui): buffer
	if Surface:GetAttribute("Generated") == true then
		return Knownbuffer(Objectkey .. "|" .. math.min(Version, Meshcastversion) .. "|" .. (Surface:GetAttribute("DirtSlot") :: number))
	end
	return Knownbuffer(Objectkey .. "|" .. math.min(Version, Meshcastversion) .. "|S" .. (Surface:GetAttribute("StainSlot") :: number))
end

local function Resolvereach(Object: RestorationObject, Getcaster: () -> (any, boolean), Decal: Decal, Known: buffer, Entry: CoverageEntry?): buffer
	local Part = Decal.Parent :: BasePart
	local Facename = Decal.Face.Name
	local Worldnormal = Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Decal.Face))
	local Objectsize = if Object:IsA("Model") then Object:GetExtentsSize() else Object.Size
	local Distance = Objectsize.Magnitude + 1
	local Length = Distance + Part.Size.Magnitude
	local Resolved = Known
	local Started = os.clock()
	for Row = 0, Coveragegridwidth - 1 do
		for Column = 0, Coveragegridwidth - 1 do
			local Index = Row * Coveragegridwidth + Column + 1
			if buffer.readu8(Resolved, Index - 1) == 0 and (not Entry or Entry.Cells[Index] < Entry.Passes) then
				local Localpoint = Facemapping.GetDecalLocalPoint(
					Part.Size,
					Facename,
					(Column + 0.5) / Coveragegridwidth,
					(Row + 0.5) / Coveragegridwidth
				)
				local Origin = Part.CFrame:PointToWorldSpace(Localpoint) + Worldnormal * Distance
				local Caster, Complete = Getcaster()
				if not Complete and Resolved == Known then
					Resolved = buffer.create(Coveragecellcount)
					buffer.copy(Resolved, 0, Known)
				end
				local Hit = Caster:Cast(Origin, -Worldnormal * Length)
				local Unreachable = not Hit or Hit.Instance ~= Part or not Facemapping.ShowsDecal(Decal, Hit.DecalNormal)
				buffer.writeu8(Resolved, Index - 1, if Unreachable then 2 else 1)
				if os.clock() - Started > Premarkframebudget then
					task.wait()
					Started = os.clock()
				end
			end
		end
	end
	return Resolved
end

local function Premarkunreachable(Entry: CoverageEntry, Object: RestorationObject, Getcaster: () -> (any, boolean), Decal: Decal, Known: buffer): boolean
	local Resolved = Resolvereach(Object, Getcaster, Decal, Known, Entry)
	for Index = 1, Coveragecellcount do
		if Entry.Cells[Index] < Entry.Passes and buffer.readu8(Resolved, Index - 1) == 2 then
			Entry.Free += Entry.Passes - Entry.Cells[Index]
			Entry.Hits += Entry.Passes - Entry.Cells[Index]
			Entry.Cells[Index] = Entry.Passes
			Entry.Premarked += 1
		end
	end
	return Entry.Premarked < Coveragecellcount
end

local function Findsticker(Object: RestorationObject): BasePart?
	local Sticker = if Config.Object[Object.Name].Sticker then Object:FindFirstChild("Sticker") else nil
	if not Sticker then
		return nil
	end
	assert(Sticker:IsA("BasePart"), "RestorationService: " .. Sticker:GetFullName() .. " must be a BasePart")
	Sticker.CanCollide = false
	Sticker.CanQuery = false
	return Sticker
end

local function Collectstains(Object: RestorationObject, Sticker: BasePart?): { Stainlayout.Layout }
	local Layouts = {}
	local Inked = {}
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if not Descendant:IsA("GuiObject") then
			continue
		end
		assert(Descendant.Name ~= "DirtFrame", "RestorationService: " .. Descendant:GetFullName() .. " is no longer used, delete it")
		local Kind = Stainframes[Descendant.Name]
		if not Kind then
			continue
		end
		assert(
			Kind ~= "Scratch" or Descendant:GetAttribute("Generated") == true or Object.Name == Config.Offer.TutorialObject,
			"RestorationService: " .. Descendant:GetFullName() .. " is no longer used, scratches are generated by the game: delete it"
		)
		local Surface = Descendant.Parent
		assert(Surface and Surface:IsA("SurfaceGui"), "RestorationService: " .. Descendant:GetFullName() .. " must be inside a SurfaceGui")
		assert(Dirtsurfacenames[Surface.Name], "RestorationService: " .. Surface:GetFullName() .. " must use a valid Ui name")
		local Part = Surface.Parent
		assert(Part and Part:IsA("BasePart"), "RestorationService: " .. Surface:GetFullName() .. " must be inside a BasePart")
		assert(
			not Sticker or Part ~= Sticker and not Part:IsDescendantOf(Sticker),
			"RestorationService: " .. Surface:GetFullName() .. " must not be on the Sticker, the peel destroys it"
		)
		assert(Surface.Enabled, "RestorationService: " .. Surface:GetFullName() .. " must be enabled")
		assert(
			Surface.Face.Name == string.sub(Surface.Name, 3),
			"RestorationService: the face of " .. Surface:GetFullName() .. " does not match its name"
		)
		assert(Descendant.Visible, "RestorationService: " .. Descendant:GetFullName() .. " must be visible")
		if Kind == "Ink" then
			assert(not Inked[Surface], "RestorationService: " .. Surface:GetFullName() .. " has more than one Ink, keep a single Ink per SurfaceGui")
			Inked[Surface] = true
		end
		local Texture = Descendant:FindFirstChild("Texture")
		assert(Texture, "RestorationService: " .. Descendant:GetFullName() .. " has no Texture, add an ImageLabel named Texture")
		assert(Texture:IsA("ImageLabel"), "RestorationService: " .. Texture:GetFullName() .. " must be an ImageLabel")
		assert(Texture.Visible, "RestorationService: " .. Texture:GetFullName() .. " must be visible")
		assert(
			Texture.ImageTransparency < 1,
			"RestorationService: " .. Texture:GetFullName() .. " is invisible (ImageTransparency 1), lower its ImageTransparency"
		)
		local Layout = Stainlayout.GetLayout(Texture)
		assert(
			math.max(Layout.Axisu.Magnitude, Layout.Axisv.Magnitude) <= Stainmaximumspan,
			"RestorationService: "
				.. Texture:GetFullName()
				.. " is more than twice the size of the "
				.. Layout.Facename
				.. " face of "
				.. Layout.Part:GetFullName()
				.. ", make it smaller than that face"
		)
		table.insert(Layouts, Layout)
	end
	return Layouts
end

local function Createstaindecal(Layout: Stainlayout.Layout, Kind: string): Decal
	local Decal = Instance.new("Decal")
	Decal.Name = Stainkinds[Kind].Decal
	Decal.Face = Layout.Face
	Decal.Texture = Layout.Texture.Image
	Decal.ZIndex = Stainkinds[Kind].Zindex
	Decal.Transparency = 1
	Decal:SetAttribute("Cleaned", false)
	local Source = Instance.new("ObjectValue")
	Source.Name = "Source"
	Source.Value = Layout.Texture
	Source.Parent = Decal
	Decal.Parent = Layout.Part
	return Decal
end

type ScratchSlot = {
	Part: BasePart,
	Face: Enum.NormalId,
	Facename: string,
	Dirtslot: number,
	Reach: buffer,
	Forbidden: { boolean },
	Allowed: { number },
	Area: number,
	Cellarea: number,
	Shortside: number,
	Canvas: Vector2,
}

type ScratchCandidate = {
	Slot: ScratchSlot,
	Centre: Vector2,
	Side: number,
	Rotation: number,
	Entry: CoverageEntry,
	Inside: boolean,
	Reachable: number,
	Share: number,
}

local function Scratchmask(Image: string): { number }
	local Success, Mask = pcall(Buildmask, Image, Scratchshape)
	if Success then
		return Mask.Alpha
	end
	warn("RestorationService: could not read the scratch texture " .. Image .. ", it is placed as a full square: " .. tostring(Mask))
	local Solid = { Alpha = Solidalpha, Premarked = 0 }
	Maskcache[Image .. "|" .. Roundedtexture.GetKey(Scratchshape)] = Solid
	return Solid.Alpha
end

local function Clipslab(Start: number, Speed: number, Extent: number, Low: number, High: number): (number, number)
	if math.abs(Speed) < 1e-9 then
		if math.abs(Start) > Extent then
			return 1, 0
		end
		return Low, High
	end
	local First, Second = (-Extent - Start) / Speed, (Extent - Start) / Speed
	return math.max(Low, math.min(First, Second)), math.min(High, math.max(First, Second))
end

local function Raymeetsbox(Origin: Vector3, Direction: Vector3, Half: Vector3): boolean
	local Low, High = Clipslab(Origin.X, Direction.X, Half.X, 0, math.huge)
	Low, High = Clipslab(Origin.Y, Direction.Y, Half.Y, Low, High)
	Low, High = Clipslab(Origin.Z, Direction.Z, Half.Z, Low, High)
	return Low <= High
end

local function Forbidaround(Slot: ScratchSlot, Index: number)
	local Column, Row = (Index - 1) % Coveragegridwidth, (Index - 1) // Coveragegridwidth
	for Nearrow = math.max(Row - 1, 0), math.min(Row + 1, Coveragegridwidth - 1) do
		for Nearcolumn = math.max(Column - 1, 0), math.min(Column + 1, Coveragegridwidth - 1) do
			Slot.Forbidden[Nearrow * Coveragegridwidth + Nearcolumn + 1] = true
		end
	end
end

local function Forbidsticker(Slot: ScratchSlot, Sticker: BasePart, Inflate: number)
	local Part = Slot.Part
	local Half = Sticker.Size / 2 + Vector3.new(Inflate, Inflate, Inflate)
	local Normal = Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Slot.Face))
	local Depth = math.abs(Vector3.FromNormalId(Slot.Face):Dot(Part.Size)) / 2
	local Lowu, Lowv, Highu, Highv = math.huge, math.huge, -math.huge, -math.huge
	local Outward = false
	for Corner = 0, 7 do
		local Point = Sticker.CFrame:PointToWorldSpace(Half * Vector3.new(Corner % 2 * 2 - 1, Corner // 2 % 2 * 2 - 1, Corner // 4 * 2 - 1))
		local Facepoint = Facemapping.GetDecalPoint(Part, Point, Slot.Facename)
		Lowu, Highu = math.min(Lowu, Facepoint.X), math.max(Highu, Facepoint.X)
		Lowv, Highv = math.min(Lowv, Facepoint.Y), math.max(Highv, Facepoint.Y)
		Outward = Outward or Normal:Dot(Point - Part.Position) >= Depth
	end
	if not Outward then
		return
	end
	local Direction = Sticker.CFrame:VectorToObjectSpace(Normal)
	for Row = math.max(math.floor(Lowv * Coveragegridwidth), 0), math.min(math.floor(Highv * Coveragegridwidth), Coveragegridwidth - 1) do
		for Column = math.max(math.floor(Lowu * Coveragegridwidth), 0), math.min(math.floor(Highu * Coveragegridwidth), Coveragegridwidth - 1) do
			local Point = Part.CFrame:PointToWorldSpace(
				Facemapping.GetDecalLocalPoint(Part.Size, Slot.Facename, (Column + 0.5) / Coveragegridwidth, (Row + 0.5) / Coveragegridwidth)
			)
			if Raymeetsbox(Sticker.CFrame:PointToObjectSpace(Point), Direction, Half) then
				Slot.Forbidden[Row * Coveragegridwidth + Column + 1] = true
			end
		end
	end
end

local function Refreshslot(Slot: ScratchSlot)
	local Allowed = {}
	for Index = 1, Coveragecellcount do
		if buffer.readu8(Slot.Reach, Index - 1) == 1 and not Slot.Forbidden[Index] then
			table.insert(Allowed, Index)
		end
	end
	Slot.Allowed = Allowed
	Slot.Area = #Allowed * Slot.Cellarea
end

local function Scratchslots(
	Object: RestorationObject,
	Sticker: BasePart?,
	Stains: { Stainlayout.Layout },
	Version: number,
	Getcaster: () -> (any, boolean),
	Inflate: number
): { ScratchSlot }
	local Slots = {}
	local Taken: { [Instance]: { [string]: boolean } } = {}
	local Started = os.clock()
	for _, Decal in ipairs(Object:GetDescendants()) do
		if not Decal:IsA("Decal") or not Dirtdecalnames[Decal.Name] then
			continue
		end
		local Part = Decal.Parent :: BasePart
		assert(Part:IsA("BasePart"), "RestorationService: " .. Decal:GetFullName() .. " must be inside a BasePart")
		local Facename = Decal.Face.Name
		local Faces = Taken[Part] or {}
		Taken[Part] = Faces
		if Faces[Facename] or Sticker and (Part == Sticker or Part:IsDescendantOf(Sticker)) then
			continue
		end
		Faces[Facename] = true
		if Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Decal.Face)).Y < Downwardlimit then
			continue
		end
		local Extent = Facemapping.GetDecalSize(Part.Size, Facename)
		local Slot: ScratchSlot = {
			Part = Part,
			Face = Decal.Face,
			Facename = Facename,
			Dirtslot = Decal:GetAttribute("DirtSlot") :: number,
			Reach = Resolvereach(Object, Getcaster, Decal, Knowncells(Object.Name, Version, Decal)),
			Forbidden = table.create(Coveragecellcount, false),
			Allowed = {},
			Area = 0,
			Cellarea = Extent.X * Extent.Y / Coveragecellcount,
			Shortside = math.min(Extent.X, Extent.Y),
			Canvas = if Turnedfaces[Facename] then Vector2.new(Extent.Y, Extent.X) else Extent,
		}
		if Sticker then
			Forbidsticker(Slot, Sticker, Inflate)
		end
		for _, Layout in ipairs(Stains) do
			if Stainframes[Layout.Frame.Name] == "Ink" and Layout.Part == Part and Layout.Face == Decal.Face then
				local Success, Mask = pcall(Buildmask, Layout.Texture.Image, Roundedtexture.GetShape(Layout.Texture))
				local Entry = Buildstainentry(Layout, "Ink", if Success then Mask.Alpha else Solidalpha)
				for Index = 1, Coveragecellcount do
					if Entry.Cells[Index] < Entry.Passes and buffer.readu8(Slot.Reach, Index - 1) == 1 then
						Forbidaround(Slot, Index)
					end
				end
			end
		end
		Refreshslot(Slot)
		table.insert(Slots, Slot)
		if os.clock() - Started > Premarkframebudget then
			task.wait()
			Started = os.clock()
		end
	end
	return Slots
end

local function Pickslot(Slots: { ScratchSlot }, Generator: Random): ScratchSlot?
	local Total = 0
	for _, Slot in ipairs(Slots) do
		Total += Slot.Area
	end
	if Total <= 0 then
		return nil
	end
	local Roll = Generator:NextNumber() * Total
	local Last = nil
	for _, Slot in ipairs(Slots) do
		if Slot.Area > 0 then
			Last = Slot
			Roll -= Slot.Area
			if Roll < 0 then
				return Slot
			end
		end
	end
	return Last
end

local function Newscratchgui(Image: string): (SurfaceGui, Frame, ImageLabel)
	local Surface = Instance.new("SurfaceGui")
	Surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	Surface.PixelsPerStud = Scratchpixelsperstud
	Surface:SetAttribute("Generated", true)
	local Frame = Instance.new("Frame")
	Frame.Name = "ScratchesFrame"
	Frame.BackgroundTransparency = 1
	Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	Frame:SetAttribute("Generated", true)
	local Texture = Instance.new("ImageLabel")
	Texture.Name = "Texture"
	Texture.Image = Image
	Texture.BackgroundTransparency = 1
	Texture.ScaleType = Enum.ScaleType.Stretch
	Texture.Size = UDim2.fromScale(1, 1)
	Texture.Parent = Frame
	Frame.Parent = Surface
	return Surface, Frame, Texture
end

local function Placescratchgui(Surface: SurfaceGui, Frame: GuiObject, Slot: ScratchSlot, Centre: Vector2, Side: number, Rotation: number)
	Surface.Name = "Ui" .. Slot.Facename
	Surface.Face = Slot.Face
	Surface:SetAttribute("DirtSlot", Slot.Dirtslot)
	Frame.Position = if Turnedfaces[Slot.Facename] then UDim2.fromScale(Centre.Y, 1 - Centre.X) else UDim2.fromScale(Centre.X, Centre.Y)
	Frame.Size = UDim2.fromScale(Side / Slot.Canvas.X, Side / Slot.Canvas.Y)
	Frame.Rotation = Rotation
end

local function Betterfallback(Candidate: ScratchCandidate, Best: ScratchCandidate?): boolean
	if not Best then
		return true
	end
	if Candidate.Inside ~= Best.Inside then
		return Candidate.Inside
	end
	if Candidate.Reachable ~= Best.Reachable then
		return Candidate.Reachable > Best.Reachable
	end
	return Candidate.Share > Best.Share
end

local function Removeauthoredscratches(Object: RestorationObject)
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("GuiObject") and Descendant.Name == "ScratchesFrame" then
			Descendant:Destroy()
		end
	end
end

local function Generatescratches(
	Object: RestorationObject,
	Sticker: BasePart?,
	Stains: { Stainlayout.Layout },
	Seed: number,
	Version: number,
	Getcaster: () -> (any, boolean)
)
	local Generator = Random.new(Seed + Scratchseedoffset)
	local Objectsize = if Object:IsA("Model") then Object:GetExtentsSize() else Object.Size
	local Scale = Objectsize.Magnitude / 2
	local Slots = Scratchslots(Object, Sticker, Stains, Version, Getcaster, Cleaningconfig.BrushMinimumRadius * Scale)
	local Holder = Instance.new("Part")
	local Candidate, Candidateframe, Candidatetexture = Newscratchgui(Scratchtextures[1].Image)
	Candidate.Parent = Holder
	local Pool = {}
	local Started = os.clock()
	for _ = 1, Randomscratch.Count do
		if #Pool == 0 then
			for Index = 1, #Scratchtextures do
				Pool[Index] = Index
			end
		end
		local Image = Scratchtextures[table.remove(Pool, Generator:NextInteger(1, #Pool))].Image
		local Alpha = Scratchmask(Image)
		Candidatetexture.Image = Image
		local Chosen: ScratchCandidate? = nil
		local Shrink = 1
		for Attempt = 1, Randomscratch.Attempts do
			local Slot = Pickslot(Slots, Generator)
			if not Slot then
				break
			end
			local Cell = Slot.Allowed[Generator:NextInteger(1, #Slot.Allowed)] - 1
			local Centre = Vector2.new(
				(Cell % Coveragegridwidth + Generator:NextNumber()) / Coveragegridwidth,
				(Cell // Coveragegridwidth + Generator:NextNumber()) / Coveragegridwidth
			)
			local Rotation = Generator:NextNumber() * 360
			local Side = Generator:NextNumber(Randomscratch.Size.Min, Randomscratch.Size.Max) * Scale
			Side = math.max(math.min(Side, Slot.Shortside * Randomscratch.FaceCap) * Shrink, Randomscratch.MinSide)
			Holder.Size = Slot.Part.Size
			Placescratchgui(Candidate, Candidateframe, Slot, Centre, Side, Rotation)
			local Layout = Stainlayout.GetLayout(Candidatetexture)
			if math.max(Layout.Axisu.Magnitude, Layout.Axisv.Magnitude) <= Stainmaximumspan then
				local Entry = Buildstainentry(Layout, "Scratch", Alpha)
				local Required, Reachable, Blocked = 0, 0, false
				for Index = 1, Coveragecellcount do
					if Entry.Cells[Index] < Entry.Passes then
						Required += 1
						Blocked = Blocked or Slot.Forbidden[Index]
						if buffer.readu8(Slot.Reach, Index - 1) == 1 then
							Reachable += 1
						end
					end
				end
				local Inside = Layout.Minimum.X >= 0 and Layout.Minimum.Y >= 0 and Layout.Maximum.X <= 1 and Layout.Maximum.Y <= 1
				local Placed: ScratchCandidate = {
					Slot = Slot,
					Centre = Centre,
					Side = Side,
					Rotation = Rotation,
					Entry = Entry,
					Inside = Inside,
					Reachable = Reachable,
					Share = if Required > 0 then Reachable / Required else 0,
				}
				if Inside and not Blocked and Required >= Randomscratch.MinCells and Reachable >= Required * Randomscratch.MinVisible then
					Chosen = Placed
					break
				end
				if not Blocked and Reachable >= Scratchfallbackcells and Betterfallback(Placed, Chosen) then
					Chosen = Placed
				end
			end
			if Attempt % Randomscratch.ShrinkRun == 0 then
				Shrink *= Randomscratch.Shrink
			end
			if os.clock() - Started > Premarkframebudget then
				task.wait()
				Started = os.clock()
			end
		end
		if not Chosen then
			warn("RestorationService: " .. Object:GetFullName() .. " has no visible dirt face for its random scratch")
			break
		end
		local Surface, Frame = Newscratchgui(Image)
		Placescratchgui(Surface, Frame, Chosen.Slot, Chosen.Centre, Chosen.Side, Chosen.Rotation)
		Surface.Parent = Chosen.Slot.Part
		for Index = 1, Coveragecellcount do
			if Chosen.Entry.Cells[Index] < Chosen.Entry.Passes then
				Forbidaround(Chosen.Slot, Index)
			end
		end
		Refreshslot(Chosen.Slot)
	end
	Holder:Destroy()
end

local function Warmtemplate(Objectkey: string)
	local Object = Objecttemplates:WaitForChild(Objectkey):Clone() :: RestorationObject
	local Getcaster, Releasecaster = Lazycaster(Object, Dirtversion)
	local Success, Failure = pcall(function()
		local Sticker = Findsticker(Object)
		Object.Parent = Warmworld
		for _, Decal in ipairs(Object:GetDescendants()) do
			if Decal:IsA("Decal") and Dirtdecalnames[Decal.Name] then
				local Known = Knowncells(Objectkey, Dirtversion, Decal)
				if Resolvereach(Object, Getcaster, Decal, Known) ~= Known then
					Coldtemplates[Objectkey] = true
					return
				end
			end
		end
		for _, Layout in ipairs(Collectstains(Object, Sticker)) do
			local Kind = Stainframes[Layout.Frame.Name]
			local Known = Stainknowncells(Objectkey, Dirtversion, Layout.Surface)
			if Resolvereach(Object, Getcaster, Createstaindecal(Layout, Kind), Known, Buildstainentry(Layout, Kind, Solidalpha)) ~= Known then
				Coldtemplates[Objectkey] = true
				return
			end
		end
	end)
	Releasecaster()
	Object:Destroy()
	if not Success then
		warn("RestorationService: could not warm " .. Objectkey .. ": " .. tostring(Failure))
	end
end

local function Runwarmup()
	if Warming then
		return
	end
	Warming = true
	task.defer(function()
		while #Warmqueue > 0 do
			Warmtemplate(table.remove(Warmqueue, 1) :: string)
		end
		Warming = false
	end)
end

local function Prioritizewarmup(Objectkey: string)
	local Position = table.find(Warmqueue, Objectkey)
	if Position then
		table.remove(Warmqueue, Position)
	elseif Coldtemplates[Objectkey] then
		Coldtemplates[Objectkey] = nil
	else
		return
	end
	table.insert(Warmqueue, 1, Objectkey)
	Runwarmup()
end

type RestorationObject = Model | BasePart

type ObjectMaximums = {
	MaxValue: number,
	MaxReputation: number,
	Mutation: string,
}

local Mutationbyobject: { [Instance]: string } = {}

local Sessions: { [Player]: RestorationObject } = {}
local Sessionitem: { [Player]: any } = {}
local Dirtallowance: { [Player]: number } = {}
local Stainallowance: { [Player]: { [Instance]: number } } = {}
local Stallevents: { [Player]: number } = {}
local Peeling: { [Player]: BasePart } = {}
local Activeobjects: { [Player]: RestorationObject } = {}
local Pendingcleanall: { [Player]: number } = {}
local Randomgenerator = Random.new()

local function Roundtwodecimals(Value: number): number
	return math.round(Value * 100) / 100
end

local function Randomizemaximum(Value: number): number
	local Minimum = Config.Variation.MinimumPercent / 100
	local Maximum = Config.Variation.MaximumPercent / 100
	return Roundtwodecimals(Value * Randomgenerator:NextNumber(Minimum, Maximum))
end

local function Rollmutation(): string
	local Total = 0
	for _, Name in ipairs(Mutationconfig.Order) do
		Total += Mutationconfig[Name].Weight
	end
	local Roll = Randomgenerator:NextNumber(0, Total)
	local Accumulated = 0
	for _, Name in ipairs(Mutationconfig.Order) do
		Accumulated += Mutationconfig[Name].Weight
		if Roll < Accumulated then
			return Name
		end
	end
	return "Normal"
end

local function Generateobjectmaximums(Objectname: string): ObjectMaximums
	local Definition = Config.Object[Objectname]
	local Mutation = Rollmutation()
	local Multipliers = Mutationconfig[Mutation]
	return {
		MaxValue = Randomizemaximum(Definition.MaxValue) * Multipliers.ValueMultiplier,
		MaxReputation = Randomizemaximum(Definition.Reputation) * Multipliers.ReputationMultiplier,
		Mutation = Mutation,
	}
end

local function Destroyobject(Object: RestorationObject?)
	if Object and Object.Parent then
		Mutationbyobject[Object] = nil
		Coverage[Object] = nil
		Object:Destroy()
	end
end

local function Getcompletionratio(Object: RestorationObject): number
	local Totalspots = tonumber(Object:GetAttribute("TotalSpots")) or 0
	local Cleanedspots = tonumber(Object:GetAttribute("CleanedSpots")) or 0
	if Totalspots <= 0 then
		return 0
	end

	return math.clamp(Cleanedspots / Totalspots, 0, 1)
end

local Mutationbuildupseconds = 1.35

local function Revealmutation(Object: RestorationObject, Immediate: boolean?)
	local Mutation = Mutationbyobject[Object]
	if not Mutation or Object:GetAttribute("Mutation") ~= nil then
		return
	end
	if Getcompletionratio(Object) < Mutationconfig.RevealRatio then
		return
	end
	Object:SetAttribute("Mutation", Mutation)
	if Immediate then
		Mutationvfx.Attach(Object, Mutation)
		return
	end
	task.delay(Mutationconfig.RevealDelaySeconds + Mutationbuildupseconds, function()
		if Object.Parent then
			Mutationvfx.Attach(Object, Mutation)
		end
	end)
end

local function Hidestain(Entry: CoverageEntry)
	local Texture = Entry.Source :: ImageLabel
	local Frame = Texture.Parent :: GuiObject
	Texture:SetAttribute("Remaining", 0)
	Frame:SetAttribute("Cleaned", true)
	Frame.Visible = false
end

local function Completestain(Decal: Instance, Entry: CoverageEntry)
	Hidestain(Entry)
	Decal:SetAttribute("Cleaned", true)
end

local function Dropstain(Object: RestorationObject, Decal: Instance, Entry: CoverageEntry)
	Hidestain(Entry)
	Coverage[Object][Decal] = nil
	Decal:Destroy()
end

local Precleankinds = {
	Scratch = { Kind = "Scratch", Units = 1, Weighted = false },
	Ink = { Kind = "Ink", Units = 1, Weighted = false },
}

local Progresskinds = { "Dirt", "Ink", "Scratch", "Sticker" }
local Precleansnapratio = 0.85

local function Staintextures(Object: RestorationObject): { ImageLabel }
	local Textures = {}
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("GuiObject") and Stainframes[Descendant.Name] then
			table.insert(Textures, Descendant:WaitForChild("Texture") :: ImageLabel)
		end
	end
	return Textures
end

local function Keynumber(Value: number, Decimals: number): string
	local Scale = 10 ^ Decimals
	local Rounded = math.round(Value * Scale)
	if Rounded == 0 then
		return "0"
	end
	local Text = string.format("%." .. Decimals .. "f", Rounded / Scale)
	if Decimals == 0 then
		return Text
	end
	return (string.gsub(string.gsub(Text, "0+$", ""), "%.$", ""))
end

local function Keyudim(Value: UDim2): string
	return Keynumber(Value.X.Scale, 3) .. "," .. Keynumber(Value.X.Offset, 0) .. "," .. Keynumber(Value.Y.Scale, 3) .. "," .. Keynumber(Value.Y.Offset, 0)
end

local function Stainsignature(Texture: ImageLabel): string
	local Frame = Texture.Parent :: GuiObject
	local Surface = Frame.Parent :: SurfaceGui
	local Size = (Surface.Parent :: BasePart).Size
	return table.concat({
		Frame.Name,
		Surface.Name,
		Keynumber(Size.X, 3) .. "," .. Keynumber(Size.Y, 3) .. "," .. Keynumber(Size.Z, 3),
		Keyudim(Frame.Position),
		Keyudim(Frame.Size),
		Keynumber(Frame.Rotation, 2),
		Keynumber(Frame.AnchorPoint.X, 3) .. "," .. Keynumber(Frame.AnchorPoint.Y, 3),
		Keyudim(Texture.Position),
		Keyudim(Texture.Size),
		Keynumber(Texture.Rotation, 2),
		Texture.Image,
	}, "|")
end

local function Stainkeys(Object: RestorationObject): { [string]: ImageLabel }
	local Keys = {}
	for _, Texture in ipairs(Staintextures(Object)) do
		local Signature = Stainsignature(Texture)
		local Key = Signature
		local Count = 1
		while Keys[Key] do
			Count += 1
			Key = Signature .. "#" .. Count
		end
		Keys[Key] = Texture
	end
	return Keys
end

local function Captureprogress(Object: RestorationObject): { [string]: any }
	local Progress: { [string]: any } = {}
	for _, Kind in ipairs(Progresskinds) do
		Progress[Kind] = tonumber(Object:GetAttribute("Cleaned_" .. Kind)) or 0
		Progress[Kind .. "Total"] = Object:GetAttribute("Total_" .. Kind)
	end
	Progress.DirtSeed = Object:GetAttribute("DirtSeed")
	Progress.DirtVersion = Object:GetAttribute("DirtVersion")
	local Stains = {}
	for Key, Texture in pairs(Stainkeys(Object)) do
		Stains[Key] = 1 - (Texture:GetAttribute("Remaining") :: number)
	end
	Progress.Stains = Stains
	return Progress
end

local function Savedstainshares(Object: RestorationObject, Progress: { [string]: any }?): { [Instance]: number }?
	local Saved = if Progress then Progress.Stains else nil
	if type(Saved) ~= "table" or Saved[1] ~= nil then
		return nil
	end
	local Shares = {}
	for Key, Texture in pairs(Stainkeys(Object)) do
		Shares[Texture] = tonumber(Saved[Key]) or 0
	end
	return Shares
end

local function Precleanobject(Object: RestorationObject, Ratio: number, Progress: { [string]: any }?)
	if Ratio <= 0 then
		return
	end
	local Totalspots = tonumber(Object:GetAttribute("TotalSpots")) or 0
	local Target = Totalspots * math.clamp(Ratio, 0, 1)
	local Dirtweight = tonumber(Object:GetAttribute("DirtWeight")) or 1
	local Cleanedbykind = {}
	local Missing = {}
	local Missingtotal = 0
	for _, Kind in ipairs(Progresskinds) do
		local Total = tonumber(Object:GetAttribute("Total_" .. Kind)) or 0
		local Stored = if Progress then tonumber(Progress[Kind]) or 0 else Total * math.clamp(Ratio, 0, 1)
		local Savedtotal = if Progress then tonumber(Progress[Kind .. "Total"]) or 0 else 0
		if Savedtotal > 0 then
			Stored *= Total / Savedtotal
		elseif Progress and Kind ~= "Dirt" and Stored <= 0 and Total > 0 then
			Missing[Kind] = Total
			Missingtotal += Total
		end
		Cleanedbykind[Kind] = math.clamp(Stored, 0, Total)
	end
	if Missingtotal > 0 then
		local Restored = Cleanedbykind.Dirt * Dirtweight + Cleanedbykind.Ink + Cleanedbykind.Scratch + Cleanedbykind.Sticker
		local Shortfall = math.clamp(Target - Restored, 0, Missingtotal)
		for Kind, Total in pairs(Missing) do
			Cleanedbykind[Kind] = Total * Shortfall / Missingtotal
		end
	end

	local Hideable = table.clone(Cleanedbykind)
	local Hidden = {}
	for _, Kind in ipairs(Progresskinds) do
		Hidden[Kind] = 0
	end
	local Cleaned = 0
	local Stainshares = Savedstainshares(Object, Progress)
	for _, Descendant in ipairs(Object:GetDescendants()) do
		local Isdirt = Descendant:IsA("Decal") and Dirtdecalnames[Descendant.Name] == true
		local Stain = if Isdirt then nil else Coverage[Object][Descendant]
		local Entry = if Isdirt
			then { Kind = "Dirt", Units = Coverage[Object][Descendant].Units, Weighted = true }
			elseif Stain then Precleankinds[Stain.Kind]
			else nil
		local Hide = if Stain and Stainshares
			then Stainshares[Stain.Source :: ImageLabel] >= Precleansnapratio
			elseif Entry then Hideable[Entry.Kind] >= Entry.Units * Precleansnapratio
			else false
		if Entry and Hide then
			if Stain then
				Dropstain(Object, Descendant, Stain)
			else
				Coverage[Object][Descendant] = nil
				Descendant:Destroy()
			end
			Hideable[Entry.Kind] = math.max(Hideable[Entry.Kind] - Entry.Units, 0)
			Hidden[Entry.Kind] += Entry.Units
			Cleaned += Entry.Units * (if Entry.Weighted then Dirtweight else 1)
		end
	end
	for _, Kind in ipairs(Progresskinds) do
		local Total = tonumber(Object:GetAttribute("Total_" .. Kind)) or 0
		Cleanedbykind[Kind] = math.max(Cleanedbykind[Kind], Hidden[Kind])
		if Total - Cleanedbykind[Kind] < 0.000001 then
			Cleanedbykind[Kind] = Total
		end
	end
	local Keptdirt = {}
	local Keptpasses = 0
	local Keptstains = { Ink = {}, Scratch = {} }
	for Source, Entry in pairs(Coverage[Object]) do
		if Entry.Kind then
			table.insert(Keptstains[Entry.Kind], Source)
		elseif Source:IsA("Decal") then
			table.insert(Keptdirt, Entry)
			Keptpasses += Coveragecellcount * Entry.Passes - Entry.Free
		end
	end
	for _, Entry in ipairs(Keptdirt) do
		Entry.Units = ((tonumber(Object:GetAttribute("Total_Dirt")) or 0) - Cleanedbykind.Dirt)
			* (Coveragecellcount * Entry.Passes - Entry.Free)
			/ Keptpasses
	end
	for Kind, Decals in pairs(Keptstains) do
		local Left = (tonumber(Object:GetAttribute("Total_" .. Kind)) or 0) - Cleanedbykind[Kind]
		for _, Decal in ipairs(Decals) do
			if Left <= 0 then
				Dropstain(Object, Decal, Coverage[Object][Decal])
			else
				Coverage[Object][Decal].Units = Left / #Decals
			end
		end
	end

	local Sticker = Object.RestorationSpots:FindFirstChild("Sticker")
	if Sticker and Cleanedbykind.Sticker >= 1 then
		Sticker:Destroy()
		Cleaned += 1
	end

	for _, Kind in ipairs(Progresskinds) do
		Object:SetAttribute("Cleaned_" .. Kind, Cleanedbykind[Kind])
	end
	local Restored = if Progress
		then math.min(Cleanedbykind.Dirt * Dirtweight + Cleanedbykind.Ink + Cleanedbykind.Scratch + Cleanedbykind.Sticker, Totalspots)
		else math.max(Cleaned, Target)
	if Totalspots - Restored < 0.000001 then
		Restored = Totalspots
	end
	Object:SetAttribute("CleanedSpots", Restored)
	Revealmutation(Object, true)
end

local function Applyratiotoitem(Item: any, Ratio: number, Object: RestorationObject?)
	if Object then
		Item.Progress = Captureprogress(Object)
	end
	Item.RestorationPercent = Restorationpercent(Ratio)
	Item.CurrentValue = Roundtwodecimals(Item.MaxValue * Ratio)
	Item.Reputation = Roundtwodecimals(Item.MaxReputation * Ratio)
	Item.NetProfit = Roundtwodecimals(Item.CurrentValue - Item.PurchasePrice)
	return Item
end

function Restorationservice:GetSessionItem(Player: Player): any
	local Item = Sessionitem[Player]
	local Object = Sessions[Player]
	if not Item then
		return nil
	end
	return Applyratiotoitem(Item, if Object then Getcompletionratio(Object) else Item.RestorationPercent / 100, Object)
end

local function Returnsessionitem(Player: Player, Object: RestorationObject?)
	local Item = Sessionitem[Player]
	Sessionitem[Player] = nil
	if not Item then
		return
	end
	Applyratiotoitem(Item, if Object then Getcompletionratio(Object) else Item.RestorationPercent / 100, Object)
	Core:GetService("InventoryService"):ReturnRestoredItem(Player, Item)
end

local function Releaseactiveobject(Player: Player)
	Destroyobject(Activeobjects[Player])
	Activeobjects[Player] = nil
end

local function Validsessionspot(Player: Player, Spot: any): (RestorationObject?, boolean)
	local Object = Sessions[Player]
	if not Object or typeof(Spot) ~= "Instance" or not Spot:IsA("BasePart") then
		return Object, false
	end
	local Spots = Object:FindFirstChild("RestorationSpots")
	return Object, Spots ~= nil and Spot:IsDescendantOf(Spots)
end

local function Spawnconfiguredobject(Objectname: string, Shop: Model, Maximums: ObjectMaximums?): RestorationObject
	local Spawnattachment = Shop:WaitForChild("Attachement"):WaitForChild("Spawn") :: Attachment
	local Camerapart = Shop:WaitForChild("Camera"):WaitForChild("CamPart") :: BasePart
	local Definition = Config.Object[Objectname]
	local Asset = Replicatedstorage:WaitForChild("Asset"):WaitForChild("Object"):WaitForChild(Objectname)
	local Object = Asset:Clone() :: RestorationObject
	if Objectname == "Skateboard" then
		local Objectcore = Object:WaitForChild("Core")
		local Grip = Objectcore:WaitForChild("Grip")
		local Uitop = Grip:WaitForChild("UiTop") :: SurfaceGui
		Uitop.AlwaysOnTop = false
	end
	local Objectmaximums = Maximums or Generateobjectmaximums(Objectname)
	local Maxvalue = Objectmaximums.MaxValue
	local Maxreputation = Objectmaximums.MaxReputation
	Mutationbyobject[Object] = Objectmaximums.Mutation or "Normal"
	Object.Name = Objectname
	Object:SetAttribute("RestorationObject", true)
	Object:SetAttribute("KeepSpawnPosition", true)
	Object:SetAttribute("ObjectKey", Objectname)
	Object:SetAttribute("SpawnFloorY", Spawnattachment.WorldPosition.Y)
	Object:SetAttribute("DisplayName", Definition.Name or Objectname)
	Object:SetAttribute("MaxPrice", Maxvalue)
	Object:SetAttribute("MaxValue", Maxvalue)
	Object:SetAttribute("Rarity", Definition.Rarity or Definition.Rarety or "Common")
	Object:SetAttribute("ImageId", Definition.IdImage or "")
	Object:SetAttribute("MaxReputation", Maxreputation)
	if Object:IsA("Model") then
		Object.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
	Object.Parent = Shop:WaitForChild("GeneratedItems")
	local Spawnposition = Spawnattachment.WorldPosition
	local Cameralook = Camerapart.CFrame.LookVector
	local Facing = CFrame.lookAt(Spawnposition, Spawnposition - Vector3.new(Cameralook.X, 0, Cameralook.Z))
	local Spawncframe = Facing * CFrame.Angles(0, math.rad(Workbenchturndegrees), 0) * Getobjectrotation(Objectname)
	if Object:IsA("Model") then
		Object:PivotTo(Spawncframe)
	else
		Object.CFrame = Spawncframe
	end

	local Boundscframe, Boundssize
	if Object:IsA("Model") then
		Boundscframe, Boundssize = Object:GetBoundingBox()
	else
		Boundscframe, Boundssize = Object.CFrame, Object.Size
	end
	local Bottomy = Boundscframe.Position.Y - Boundssize.Y * 0.5
	local Heightoffset = Spawnattachment.WorldPosition.Y - Bottomy
	if Object:IsA("Model") then
		Object:PivotTo(Object:GetPivot() + Vector3.new(0, Heightoffset, 0))
	else
		Object.CFrame += Vector3.new(0, Heightoffset, 0)
	end

	return Object
end

local function Facearea(Decal: Decal): number
	local Size = (Decal.Parent :: BasePart).Size
	return Size.X * Size.Y * Size.Z / math.abs(Vector3.FromNormalId(Decal.Face):Dot(Size))
end

local function Pickdirttexture(Generator: Random, Excludedpattern: string?)
	local Choices = {}
	for _, Texture in ipairs(Cleaningconfig.DirtTextures) do
		if Texture.Pattern ~= Excludedpattern then
			table.insert(Choices, Texture)
		end
	end
	return Choices[Generator:NextInteger(1, #Choices)]
end

local function Initializedirt(
	Object: RestorationObject,
	Singleface: boolean,
	Seed: number,
	Version: number,
	Getcaster: () -> (any, boolean),
	Spotseconds: number?
): number
	local Generator = Random.new(Seed)
	local Styled = Version >= 2 and not Singleface
	local Decals = {}
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("Decal") and Dirtdecalnames[Descendant.Name] then
			assert(Descendant.Parent:IsA("BasePart"), "RestorationService: " .. Descendant:GetFullName() .. " must be inside a BasePart")
			table.insert(Decals, Descendant)
		end
	end
	if Singleface then
		local Preferred = Config.Offer.TutorialDirtFace
		local function Facerank(Decal: Decal): number
			if Decal.Face.Name == Preferred then
				return 0
			end
			return Frontfacerank[Decal.Face.Name]
		end
		table.sort(Decals, function(Left, Right)
			local Leftrank, Rightrank = Facerank(Left), Facerank(Right)
			if Leftrank ~= Rightrank then
				return Leftrank < Rightrank
			end
			return Facearea(Left) > Facearea(Right)
		end)
	else
		for Index = #Decals, 2, -1 do
			local Swap = Generator:NextInteger(1, Index)
			Decals[Index], Decals[Swap] = Decals[Swap], Decals[Index]
		end
	end
	local Keptcount = if #Decals == 0 then 0 elseif Singleface then 1 else Generator:NextInteger(1, #Decals)
	local Kept = 0
	local Layers = 0
	local Totaldirt = 0
	local Keptentries = {}
	local Footprints = {}
	local Objectsize = if Object:IsA("Model") then Object:GetExtentsSize() else Object.Size
	local Brushradius = Cleaningconfig.BrushMinimumRadius * Objectsize.Magnitude / 2
	local Totalarea = 0
	local Keptarea = 0
	for _, Decal in ipairs(Decals) do
		Totalarea += Facearea(Decal)
	end
	local Mindirtshare = if Singleface or Version < Mindirtshareversion then 0 else Cleaningconfig.MinDirtShare
	for _, Decal in ipairs(Decals) do
		local Wanted = Kept < Keptcount or Keptarea < Totalarea * Mindirtshare
		local Texture = if Styled and Wanted then Pickdirttexture(Generator, nil) else nil
		if Texture then
			Decal.Texture = Texture.Image
			Decal.ZIndex = Texture.ZIndex
		end
		local Entry = if Wanted then Buildcoverageentry(Decal, Decal.Texture, Cleaningconfig.DirtPasses, 16) else nil
		if Entry and Premarkunreachable(Entry, Object, Getcaster, Decal, Knowncells(Object.Name, Version, Decal)) then
			local Radius = Facemapping.GetBrushRadius((Decal.Parent :: BasePart).Size, Decal.Face.Name, Brushradii.ToothBrush, Brushradius)
			Kept += 1
			Keptarea += Facearea(Decal)
			Coverage[Object][Decal] = Entry
			table.insert(Keptentries, Entry)
			table.insert(Footprints, Brushfootprint(Entry, Radius))
			Decal:SetAttribute("Cleaned", false)
			Totaldirt += 16
			if Texture and Layers < Cleaningconfig.MaxDirtLayers and Generator:NextNumber() < Cleaningconfig.DirtLayerChance then
				local Layertexture = Pickdirttexture(Generator, Texture.Pattern)
				local Layer = Decal:Clone()
				Layer.Texture = Layertexture.Image
				Layer.ZIndex = Layertexture.ZIndex
				Layer.Parent = Decal.Parent
				local Layerentry = Buildcoverageentry(Layer, Layer.Texture, Cleaningconfig.DirtPasses, 16)
				if Premarkunreachable(Layerentry, Object, Getcaster, Layer, Knowncells(Object.Name, Version, Layer)) then
					Layers += 1
					Coverage[Object][Layer] = Layerentry
					table.insert(Keptentries, Layerentry)
					table.insert(Footprints, Brushfootprint(Layerentry, Radius))
					Totaldirt += 16
				else
					Layer:Destroy()
				end
			end
		else
			Decal:Destroy()
		end
	end
	local Speed = Cleaningconfig.CleaningSpeed
	local Target = Speed.TargetCleaningDuration * Speed.RarityDuration[Object:GetAttribute("Rarity")] * Keptarea / Totalarea
	local Dirttarget = math.max(Target - (Spotseconds or 0), Target * Dirttargetfloor)
	local Step = if Singleface then Dirtfadestep else Dirtstep(Keptentries, Footprints, Dirttarget)
	local Opaquepasses = 0
	for _, Entry in ipairs(Keptentries) do
		Restepentry(Entry, Step)
		Opaquepasses += Coveragecellcount * Entry.Passes - Entry.Free
	end
	for _, Entry in ipairs(Keptentries) do
		Entry.Units = Totaldirt * (Coveragecellcount * Entry.Passes - Entry.Free) / Opaquepasses
	end
	Object:SetAttribute("DirtSeed", Seed)
	Object:SetAttribute("DirtVersion", Version)
	Object:SetAttribute("DirtStep", Step)
	Object:SetAttribute("BrushRadius", Brushradius)
	Object:SetAttribute("Total_Dirt", Totaldirt)
	Object:SetAttribute("Cleaned_Dirt", 0)
	return Totaldirt
end

local function Initializestains(
	Object: RestorationObject,
	Layouts: { Stainlayout.Layout },
	Version: number,
	Getcaster: () -> (any, boolean)
): (number, number)
	local Totals = { Ink = 0, Scratch = 0 }
	local Entries = {}
	for Index, Layout in ipairs(Layouts) do
		local Texture = Layout.Texture
		local Success, Mask = pcall(Buildmask, Texture.Image, Roundedtexture.GetShape(Texture))
		if not Success then
			warn("RestorationService: could not read " .. Texture.Image .. ": " .. tostring(Mask))
		end
		assert(not Success or Mask.Premarked < Coveragecellcount, "RestorationService: " .. Texture:GetFullName() .. " is fully transparent")
		Entries[Index] = Buildstainentry(Layout, Stainframes[Layout.Frame.Name], if Success then Mask.Alpha else Solidalpha)
	end
	local Blocked: string? = nil
	for Index, Layout in ipairs(Layouts) do
		local Entry = Entries[Index]
		local Kind = Entry.Kind :: string
		local Decal = Createstaindecal(Layout, Kind)
		if not Premarkunreachable(Entry, Object, Getcaster, Decal, Stainknowncells(Object.Name, Version, Layout.Surface)) and not Blocked then
			Blocked = string.format(
				"RestorationService: no pixel of %s can be cleaned on the %s face of %s, move it onto a visible part of that face",
				Layout.Texture:GetFullName(),
				Layout.Facename,
				Layout.Part:GetFullName()
			)
		end
		Coverage[Object][Decal] = Entry
		Layout.Texture:SetAttribute("Remaining", 1)
		Layout.Texture:SetAttribute(Stainkinds[Kind].Liquid, false)
		Layout.Frame:SetAttribute("Cleaned", false)
		Totals[Kind] += 1
	end
	assert(not Blocked, Blocked)
	Object:SetAttribute("Total_Ink", Totals.Ink)
	Object:SetAttribute("Cleaned_Ink", 0)
	Object:SetAttribute("Total_Scratch", Totals.Scratch)
	Object:SetAttribute("Cleaned_Scratch", 0)
	return Totals.Ink, Totals.Scratch
end

local function Validpoints(Points: any): boolean
	if type(Points) ~= "table" or #Points == 0 or #Points > Maxcleanpoints then return false end
	for _, Point in ipairs(Points) do
		if typeof(Point) ~= "Vector2" or Point.X ~= Point.X or Point.Y ~= Point.Y then return false end
	end
	return true
end

local function Openmask(Entry: CoverageEntry, Row: number): number
	local Mask = 0
	for Column = 0, Coveragegridwidth - 1 do
		if Entry.Cells[Row * Coveragegridwidth + Column + 1] < Entry.Passes then
			Mask += bit32.lshift(1, Column)
		end
	end
	return Mask
end

local function Stampcells(Entry: CoverageEntry, Points: { Vector2 }, Radius: Vector2): number
	local Newhits = 0
	local Openrows = {}
	local Lastx, Lasty = -1, -1
	for _, Point in ipairs(Points) do
		local X = math.clamp(Point.X, 0, 1)
		local Y = math.clamp(Point.Y, 0, 1)
		if X ~= Lastx or Y ~= Lasty then
			Lastx, Lasty = X, Y
			local Mincolumn = math.max(math.floor((X - Radius.X) * Coveragegridwidth), 0)
			local Maxcolumn = math.min(math.floor((X + Radius.X) * Coveragegridwidth), Coveragegridwidth - 1)
			local Minrow = math.max(math.floor((Y - Radius.Y) * Coveragegridwidth), 0)
			local Maxrow = math.min(math.floor((Y + Radius.Y) * Coveragegridwidth), Coveragegridwidth - 1)
			local Columns = bit32.lshift(2 ^ (Maxcolumn - Mincolumn + 1) - 1, Mincolumn)
			for Row = Minrow, Maxrow do
				local Open = Openrows[Row + 1] or Openmask(Entry, Row)
				local Candidates = bit32.band(Open, Columns)
				local Centery = (Row + 0.5) / Coveragegridwidth
				while Candidates ~= 0 do
					local Column = bit32.countrz(Candidates)
					local Bit = bit32.lshift(1, Column)
					Candidates -= Bit
					local Centerx = (Column + 0.5) / Coveragegridwidth
					if ((X - Centerx) / Radius.X) ^ 2 + ((Y - Centery) / Radius.Y) ^ 2 <= 1 then
						Open -= Bit
						Entry.Cells[Row * Coveragegridwidth + Column + 1] += 1
						Newhits += 1
					end
				end
				Openrows[Row + 1] = Open
			end
		end
	end
	Entry.Hits += Newhits
	return Newhits
end

local function Stampstain(Entry: CoverageEntry, Points: { Vector2 }, Radius: Vector2): number
	local Newhits = 0
	local Halfcell = 0.5 / Coveragegridwidth
	for _, Point in ipairs(Points) do
		local X = math.clamp(Point.X, 0, 1)
		local Y = math.clamp(Point.Y, 0, 1)
		local Mincolumn = math.max(math.floor((X - Radius.X) * Coveragegridwidth), 0)
		local Maxcolumn = math.min(math.floor((X + Radius.X) * Coveragegridwidth), Coveragegridwidth - 1)
		local Minrow = math.max(math.floor((Y - Radius.Y) * Coveragegridwidth), 0)
		local Maxrow = math.min(math.floor((Y + Radius.Y) * Coveragegridwidth), Coveragegridwidth - 1)
		for Row = Minrow, Maxrow do
			local Distancey = math.max(math.abs(Y - (Row + 0.5) / Coveragegridwidth) - Halfcell, 0) / Radius.Y
			for Column = Mincolumn, Maxcolumn do
				local Index = Row * Coveragegridwidth + Column + 1
				local Distancex = math.max(math.abs(X - (Column + 0.5) / Coveragegridwidth) - Halfcell, 0) / Radius.X
				if Entry.Cells[Index] < Entry.Passes and Distancex * Distancex + Distancey * Distancey <= 1 + Stampslack then
					Entry.Cells[Index] += 1
					Newhits += 1
				end
			end
		end
	end
	Entry.Hits += Newhits
	return Newhits
end

local function Iscovered(Entry: CoverageEntry): boolean
	return Entry.Hits >= Coveragecellcount * Entry.Passes
end

local function Isfaceclean(Target: Decal): boolean
	for _, Sibling in ipairs((Target.Parent :: Instance):GetChildren()) do
		if Sibling ~= Target and Sibling.Name == Target.Name and Sibling:GetAttribute("Cleaned") == false then
			return false
		end
	end
	return true
end

local function Fillentry(Entry: CoverageEntry): number
	local Credited = Coveragecellcount * Entry.Passes - Entry.Hits
	for Index = 1, Coveragecellcount do
		Entry.Cells[Index] = Entry.Passes
	end
	Entry.Hits = Coveragecellcount * Entry.Passes
	return Credited
end

local function Markdirtcleaned(Player: Player, Target: Decal, Toolname: string)
	Target:SetAttribute("Cleaned", true)
	if Isfaceclean(Target) then
		Core:GetService("DailyTaskService"):Record(Player, "Clean", { Tool = Toolname })
	end
end

local function Snapentry(Entry: CoverageEntry, Ratio: number): number
	local Remaining = Coveragecellcount * Entry.Passes - Entry.Hits
	local Snap = math.max((Coveragecellcount * Entry.Passes - Entry.Free) * (1 - Ratio), Finishassist.SnapCells * Entry.Passes)
	if not Iscovered(Entry) and Remaining <= Snap then
		return Fillentry(Entry)
	end
	return 0
end

local function Settledirt(Player: Player, Target: Decal, Entry: CoverageEntry, Toolname: string): number
	local Credited = Snapentry(Entry, Finishassist.SnapRatio)
	if Iscovered(Entry) and Target:GetAttribute("Cleaned") ~= true then
		Markdirtcleaned(Player, Target, Toolname)
	end
	return Credited
end

local function Isfinished(Object: RestorationObject): boolean
	for Target in pairs(Coverage[Object]) do
		if Target:GetAttribute("Cleaned") ~= true then
			return false
		end
	end
	return (tonumber(Object:GetAttribute("Cleaned_Sticker")) or 0) >= (tonumber(Object:GetAttribute("Total_Sticker")) or 0)
end

local function Finishobject(Player: Player, Object: RestorationObject)
	local Spot = Peeling[Player]
	if Spot and Spot.Parent then
		Spot:SetAttribute("PeelingBy", nil)
	end
	Peeling[Player] = nil
	for Target, Entry in pairs(Coverage[Object]) do
		Fillentry(Entry)
		if Entry.Kind then
			Completestain(Target, Entry)
		elseif Target:GetAttribute("Cleaned") ~= true then
			Markdirtcleaned(Player, Target :: Decal, Cleanalltool)
		end
	end
	for _, Child in ipairs(Object:WaitForChild("RestorationSpots"):GetChildren()) do
		if Child:GetAttribute("SpotKind") then
			(Child :: BasePart).CanQuery = false
			Child:Destroy()
		end
	end
	for _, Kind in ipairs(Progresskinds) do
		Object:SetAttribute("Cleaned_" .. Kind, tonumber(Object:GetAttribute("Total_" .. Kind)) or 0)
	end
	Object:SetAttribute("CleanedSpots", tonumber(Object:GetAttribute("TotalSpots")) or 0)
	Revealmutation(Object)
end

local function Setcleanedspots(Player: Player, Object: RestorationObject, Value: number)
	if Value >= (tonumber(Object:GetAttribute("TotalSpots")) or 0) or Isfinished(Object) then
		Finishobject(Player, Object)
		return
	end
	Object:SetAttribute("CleanedSpots", Value)
	Revealmutation(Object)
end

local function Getdirtratio(Object: RestorationObject): number
	local Totaldirt = tonumber(Object:GetAttribute("Total_Dirt")) or 0
	if Totaldirt <= 0 then
		return 0
	end
	return math.clamp((tonumber(Object:GetAttribute("Cleaned_Dirt")) or 0) / Totaldirt, 0, 1)
end

local function Getdirtspots(Object: RestorationObject): number
	return (tonumber(Object:GetAttribute("Total_Dirt")) or 0) * (tonumber(Object:GetAttribute("DirtWeight")) or 1)
end

local function Assistfloor(Object: RestorationObject, Stalled: boolean): number
	local Ratio = Getdirtratio(Object)
	local Active = Ratio >= Finishassist.Start or Stalled and Ratio >= Finishassist.StallStart
	if not Active or Ratio >= 1 then
		return 0
	end
	if Ratio < Finishassist.Start then
		return Finishassist.StallFloor * Getdirtspots(Object)
	end
	local Advance = (math.max(Ratio - Finishassist.Start, 0) / (1 - Finishassist.Start)) ^ Finishassist.Curve
	return (Finishassist.MinGain + (Finishassist.MaxGain - Finishassist.MinGain) * Advance) * Getdirtspots(Object)
end

local function Recordstall(Player: Player, Ratio: number, Gain: number, Stallspots: number): boolean
	local Count = Stallevents[Player] or 0
	if Ratio >= Finishassist.StallStart and Count < Finishassist.StallEvents then
		Count = if Gain < Finishassist.StallGain * Stallspots then Count + 1 else 0
		Stallevents[Player] = Count
	end
	return Count >= Finishassist.StallEvents
end

local function Assistentry(Entry: CoverageEntry, Points: { Vector2 }, Wanted: number): (number, { number })
	local Pointx = table.create(#Points)
	local Pointy = table.create(#Points)
	for Position, Point in ipairs(Points) do
		Pointx[Position] = Point.X
		Pointy[Position] = Point.Y
	end
	local Order = {}
	local Distances = {}
	for Index = 1, Coveragecellcount do
		if Entry.Cells[Index] < Entry.Passes then
			local Centerx = ((Index - 1) % Coveragegridwidth + 0.5) / Coveragegridwidth
			local Centery = ((Index - 1) // Coveragegridwidth + 0.5) / Coveragegridwidth
			local Distance = math.huge
			for Position = 1, #Pointx do
				local Offsetx = Pointx[Position] - Centerx
				local Offsety = Pointy[Position] - Centery
				Distance = math.min(Distance, Offsetx * Offsetx + Offsety * Offsety)
			end
			table.insert(Order, Index)
			Distances[Index] = Distance
		end
	end
	table.sort(Order, function(Left, Right)
		if Distances[Left] ~= Distances[Right] then
			return Distances[Left] < Distances[Right]
		end
		return Left < Right
	end)
	local Applied = 0
	local Cleared = {}
	for _, Index in ipairs(Order) do
		if Applied >= Wanted then
			break
		end
		local Added = math.min(Entry.Passes - Entry.Cells[Index], Wanted - Applied)
		Entry.Cells[Index] += Added
		Applied += Added
		if Entry.Cells[Index] == Entry.Passes then
			table.insert(Cleared, Index - 1)
		end
	end
	Entry.Hits += Applied
	return Applied, Cleared
end

local function Remainingunits(Entry: CoverageEntry): number
	return (Coveragecellcount * Entry.Passes - Entry.Hits) * Entry.Units / (Coveragecellcount * Entry.Passes - Entry.Free)
end

local function Remainingdecals(Object: RestorationObject)
	local List = {}
	for Target, Entry in pairs(Coverage[Object]) do
		if not Entry.Kind and not Iscovered(Entry) then
			table.insert(List, { Target = Target, Entry = Entry, Points = {} })
		end
	end
	table.sort(List, function(Left, Right)
		return Remainingunits(Left.Entry) < Remainingunits(Right.Entry)
	end)
	return List
end

local function Payassist(Player: Player, Targets, Shortfall: number, Dirtweight: number, Toolname: string): (number, number)
	local Removed = 0
	for _, Item in ipairs(Targets) do
		if Shortfall <= 0 then
			break
		end
		local Entry = Item.Entry
		if not Iscovered(Entry) then
			local Opaquepasses = Coveragecellcount * Entry.Passes - Entry.Free
			local Unit = Entry.Units * Dirtweight / Opaquepasses
			local Applied, Cleared = Assistentry(Entry, Item.Points, math.ceil(Shortfall / Unit))
			local Credited = Applied + Settledirt(Player, Item.Target, Entry, Toolname)
			Removed += Credited * Entry.Units / Opaquepasses
			Shortfall -= Credited * Unit
			if #Cleared > 0 and not Iscovered(Entry) then
				local Cells = buffer.create(#Cleared * 2)
				for Position, Index in ipairs(Cleared) do
					buffer.writeu16(Cells, (Position - 1) * 2, Index)
				end
				Remotemanager:FireClient(Restorationservice.Name, "LeftoversCleared", Player, Item.Target, Cells)
			end
		end
	end
	return Removed, Shortfall
end

local function Assistdirt(Player: Player, Object: RestorationObject, Touched, Shortfall: number, Dirtweight: number, Toolname: string): number
	local Removed, Remaining = Payassist(Player, Touched, Shortfall, Dirtweight, Toolname)
	if Remaining > 0 then
		Removed += Payassist(Player, Remainingdecals(Object), Remaining, Dirtweight, Toolname)
	end
	return Removed
end

local function Setpendingcleanall(Player: Player, Count: number)
	Pendingcleanall[Player] = Count
	Player:SetAttribute("PendingCleanAll", Count)
end

local function Basependingcleanall(Player: Player)
	Core:GetService("DataService"):WaitForLoad(Player)
	if Player.Parent and Pendingcleanall[Player] == nil then
		Setpendingcleanall(Player, 0)
	end
end

local function Cleanallobject(Player: Player): RestorationObject?
	local Object = Sessions[Player]
	if not Object or Core:GetService("TutorialService"):IsRunning(Player) or Getcompletionratio(Object) >= 1 then
		return nil
	end
	return Object
end

local function Allowrequest(Allowances: { [any]: number }, Key: any, Burst: number): boolean
	local Now = os.clock()
	local Allowed = Allowances[Key] or Now
	if Now < Allowed - Dirtcleaninterval * (Burst - 1) then
		return false
	end
	Allowances[Key] = math.max(Now, Allowed) + Dirtcleaninterval
	return true
end

local function Cleanstain(Player: Player, Kind: string, Target: any, Points: any)
	local Sessionobject = Sessions[Player]
	if not Sessionobject then
		return
	end
	local Entry = Coverage[Sessionobject][Target]
	if not Entry or Entry.Kind ~= Kind or not Validpoints(Points) then
		return
	end
	local Source = Entry.Source :: ImageLabel
	if Source:GetAttribute(Stainkinds[Kind].Liquid) ~= true or Iscovered(Entry) then
		return
	end
	local Allowances = Stainallowance[Player]
	if not Allowances then
		Allowances = {}
		Stainallowance[Player] = Allowances
	end
	if not Allowrequest(Allowances, Target, Stainburst) then
		return
	end
	local Radius = Facemapping.GetBrushRadius((Target.Parent :: BasePart).Size, Target.Face.Name, Stainbrushradius, Sessionobject:GetAttribute("BrushRadius"))
	local Opaquecells = Coveragecellcount * Entry.Passes - Entry.Free
	local Newlycovered = Stampstain(Entry, Points, Radius) + Snapentry(Entry, Finishassist.StainSnapRatio)
	if Newlycovered <= 0 then
		return
	end
	Source:SetAttribute("Remaining", (Coveragecellcount * Entry.Passes - Entry.Hits) / Opaquecells)
	if Iscovered(Entry) then
		Completestain(Target, Entry)
	end
	local Total = tonumber(Sessionobject:GetAttribute("Total_" .. Kind)) or 0
	local Previous = tonumber(Sessionobject:GetAttribute("Cleaned_" .. Kind)) or 0
	local Cleaned = math.min(Previous + Newlycovered * Entry.Units / Opaquecells, Total)
	if Total - Cleaned < 0.000001 then
		Cleaned = Total
	end
	Sessionobject:SetAttribute("Cleaned_" .. Kind, Cleaned)
	local Totalspots = tonumber(Sessionobject:GetAttribute("TotalSpots")) or 0
	local Cleanedspots = math.min((tonumber(Sessionobject:GetAttribute("CleanedSpots")) or 0) + Cleaned - Previous, Totalspots)
	if Totalspots - Cleanedspots < 0.000001 then
		Cleanedspots = Totalspots
	end
	Setcleanedspots(Player, Sessionobject, Cleanedspots)
end

local function Applyliquid(Player: Player, Kind: string, Target: any)
	local Sessionobject = Sessions[Player]
	if not Sessionobject then
		return
	end
	for _, Entry in pairs(Coverage[Sessionobject]) do
		if Entry.Source == Target and Entry.Kind == Kind then
			if not Iscovered(Entry) then
				Target:SetAttribute(Stainkinds[Kind].Liquid, true)
			end
			return
		end
	end
end

local function Createspots(Object: RestorationObject, Singleface: boolean, Seed: number, Version: number)
	Coverage[Object] = {}
	Warmmasks(Object)
	local Old = Object:FindFirstChild("RestorationSpots")
	if Old then
		Old:Destroy()
	end

	local Folder = Instance.new("Folder")
	Folder.Name = "RestorationSpots"
	Folder.Parent = Object

	local Speed = Cleaningconfig.CleaningSpeed
	local Sticker = Findsticker(Object)
	local Generating = Version >= Scratchversion and not Singleface and Randomscratch.Count > 0
	if Generating and Object.Name == Config.Offer.TutorialObject then
		Removeauthoredscratches(Object)
	end
	local Stains = Collectstains(Object, Sticker)
	local Getcaster, Releasecaster = Lazycaster(Object, Version)
	local Totaldirt, Totalink, Totalscratches = 0, 0, 0
	local Success, Failure = pcall(function()
		if Generating then
			Generatescratches(Object, Sticker, Stains, Seed, Version, Getcaster)
			Stains = Collectstains(Object, Sticker)
		end
		local Spotseconds = if Sticker then Speed.SpotSeconds.Sticker else 0
		for _, Layout in ipairs(Stains) do
			Spotseconds += Speed.SpotSeconds[Stainframes[Layout.Frame.Name]]
		end
		Totaldirt = Initializedirt(Object, Singleface, Seed, Version, Getcaster, Spotseconds)
		Totalink, Totalscratches = Initializestains(Object, Stains, Version, Getcaster)
	end)
	if Releasecaster() then
		Prioritizewarmup(Object.Name)
	end
	if not Success then
		error(Failure, 0)
	end
	local Totalsticker = 0
	if Sticker then
		Sticker:SetAttribute("SpotKind", "Sticker")
		Sticker.CanQuery = true
		Sticker.CanTouch = false
		Sticker.Massless = true
		Sticker.Parent = Folder
		Totalsticker = 1
	end
	Object:SetAttribute("Total_Sticker", Totalsticker)
	Object:SetAttribute("Cleaned_Sticker", 0)
	local Otherspots = Totalscratches + Totalink + Totalsticker
	assert(Totaldirt + Otherspots > 0, "RestorationService: " .. Object:GetFullName() .. " has nothing to clean")
	local Dirtshare = Speed.DirtProgressShare
	local Dirtweight = if Totaldirt > 0 and Otherspots > 0 then math.min(1, Otherspots * Dirtshare / ((1 - Dirtshare) * Totaldirt)) else 1
	Object:SetAttribute("DirtWeight", Dirtweight)
	Object:SetAttribute("TotalSpots", Totaldirt * Dirtweight + Otherspots)
	Object:SetAttribute("CleanedSpots", 0)
end

function Restorationservice:GenerateObjectMaximums(Objectname: string): ObjectMaximums
	return Generateobjectmaximums(Objectname)
end

function Restorationservice:PrepareObject(
	Objectname: string,
	Owner: Player,
	Maximums: ObjectMaximums?,
	Percent: number?,
	Progress: { [string]: any }?
): RestorationObject
	Releaseactiveobject(Owner)
	local Object = Spawnconfiguredobject(Objectname, Core:GetService("ShopService"):GetShop(Owner), Maximums)
	if Object:IsA("BasePart") then
		Object.Anchored = true
	else
		for _, Descendant in ipairs(Object:GetDescendants()) do
			if Descendant:IsA("BasePart") then
				Descendant.Anchored = true
			end
		end
	end
	Object:SetAttribute("RestorationObject", true)
	Object:SetAttribute("AwardedUserId", Owner.UserId)
	local Istutorial = Core:GetService("TutorialService"):IsActive(Owner)
	local Seed = if Progress and Progress.DirtSeed then Progress.DirtSeed else Randomgenerator:NextInteger(1, 2147483646)
	local Version = if Progress and Progress.DirtSeed then Progress.DirtVersion or 1 else Dirtversion
	local Success, Failure = pcall(function()
		Createspots(Object, Istutorial, Seed, Version)
		Precleanobject(Object, (tonumber(Percent) or 0) / 100, Progress)
	end)
	if not Success then
		Destroyobject(Object)
		error(Failure, 0)
	end
	Activeobjects[Owner] = Object
	return Object
end

function Restorationservice:GrantObject(Player: Player, Objectname: string): boolean
	if Config.Object[Objectname] == nil then return false end
	Core:GetService("InventoryService"):AddPurchasedItem(Player, Objectname, Generateobjectmaximums(Objectname), 0)
	return true
end

function Restorationservice:HasActiveSession(Player: Player): boolean
	return Sessions[Player] ~= nil
end

function Restorationservice:HasActiveObject(Player: Player): boolean
	local Object = Activeobjects[Player]
	return Object ~= nil and Object.Parent ~= nil
end

function Restorationservice:IsRestoring(Player: Player): boolean
	return Sessionitem[Player] ~= nil or Sessions[Player] ~= nil or Activeobjects[Player] ~= nil
end

function Restorationservice:CleanAll(Player: Player): boolean
	local Object = Cleanallobject(Player)
	if Object then
		Finishobject(Player, Object)
	else
		Setpendingcleanall(Player, (Pendingcleanall[Player] or 0) + 1)
	end
	return true
end

function Restorationservice:Warmobject(Objectkey: string)
	Prioritizewarmup(Objectkey)
end

function Restorationservice:Init()
	Objecttemplates = Replicatedstorage:WaitForChild("Asset"):WaitForChild("Object") :: Folder
	for _, Template in ipairs(Objecttemplates:GetChildren()) do
		local Slot = 0
		local Stainslot = 0
		for _, Descendant in ipairs(Template:GetDescendants()) do
			if Descendant:IsA("Decal") and Dirtdecalnames[Descendant.Name] then
				Slot += 1
				Descendant:SetAttribute("DirtSlot", Slot)
			elseif Descendant:IsA("SurfaceGui") and Dirtsurfacenames[Descendant.Name] then
				Stainslot += 1
				Descendant:SetAttribute("StainSlot", Stainslot)
			end
		end
	end
	Warmworld = Instance.new("WorldModel")
	Warmworld.Name = "RestorationWarmup"
	Warmworld.Parent = Serverstorage
	Core:GetService("DataService"):Register("Restoration", {
		Load = function(Player, Saved)
			local Count = tonumber(Saved.PendingCleanAll) or 0
			Setpendingcleanall(Player, if Count == Count and math.abs(Count) ~= math.huge then math.max(math.floor(Count), 0) else 0)
		end,
		Save = function(Player)
			return { PendingCleanAll = Pendingcleanall[Player] or 0 }
		end,
		Clear = function(Player)
			local Spot = Peeling[Player]
			if Spot and Spot.Parent then
				Spot:SetAttribute("PeelingBy", nil)
			end
			Peeling[Player] = nil
			Sessionitem[Player] = nil
			Sessions[Player] = nil
			Dirtallowance[Player] = nil
			Stainallowance[Player] = nil
			Stallevents[Player] = nil
			Pendingcleanall[Player] = nil
			Releaseactiveobject(Player)
		end,
	})
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(Basependingcleanall, Player)
	end
	Players.PlayerAdded:Connect(function(Player)
		task.spawn(Basependingcleanall, Player)
	end)
	for _, Shop in ipairs(Core:GetService("ShopService"):GetShops()) do
		local Generateditems = Instance.new("Folder")
		Generateditems.Name = "GeneratedItems"
		Generateditems.Parent = Shop
	end
	Remotemanager:OnServerInvoke(self.Name, "BeginSession", function(Player)
		local Object = Activeobjects[Player]
		if not Object or not Object.Parent then
			return nil
		end
		if Object:GetAttribute("CompletingRestoration") then return nil end
		Sessions[Player] = Object
		return Object
	end)

	Remotemanager:OnServerInvoke(self.Name, "BeginItem", function(Player, ItemId)
		if Activeobjects[Player] or Sessions[Player] or Sessionitem[Player] then
			return nil
		end
		local Inventoryservice = Core:GetService("InventoryService")
		local Item = Inventoryservice:TakeRestoredItem(Player, tonumber(ItemId) or 0, true)
		if not Item then
			return nil
		end
		Sessionitem[Player] = Item
		local Success, Object = pcall(self.PrepareObject, self, Item.ObjectKey, Player, {
			MaxValue = Item.MaxValue,
			MaxReputation = Item.MaxReputation,
			Mutation = Item.Mutation,
		}, Item.RestorationPercent, Item.Progress)
		if not Success then
			Returnsessionitem(Player, nil)
			error(Object, 0)
		end
		if not Player.Parent then
			Releaseactiveobject(Player)
			return nil
		end
		Object:SetAttribute("PurchasePrice", Item.PurchasePrice)
		Object:SetAttribute("StartPercent", Item.RestorationPercent)
		Sessions[Player] = Object
		Inventoryservice:PushItems(Player)
		return Object, true
	end)

	Remotemanager:OnServerInvoke(self.Name, "BeginPeel", function(Player, Spot)
		local _, Valid = Validsessionspot(Player, Spot)
		if not Valid or Spot:GetAttribute("SpotKind") ~= "Sticker" then
			return false
		end
		local Owner = Spot:GetAttribute("PeelingBy")
		if Owner and Owner ~= Player.UserId then
			return false
		end
		Spot:SetAttribute("PeelingBy", Player.UserId)
		Peeling[Player] = Spot
		return true
	end)

	Remotemanager:OnServerInvoke(self.Name, "CompleteRestoration", function(Player)
		local Sessionobject = Sessions[Player]
		if not Sessionobject or not Sessionobject.Parent then
			return nil
		end
		if Sessionobject:GetAttribute("CompletingRestoration") then return nil end
		Sessionobject:SetAttribute("CompletingRestoration", true)
		Sessions[Player] = nil

		local Inventoryservice = Core:GetService("InventoryService")
		local Completionratio = Getcompletionratio(Sessionobject)
		local Maxvalue = tonumber(Sessionobject:GetAttribute("MaxValue")) or tonumber(Sessionobject:GetAttribute("MaxPrice")) or 0
		local Maxreputation = tonumber(Sessionobject:GetAttribute("MaxReputation")) or 0
		local Salevalue = Roundtwodecimals(Maxvalue * Completionratio)
		local Reputation = Roundtwodecimals(Maxreputation * Completionratio)
		local Purchaseprice = tonumber(Sessionobject:GetAttribute("PurchasePrice")) or 0
		local Startpercent = tonumber(Sessionobject:GetAttribute("StartPercent")) or 0
		local Objectkey = tostring(Sessionobject:GetAttribute("ObjectKey") or Sessionobject.Name)
		local Itemdata = {
			Id = 0,
			ObjectKey = Objectkey,
			Name = tostring(Sessionobject:GetAttribute("DisplayName") or Sessionobject.Name),
			ImageId = tostring(Sessionobject:GetAttribute("ImageId") or ""),
			Rarity = tostring(Sessionobject:GetAttribute("Rarity") or "Common"),
			Mutation = Mutationbyobject[Sessionobject] or "Normal",
			RestorationPercent = Restorationpercent(Completionratio),
			PurchasePrice = Purchaseprice,
			CurrentValue = Salevalue,
			MaxValue = Maxvalue,
			MaxReputation = Maxreputation,
			NetProfit = Roundtwodecimals(Salevalue - Purchaseprice),
			Reputation = Reputation,
		}

		Sessionobject:SetAttribute("SaleValue", Salevalue)

		local Spot = Peeling[Player]
		if Spot and Spot.Parent then
			Spot:SetAttribute("PeelingBy", nil)
		end
		Peeling[Player] = nil
		Dirtallowance[Player] = nil
		Stainallowance[Player] = nil
		Stallevents[Player] = nil

		local Sessioniteminstance = Sessionitem[Player]
		Sessionitem[Player] = nil
		if Sessioniteminstance then
			Applyratiotoitem(Sessioniteminstance, Completionratio, Sessionobject)
		end

		if Activeobjects[Player] == Sessionobject then
			Activeobjects[Player] = nil
		end
		Destroyobject(Sessionobject)

		local Restoreditem
		if Sessioniteminstance then
			Restoreditem = Inventoryservice:ReturnRestoredItem(Player, Sessioniteminstance)
		else
			Restoreditem = Inventoryservice:AddRestoredItem(Player, Itemdata)
		end
		Core:GetService("TutorialService"):MarkObjectDone(Player)
		if Itemdata.RestorationPercent >= 100 and Startpercent < 100 then
			Core:GetService("DailyTaskService"):Record(Player, "Restore", {
				ObjectKey = Objectkey,
				Rarity = Itemdata.Rarity,
				Mutation = Itemdata.Mutation,
				Value = Itemdata.MaxValue,
				Start = Startpercent,
			})
		end
		if Completionratio >= 0.5 and Player.Parent then
			Inventoryservice:UnlockIndexEntry(Player, Objectkey, Itemdata.Mutation)
		end
		Core:GetService("CustomerService"):PresentOffer(Player)

		return Restoreditem
	end)

	Remotemanager:OnServerEvent(self.Name, "CompletePeel", function(Player, Spot)
		local Object, Valid = Validsessionspot(Player, Spot)
		if not Object or not Valid or Peeling[Player] ~= Spot or Spot:GetAttribute("PeelingBy") ~= Player.UserId then
			return
		end
		Peeling[Player] = nil
		Spot.CanQuery = false
		local Previous = tonumber(Object:GetAttribute("Cleaned_Sticker")) or 0
		local Cleanedsticker = math.max(math.min(Previous + 1, tonumber(Object:GetAttribute("Total_Sticker")) or 0), Previous)
		local Totalspots = tonumber(Object:GetAttribute("TotalSpots")) or 0
		local Cleanedspots = math.min((tonumber(Object:GetAttribute("CleanedSpots")) or 0) + Cleanedsticker - Previous, Totalspots)
		if Totalspots - Cleanedspots < 0.000001 then Cleanedspots = Totalspots end
		Object:SetAttribute("Cleaned_Sticker", Cleanedsticker)
		Setcleanedspots(Player, Object, Cleanedspots)
		Spot:Destroy()
	end)

	Remotemanager:OnServerEvent(self.Name, "CancelPeel", function(Player, Spot)
		if Peeling[Player] ~= Spot then
			return
		end
		Peeling[Player] = nil
		if Spot.Parent and Spot:GetAttribute("PeelingBy") == Player.UserId then
			Spot:SetAttribute("PeelingBy", nil)
			Spot.CanQuery = true
		end
	end)

	Remotemanager:OnServerEvent(self.Name, "ApplyInkSolvent", function(Player, Target)
		Applyliquid(Player, "Ink", Target)
	end)

	Remotemanager:OnServerEvent(self.Name, "ApplyScratchPolish", function(Player, Target)
		Applyliquid(Player, "Scratch", Target)
	end)

	Remotemanager:OnServerEvent(self.Name, "CleanInk", function(Player, Target, Points)
		Cleanstain(Player, "Ink", Target, Points)
	end)

	Remotemanager:OnServerEvent(self.Name, "CleanScratch", function(Player, Target, Points)
		Cleanstain(Player, "Scratch", Target, Points)
	end)

	Remotemanager:OnServerInvoke(self.Name, "GetLeftovers", function(Player, Targets)
		local Sessionobject = Sessions[Player]
		if not Sessionobject or type(Targets) ~= "table" or #Targets > Maxdirtstrokes then return {} end
		local Masks = {}
		for Index, Target in ipairs(Targets) do
			local Entry = Coverage[Sessionobject][Target]
			local Mask = buffer.create(Coveragecellcount)
			if Entry then
				for Cell = 1, Coveragecellcount do
					buffer.writeu8(Mask, Cell - 1, Entry.Passes - Entry.Cells[Cell])
				end
			end
			Masks[Index] = Mask
		end
		return Masks
	end)

	Remotemanager:OnServerInvoke(self.Name, "UseCleanAll", function(Player)
		local Object = Cleanallobject(Player)
		if not Object or (Pendingcleanall[Player] or 0) <= 0 then
			return false
		end
		Setpendingcleanall(Player, Pendingcleanall[Player] - 1)
		Finishobject(Player, Object)
		return true
	end)

	Remotemanager:OnServerEvent(self.Name, "CleanDirt", function(Player, Toolname, Strokes)
		local Sessionobject = Sessions[Player]
		if not Sessionobject or not Dirttools[Toolname] then return end
		if type(Strokes) ~= "table" or #Strokes > Maxdirtstrokes then return end
		local Ratio = Getdirtratio(Sessionobject)
		if #Strokes == 0 and Ratio < Pingstart then return end
		if not Allowrequest(Dirtallowance, Player, Dirtburst) then return end

		local Minimumradius = Sessionobject:GetAttribute("BrushRadius") * Brushradii[Toolname] / Brushradii.ToothBrush
		local Removeddirt = 0
		local Seen = {}
		local Touched = {}
		for _, Stroke in ipairs(Strokes) do
			local Target = if type(Stroke) == "table" then Stroke.Target else nil
			local Entry = if typeof(Target) == "Instance" then Coverage[Sessionobject][Target] else nil
			if
				Entry
				and not Seen[Target]
				and Target:IsA("Decal")
				and Dirtdecalnames[Target.Name]
				and Target:IsDescendantOf(Sessionobject)
				and Validpoints(Stroke.Points)
			then
				Seen[Target] = true
				local Opaquepasses = Coveragecellcount * Entry.Passes - Entry.Free
				local Radius = Facemapping.GetBrushRadius((Target.Parent :: BasePart).Size, Target.Face.Name, Brushradii[Toolname], Minimumradius)
				local Newlycovered = Stampcells(Entry, Stroke.Points, Radius)
				Newlycovered += Settledirt(Player, Target, Entry, Toolname)
				Removeddirt += Newlycovered * Entry.Units / Opaquepasses
				table.insert(Touched, { Target = Target, Entry = Entry, Points = Stroke.Points })
			end
		end
		local Dirtweight = tonumber(Sessionobject:GetAttribute("DirtWeight")) or 1
		local Totalspots = tonumber(Sessionobject:GetAttribute("TotalSpots")) or 0
		local Stallspots = Getdirtspots(Sessionobject) * math.min(Sessionobject:GetAttribute("DirtStep") / Dirtfadestep, 1)
		local Stalled = Recordstall(Player, Ratio, Removeddirt * Dirtweight, Stallspots)
		local Shortfall = Assistfloor(Sessionobject, Stalled) - Removeddirt * Dirtweight
		if Shortfall > 0 then
			Removeddirt += Assistdirt(Player, Sessionobject, Touched, Shortfall, Dirtweight, Toolname)
		end
		if Removeddirt <= 0 then return end
		local Totaldirt = tonumber(Sessionobject:GetAttribute("Total_Dirt")) or 0
		local Cleaneddirt = math.min((tonumber(Sessionobject:GetAttribute("Cleaned_Dirt")) or 0) + Removeddirt, Totaldirt)
		if Totaldirt - Cleaneddirt < 0.000001 then Cleaneddirt = Totaldirt end
		local Previouscleaneddirt = tonumber(Sessionobject:GetAttribute("Cleaned_Dirt")) or 0
		local Appliedprogress = Cleaneddirt - Previouscleaneddirt
		Sessionobject:SetAttribute("Cleaned_Dirt", Cleaneddirt)
		local Cleanedspots = math.min((tonumber(Sessionobject:GetAttribute("CleanedSpots")) or 0) + Appliedprogress * Dirtweight, Totalspots)
		if Totalspots - Cleanedspots < 0.000001 then Cleanedspots = Totalspots end
		Setcleanedspots(Player, Sessionobject, Cleanedspots)
	end)

	Remotemanager:OnServerEvent(self.Name, "SessionEnded", function(Player)
		local Sessionobject = Sessions[Player]
		Sessions[Player] = nil
		Dirtallowance[Player] = nil
		Stainallowance[Player] = nil
		Stallevents[Player] = nil
		if Sessionobject then Returnsessionitem(Player, Sessionobject) end
		if Sessionobject and Activeobjects[Player] == Sessionobject then Releaseactiveobject(Player) end
		Core:GetService("CustomerService"):PresentOffer(Player)
	end)
end

function Restorationservice:Start()
	local Templates = Objecttemplates:GetChildren()
	table.sort(Templates, function(Left, Right)
		return Left.Name < Right.Name
	end)
	for _, Template in ipairs(Templates) do
		if Config.Object[Template.Name] then
			table.insert(Warmqueue, Template.Name)
		end
	end
	task.spawn(function()
		Warmmasks(Objecttemplates:WaitForChild(Config.Offer.TutorialObject) :: RestorationObject)
	end)
	for _, Texture in ipairs(Scratchtextures) do
		task.spawn(Scratchmask, Texture.Image)
	end
	Runwarmup()
end

return Restorationservice
