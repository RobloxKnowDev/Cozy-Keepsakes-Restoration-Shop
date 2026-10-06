local Assetservice = game:GetService("AssetService")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Tweenservice = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

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
		CleanScratch = "Event",
		CompleteRestoration = "Function",
		CompletePeel = "Event",
		CancelPeel = "Event",
		CleanSpot = "Event",
		SessionEnded = "Event",
	},
}

local Dirtcleaninterval = 0.05
local Scratchcleaninterval = Dirtcleaninterval
local Inkcleaninterval = Scratchcleaninterval
local Coveragegridwidth = Cleaningconfig.CoverageGrid
local Coveragecellcount = Coveragegridwidth * Coveragegridwidth
local Brushradii = { CottonTip = 1 / 12, ToothBrush = 3 / 32 }
local Maxcleanpoints = 32
local Maxdirtstrokes = 8
local Dirtsnapratio = 0.995
local Dirtversion = 2
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
local Spothealth = { Sticker = 3 }
local Toolpower = { CottonTip = 1, HeatGun = 1, Polish = 1, Solvent = 1, ToothBrush = 1, Tweezers = 1 }
local Toolsforspot = { Sticker = "Tweezers" }
type CoverageEntry = { Cells: { number }, Hits: number, Free: number, Premarked: number, Passes: number }
local Coverage: { [RestorationObject]: { [Instance]: CoverageEntry } } = {}

type CoverageMask = { Alpha: { number }, Premarked: number }
local Visiblealpha = 32
local Dirtfadestep = math.ceil(255 / Cleaningconfig.DirtPasses)
local Maskcache: { [string]: CoverageMask } = {}
local Textureframenames = { Ink = true, ScratchesFrame = true }
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
		if Descendant:IsA("ImageLabel") and Descendant.Name == "Texture" and Textureframenames[Descendant.Parent.Name] then
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

local function Buildcoverageentry(Source: Instance, Image: string, Passes: number): CoverageEntry
	local Success, Mask = pcall(Buildmask, Image, Roundedtexture.GetShape(Source))
	if not Success then
		warn("RestorationService: could not read " .. Image .. ": " .. tostring(Mask))
		return { Cells = table.create(Coveragecellcount, 0), Hits = 0, Free = 0, Premarked = 0, Passes = Passes }
	end
	assert(Mask.Premarked < Coveragecellcount, "RestorationService: " .. Source:GetFullName() .. " is fully transparent")
	local Cells = table.create(Coveragecellcount, 0)
	local Free = 0
	for Index, Alpha in ipairs(Mask.Alpha) do
		local Needed = if Alpha > Visiblealpha then math.min(math.ceil((Alpha - Visiblealpha) / Dirtfadestep), Passes) else 0
		Cells[Index] = Passes - Needed
		Free += Passes - Needed
	end
	return { Cells = Cells, Hits = Free, Free = Free, Premarked = Mask.Premarked, Passes = Passes }
end

local function Premarkunreachable(Entry: CoverageEntry, Object: RestorationObject, Decal: Decal): boolean
	local Part = Decal.Parent :: BasePart
	local Facename = Decal.Face.Name
	local Worldnormal = Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Decal.Face))
	local Objectsize = if Object:IsA("Model") then Object:GetExtentsSize() else Object.Size
	local Distance = Objectsize.Magnitude + 1
	local Length = Distance + Part.Size.Magnitude
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Object }
	for Row = 0, Coveragegridwidth - 1 do
		for Column = 0, Coveragegridwidth - 1 do
			local Index = Row * Coveragegridwidth + Column + 1
			if Entry.Cells[Index] < Entry.Passes then
				local Localpoint = Facemapping.GetDecalLocalPoint(
					Part.Size,
					Facename,
					(Column + 0.5) / Coveragegridwidth,
					(Row + 0.5) / Coveragegridwidth
				)
				local Origin = Part.CFrame:PointToWorldSpace(Localpoint) + Worldnormal * Distance
				local Result = Workspace:Raycast(Origin, -Worldnormal * Length, Params)
				if
					not Result
					or Result.Instance ~= Part
					or not Facemapping.ShowsDecal(Decal, Result.Normal)
				then
					Entry.Free += Entry.Passes - Entry.Cells[Index]
					Entry.Hits += Entry.Passes - Entry.Cells[Index]
					Entry.Cells[Index] = Entry.Passes
					Entry.Premarked += 1
				end
			end
		end
	end
	return Entry.Premarked < Coveragecellcount
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
local Lastclean: { [Player]: number } = {}
local Lastscratchclean: { [Player]: number } = {}
local Lastinkclean: { [Player]: number } = {}
local Peeling: { [Player]: BasePart } = {}
local Activeobjects: { [Player]: RestorationObject } = {}
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

local Dirtpreclean = { Kind = "Dirt", Units = 16, Weighted = true }
local Precleankinds = {
	ScratchesFrame = { Kind = "Scratch", Units = 1, Weighted = false },
	Ink = { Kind = "Ink", Units = 1, Weighted = false },
}

local Progresskinds = { "Dirt", "Ink", "Scratch", "Sticker" }
local Precleansnapratio = 0.85

local function Captureprogress(Object: RestorationObject): { [string]: number }
	local Progress = {}
	for _, Kind in ipairs(Progresskinds) do
		Progress[Kind] = tonumber(Object:GetAttribute("Cleaned_" .. Kind)) or 0
	end
	Progress.DirtSeed = Object:GetAttribute("DirtSeed")
	Progress.DirtVersion = Object:GetAttribute("DirtVersion")
	return Progress
end

local function Precleanobject(Object: RestorationObject, Ratio: number, Progress: { [string]: number }?)
	if Ratio <= 0 then
		return
	end
	local Totalspots = tonumber(Object:GetAttribute("TotalSpots")) or 0
	local Target = Totalspots * math.clamp(Ratio, 0, 1)
	local Dirtweight = tonumber(Object:GetAttribute("DirtWeight")) or 1
	local Cleanedbykind = {}
	for _, Kind in ipairs(Progresskinds) do
		local Total = tonumber(Object:GetAttribute("Total_" .. Kind)) or 0
		local Stored = if Progress then tonumber(Progress[Kind]) or 0 else Total * math.clamp(Ratio, 0, 1)
		Cleanedbykind[Kind] = math.clamp(Stored, 0, Total)
	end

	local Hideable = table.clone(Cleanedbykind)
	local Hidden = {}
	for _, Kind in ipairs(Progresskinds) do
		Hidden[Kind] = 0
	end
	local Cleaned = 0
	for _, Descendant in ipairs(Object:GetDescendants()) do
		local Isdirt = Descendant:IsA("Decal") and Dirtdecalnames[Descendant.Name] == true
		local Entry = if Isdirt then Dirtpreclean else Precleankinds[Descendant.Name]
		if
			Entry
			and (Isdirt or Descendant:IsA("GuiObject") and Descendant.Visible)
			and Hideable[Entry.Kind] >= Entry.Units * Precleansnapratio
		then
			if Isdirt then
				Coverage[Object][Descendant] = nil
				Descendant:Destroy()
			else
				Descendant.Visible = false
				Descendant:SetAttribute("Cleaned", true)
			end
			Hideable[Entry.Kind] = math.max(Hideable[Entry.Kind] - Entry.Units, 0)
			Hidden[Entry.Kind] += Entry.Units
			Cleaned += Entry.Units * (if Entry.Weighted then Dirtweight else 1)
		end
	end
	for _, Kind in ipairs(Progresskinds) do
		Cleanedbykind[Kind] = math.max(Cleanedbykind[Kind], Hidden[Kind])
	end

	local Sticker = Object.RestorationSpots:FindFirstChild("Sticker")
	if Sticker and Cleanedbykind.Sticker >= 1 then
		Sticker:Destroy()
		Cleaned += 1
	end

	for _, Kind in ipairs(Progresskinds) do
		Object:SetAttribute("Cleaned_" .. Kind, Cleanedbykind[Kind])
	end
	local Restored = Cleanedbykind.Dirt * Dirtweight + Cleanedbykind.Ink + Cleanedbykind.Scratch + Cleanedbykind.Sticker
	Object:SetAttribute("CleanedSpots", if Progress then math.min(Restored, Totalspots) else math.max(Cleaned, Target))
	Revealmutation(Object, true)
end

local function Setcleanedspots(Object: RestorationObject, Value: number)
	Object:SetAttribute("CleanedSpots", Value)
	Revealmutation(Object)
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

local function Initializedirt(Object: RestorationObject, Singleface: boolean, Seed: number, Version: number): number
	local Generator = Random.new(Seed)
	local Styled = Version == Dirtversion and not Singleface
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
	for _, Decal in ipairs(Decals) do
		local Texture = if Styled and Kept < Keptcount then Pickdirttexture(Generator, nil) else nil
		if Texture then
			Decal.Texture = Texture.Image
			Decal.ZIndex = Texture.ZIndex
		end
		local Entry = if Kept < Keptcount then Buildcoverageentry(Decal, Decal.Texture, Cleaningconfig.DirtPasses) else nil
		if Entry and Premarkunreachable(Entry, Object, Decal) then
			Kept += 1
			Coverage[Object][Decal] = Entry
			Decal:SetAttribute("Cleaned", false)
			Totaldirt += 16
			if Texture and Layers < Cleaningconfig.MaxDirtLayers and Generator:NextNumber() < Cleaningconfig.DirtLayerChance then
				local Layertexture = Pickdirttexture(Generator, Texture.Pattern)
				local Layer = Decal:Clone()
				Layer.Texture = Layertexture.Image
				Layer.ZIndex = Layertexture.ZIndex
				Layer.Parent = Decal.Parent
				local Layerentry = Buildcoverageentry(Layer, Layer.Texture, Cleaningconfig.DirtPasses)
				if Premarkunreachable(Layerentry, Object, Layer) then
					Layers += 1
					Coverage[Object][Layer] = Layerentry
					Totaldirt += 16
				else
					Layer:Destroy()
				end
			end
		else
			Decal:Destroy()
		end
	end
	Object:SetAttribute("DirtSeed", Seed)
	Object:SetAttribute("DirtVersion", Version)
	Object:SetAttribute("Total_Dirt", Totaldirt)
	Object:SetAttribute("Cleaned_Dirt", 0)
	return Totaldirt
end

local function Initializescratches(Object: RestorationObject): number
	local Totalscratches = 0
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("GuiObject") and Descendant.Name == "ScratchesFrame" then
			local Surface = Descendant.Parent
			assert(Surface and Surface:IsA("SurfaceGui"), "RestorationService: " .. Descendant:GetFullName() .. " must be inside a SurfaceGui")
			assert(Dirtsurfacenames[Surface.Name], "RestorationService: " .. Surface:GetFullName() .. " must use a valid Ui name")
			local Part = Surface.Parent
			assert(Part and Part:IsA("BasePart"), "RestorationService: " .. Surface:GetFullName() .. " must be inside a BasePart")
			assert(Surface.Enabled, "RestorationService: " .. Surface:GetFullName() .. " must be enabled")
			assert(
				Surface.Face.Name == string.sub(Surface.Name, 3),
				"RestorationService: the face of " .. Surface:GetFullName() .. " does not match its name"
			)
			assert(Descendant.Visible, "RestorationService: " .. Descendant:GetFullName() .. " must be visible")
			local Texture = Descendant:WaitForChild("Texture")
			assert(Texture:IsA("ImageLabel"), "RestorationService: " .. Texture:GetFullName() .. " must be an ImageLabel")
			Texture:SetAttribute("Remaining", 1)
			Texture:SetAttribute("HasPolish", false)
			Descendant:SetAttribute("Cleaned", false)
			Coverage[Object][Descendant] = Buildcoverageentry(Texture, Texture.Image, 1)
			Totalscratches += 1
		end
	end
	Object:SetAttribute("Total_Scratch", Totalscratches)
	Object:SetAttribute("Cleaned_Scratch", 0)
	return Totalscratches
end

local function Initializeink(Object: RestorationObject): number
	local Totalink = 0
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("GuiObject") and Descendant.Name == "Ink" then
			local Surface = Descendant.Parent
			assert(Surface and Surface:IsA("SurfaceGui"), "RestorationService: " .. Descendant:GetFullName() .. " must be inside a SurfaceGui")
			assert(Dirtsurfacenames[Surface.Name], "RestorationService: " .. Surface:GetFullName() .. " must use a valid Ui name")
			local Part = Surface.Parent
			assert(Part and Part:IsA("BasePart"), "RestorationService: " .. Surface:GetFullName() .. " must be inside a BasePart")
			assert(Surface.Enabled, "RestorationService: " .. Surface:GetFullName() .. " must be enabled")
			assert(Surface.Face.Name == string.sub(Surface.Name, 3), "RestorationService: the face of " .. Surface:GetFullName() .. " does not match its name")
			assert(Descendant.Visible, "RestorationService: " .. Descendant:GetFullName() .. " must be visible")
			local Texture = Descendant:WaitForChild("Texture")
			assert(Texture:IsA("ImageLabel"), "RestorationService: " .. Texture:GetFullName() .. " must be an ImageLabel")
			Texture:SetAttribute("Remaining", 1)
			Texture:SetAttribute("HasSolvent", false)
			Descendant:SetAttribute("Cleaned", false)
			Coverage[Object][Descendant] = Buildcoverageentry(Texture, Texture.Image, 1)
			Totalink += 1
		end
	end
	Object:SetAttribute("Total_Ink", Totalink)
	Object:SetAttribute("Cleaned_Ink", 0)
	return Totalink
end

local function Validscratchimage(Object: RestorationObject, Target: any): boolean
	if typeof(Target) ~= "Instance" or not Target:IsA("ImageLabel") or not Target:IsDescendantOf(Object) then return false end
	local Scratchframe = Target.Parent
	if not Scratchframe or Scratchframe.Name ~= "ScratchesFrame" or not Scratchframe:IsA("GuiObject") or not Scratchframe.Visible then return false end
	local Surface = Scratchframe.Parent
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled or not Dirtsurfacenames[Surface.Name] then return false end
	if not Surface.Parent or not Surface.Parent:IsA("BasePart") then return false end
	if Surface.Face.Name ~= string.sub(Surface.Name, 3) then return false end
	return Target.Name == "Texture" and Target:GetAttribute("Remaining") ~= nil
end

local function Validinkimage(Object: RestorationObject, Target: any): boolean
	if typeof(Target) ~= "Instance" or not Target:IsA("ImageLabel") or not Target:IsDescendantOf(Object) then return false end
	local Inkframe = Target.Parent
	if not Inkframe or Inkframe.Name ~= "Ink" or not Inkframe:IsA("GuiObject") or not Inkframe.Visible then return false end
	local Surface = Inkframe.Parent
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled or not Dirtsurfacenames[Surface.Name] then return false end
	if not Surface.Parent or not Surface.Parent:IsA("BasePart") then return false end
	if Surface.Face.Name ~= string.sub(Surface.Name, 3) then return false end
	return Target.Name == "Texture" and Target:GetAttribute("Remaining") ~= nil
end

local function Validpoints(Points: any): boolean
	if type(Points) ~= "table" or #Points == 0 or #Points > Maxcleanpoints then return false end
	for _, Point in ipairs(Points) do
		if typeof(Point) ~= "Vector2" or Point.X ~= Point.X or Point.Y ~= Point.Y then return false end
	end
	return true
end

local function Stampcells(Entry: CoverageEntry, Points: { Vector2 }, Radius: number): number
	local Newhits = 0
	local Touched = {}
	for _, Point in ipairs(Points) do
		local X = math.clamp(Point.X, 0, 1)
		local Y = math.clamp(Point.Y, 0, 1)
		local Mincolumn = math.max(math.floor((X - Radius) * Coveragegridwidth), 0)
		local Maxcolumn = math.min(math.floor((X + Radius) * Coveragegridwidth), Coveragegridwidth - 1)
		local Minrow = math.max(math.floor((Y - Radius) * Coveragegridwidth), 0)
		local Maxrow = math.min(math.floor((Y + Radius) * Coveragegridwidth), Coveragegridwidth - 1)
		for Row = Minrow, Maxrow do
			local Centery = (Row + 0.5) / Coveragegridwidth
			for Column = Mincolumn, Maxcolumn do
				local Index = Row * Coveragegridwidth + Column + 1
				if Entry.Cells[Index] < Entry.Passes and not Touched[Index] then
					local Centerx = (Column + 0.5) / Coveragegridwidth
					if (X - Centerx) ^ 2 + (Y - Centery) ^ 2 <= Radius * Radius then
						Touched[Index] = true
						Entry.Cells[Index] += 1
						Newhits += 1
					end
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

	local Hassticker = Config.Object[Object.Name].Sticker
	local Sticker = if Hassticker then Object:FindFirstChild("Sticker") else nil
	if Sticker then
		Sticker.CanQuery = false
	end
	local Totaldirt = Initializedirt(Object, Singleface, Seed, Version)
	local Totalscratches = Initializescratches(Object)
	local Totalink = if Hassticker then Initializeink(Object) else 0
	local Totalsticker = 0
	if Sticker then
		assert(Sticker:IsA("BasePart"), "RestorationService: " .. Sticker:GetFullName() .. " must be a BasePart")
		Sticker:SetAttribute("SpotKind", "Sticker")
		Sticker:SetAttribute("Health", Spothealth.Sticker)
		Sticker.CanCollide = false
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
	local Dirtshare = math.random(67, 73) / 100
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
	Progress: { [string]: number }?
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

function Restorationservice:Init()
	Core:GetService("DataService"):Register("Restoration", {
		Load = function() end,
		Save = function() return nil end,
		Clear = function(Player)
			local Spot = Peeling[Player]
			if Spot and Spot.Parent then
				Spot:SetAttribute("PeelingBy", nil)
			end
			Peeling[Player] = nil
			Sessionitem[Player] = nil
			Sessions[Player] = nil
			Lastclean[Player] = nil
			Lastscratchclean[Player] = nil
			Lastinkclean[Player] = nil
			Releaseactiveobject(Player)
		end,
	})
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
		local Item = Core:GetService("InventoryService"):TakeRestoredItem(Player, tonumber(ItemId) or 0)
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
		return Object
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
		Lastclean[Player] = nil
		Lastscratchclean[Player] = nil
		Lastinkclean[Player] = nil

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
		local Totalspots = tonumber(Object:GetAttribute("TotalSpots")) or 0
		local Cleanedspots = math.min((tonumber(Object:GetAttribute("CleanedSpots")) or 0) + 1, Totalspots)
		if Totalspots - Cleanedspots < 0.000001 then Cleanedspots = Totalspots end
		Setcleanedspots(Object, Cleanedspots)
		Object:SetAttribute("Cleaned_Sticker", (Object:GetAttribute("Cleaned_Sticker") or 0) + 1)
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
		local Sessionobject = Sessions[Player]
		if not Sessionobject or not Validinkimage(Sessionobject, Target) then return end
		if (Target:GetAttribute("Remaining") or 0) <= 0 then return end
		Target:SetAttribute("HasSolvent", true)
	end)

	Remotemanager:OnServerEvent(self.Name, "ApplyScratchPolish", function(Player, Target)
		local Sessionobject = Sessions[Player]
		if not Sessionobject or not Validscratchimage(Sessionobject, Target) then return end
		if (Target:GetAttribute("Remaining") or 0) <= 0 then return end
		Target:SetAttribute("HasPolish", true)
	end)

	Remotemanager:OnServerEvent(self.Name, "CleanInk", function(Player, Target, Points)
		local Sessionobject = Sessions[Player]
		if not Sessionobject or not Validinkimage(Sessionobject, Target) then return end
		if Target:GetAttribute("HasSolvent") ~= true then return end
		if not Validpoints(Points) then return end
		local Entry = Coverage[Sessionobject][Target.Parent]
		if not Entry then return end
		local Now = os.clock()
		if Now - (Lastinkclean[Player] or 0) < Inkcleaninterval then return end
		Lastinkclean[Player] = Now

		local Newlycovered = Stampcells(Entry, Points, Brushradii.ToothBrush)
		if Newlycovered <= 0 then return end
		local Opaquecells = Coveragecellcount - Entry.Premarked
		local Removedink = Newlycovered / (Opaquecells * Entry.Passes)
		Target:SetAttribute("Remaining", 1 - (Entry.Hits - Entry.Premarked * Entry.Passes) / (Opaquecells * Entry.Passes))
		if Iscovered(Entry) then Target.Parent:SetAttribute("Cleaned", true) end

		local Totalink = tonumber(Sessionobject:GetAttribute("Total_Ink")) or 0
		local Previouscleanedink = tonumber(Sessionobject:GetAttribute("Cleaned_Ink")) or 0
		local Cleanedink = math.min(Previouscleanedink + Removedink, Totalink)
		if Totalink - Cleanedink < 0.000001 then Cleanedink = Totalink end
		local Appliedprogress = Cleanedink - Previouscleanedink
		Sessionobject:SetAttribute("Cleaned_Ink", Cleanedink)
		local Totalspots = tonumber(Sessionobject:GetAttribute("TotalSpots")) or 0
		local Cleanedspots = math.min((tonumber(Sessionobject:GetAttribute("CleanedSpots")) or 0) + Appliedprogress, Totalspots)
		if Totalspots - Cleanedspots < 0.000001 then Cleanedspots = Totalspots end
		Setcleanedspots(Sessionobject, Cleanedspots)
	end)

	Remotemanager:OnServerEvent(self.Name, "CleanScratch", function(Player, Target, Points)
		local Sessionobject = Sessions[Player]
		if not Sessionobject or not Validscratchimage(Sessionobject, Target) then return end
		if Target:GetAttribute("HasPolish") ~= true then return end
		if not Validpoints(Points) then return end
		local Entry = Coverage[Sessionobject][Target.Parent]
		if not Entry then return end
		local Now = os.clock()
		if Now - (Lastscratchclean[Player] or 0) < Scratchcleaninterval then return end
		Lastscratchclean[Player] = Now

		local Newlycovered = Stampcells(Entry, Points, Brushradii.ToothBrush)
		if Newlycovered <= 0 then return end
		local Opaquecells = Coveragecellcount - Entry.Premarked
		local Removedscratch = Newlycovered / (Opaquecells * Entry.Passes)
		Target:SetAttribute("Remaining", 1 - (Entry.Hits - Entry.Premarked * Entry.Passes) / (Opaquecells * Entry.Passes))
		if Iscovered(Entry) then Target.Parent:SetAttribute("Cleaned", true) end

		local Totalscratches = tonumber(Sessionobject:GetAttribute("Total_Scratch")) or 0
		local Previouscleanedscratches = tonumber(Sessionobject:GetAttribute("Cleaned_Scratch")) or 0
		local Cleanedscratches = math.min(Previouscleanedscratches + Removedscratch, Totalscratches)
		if Totalscratches - Cleanedscratches < 0.000001 then Cleanedscratches = Totalscratches end
		local Appliedprogress = Cleanedscratches - Previouscleanedscratches
		Sessionobject:SetAttribute("Cleaned_Scratch", Cleanedscratches)
		local Totalspots = tonumber(Sessionobject:GetAttribute("TotalSpots")) or 0
		local Cleanedspots = math.min((tonumber(Sessionobject:GetAttribute("CleanedSpots")) or 0) + Appliedprogress, Totalspots)
		if Totalspots - Cleanedspots < 0.000001 then Cleanedspots = Totalspots end
		Setcleanedspots(Sessionobject, Cleanedspots)
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

	Remotemanager:OnServerEvent(self.Name, "CleanDirt", function(Player, Toolname, Strokes)
		local Sessionobject = Sessions[Player]
		if not Sessionobject or not Dirttools[Toolname] then return end
		if type(Strokes) ~= "table" or #Strokes == 0 or #Strokes > Maxdirtstrokes then return end
		local Now = os.clock()
		if Now - (Lastclean[Player] or 0) < Dirtcleaninterval then return end
		Lastclean[Player] = Now

		local Removeddirt = 0
		local Seen = {}
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
				local Newlycovered = Stampcells(Entry, Stroke.Points, Brushradii[Toolname])
				if not Iscovered(Entry) and Entry.Hits - Entry.Free >= Opaquepasses * Dirtsnapratio then
					Newlycovered += Coveragecellcount * Entry.Passes - Entry.Hits
					for Index = 1, Coveragecellcount do
						Entry.Cells[Index] = Entry.Passes
					end
					Entry.Hits = Coveragecellcount * Entry.Passes
				end
				if Iscovered(Entry) and Target:GetAttribute("Cleaned") ~= true then
					Target:SetAttribute("Cleaned", true)
					if Isfaceclean(Target) then
						Core:GetService("DailyTaskService"):Record(Player, "Clean", { Tool = Toolname })
					end
				end
				Removeddirt += Newlycovered * 16 / Opaquepasses
			end
		end
		if Removeddirt <= 0 then return end
		local Totaldirt = tonumber(Sessionobject:GetAttribute("Total_Dirt")) or 0
		local Cleaneddirt = math.min((tonumber(Sessionobject:GetAttribute("Cleaned_Dirt")) or 0) + Removeddirt, Totaldirt)
		if Totaldirt - Cleaneddirt < 0.000001 then Cleaneddirt = Totaldirt end
		local Previouscleaneddirt = tonumber(Sessionobject:GetAttribute("Cleaned_Dirt")) or 0
		local Appliedprogress = Cleaneddirt - Previouscleaneddirt
		Sessionobject:SetAttribute("Cleaned_Dirt", Cleaneddirt)
		local Dirtweight = tonumber(Sessionobject:GetAttribute("DirtWeight")) or 1
		local Totalspots = tonumber(Sessionobject:GetAttribute("TotalSpots")) or 0
		local Cleanedspots = math.min((tonumber(Sessionobject:GetAttribute("CleanedSpots")) or 0) + Appliedprogress * Dirtweight, Totalspots)
		if Totalspots - Cleanedspots < 0.000001 then Cleanedspots = Totalspots end
		Setcleanedspots(Sessionobject, Cleanedspots)
	end)

	Remotemanager:OnServerEvent(self.Name, "CleanSpot", function(Player, Spot, Toolname)
		local Sessionobject = Sessions[Player]
		if not Sessionobject then
			return
		end
		if typeof(Spot) ~= "Instance" or not Spot:IsA("BasePart") then
			return
		end
		local Spots = Sessionobject:FindFirstChild("RestorationSpots")
		if not Spots or not Spot:IsDescendantOf(Spots) then
			return
		end
		local Kind = Spot:GetAttribute("SpotKind")
		local Allowedtools = Toolsforspot[Kind]
		local Isallowed = Allowedtools == Toolname
		if type(Allowedtools) == "table" then
			Isallowed = table.find(Allowedtools, Toolname) ~= nil
		end
		if not Isallowed then
			return
		end
		local Now = os.clock()
		if Now - (Lastclean[Player] or 0) < 0.045 then
			return
		end
		Lastclean[Player] = Now
		local Health = (Spot:GetAttribute("Health") or 1) - (Toolpower[Toolname] or 0)
		if Health <= 0 then
			Setcleanedspots(Sessionobject, (Sessionobject:GetAttribute("CleanedSpots") or 0) + 1)
			Sessionobject:SetAttribute("Cleaned_" .. Kind, (Sessionobject:GetAttribute("Cleaned_" .. Kind) or 0) + 1)
			if Kind == "Sticker" and Toolname == "Tweezers" then
				Spot.CanQuery = false
				local Weld = Spot:FindFirstChildOfClass("WeldConstraint")
				if Weld then
					Weld:Destroy()
				end
				Spot.Anchored = true
				local Peeldirection = Spot.CFrame.LookVector
				local Peeledcframe = Spot.CFrame + Peeldirection * 0.65 + Vector3.new(0, 0.28, 0)
				Peeledcframe *= CFrame.Angles(math.rad(55), math.rad(18), math.rad(30))
				local Tween = Tweenservice:Create(Spot, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = Peeledcframe,
					Transparency = 1,
					Size = Vector3.new(Spot.Size.X * 0.72, Spot.Size.Y * 0.72, Spot.Size.Z),
				})
				Tween:Play()
				Tween.Completed:Once(function()
					Spot:Destroy()
				end)
			else
				Spot:Destroy()
			end
		else
			Spot:SetAttribute("Health", Health)
			Spot.Transparency = math.clamp(Spot.Transparency + 0.35, 0, 0.85)
		end
	end)

	Remotemanager:OnServerEvent(self.Name, "SessionEnded", function(Player)
		local Sessionobject = Sessions[Player]
		Sessions[Player] = nil
		Lastclean[Player] = nil
		Lastscratchclean[Player] = nil
		Lastinkclean[Player] = nil
		Returnsessionitem(Player, Sessionobject)
		if Sessionobject and Activeobjects[Player] == Sessionobject then Releaseactiveobject(Player) end
		Core:GetService("CustomerService"):PresentOffer(Player)
	end)
end

return Restorationservice
