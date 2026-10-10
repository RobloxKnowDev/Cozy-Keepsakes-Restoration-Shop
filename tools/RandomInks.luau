local Inkimage = "rbxassetid://95412805630635"
local Replacekeys = { AlarmClock = true, PhotoFrame = true }
local Inkaspect = 1.6
local Minimumwidth = 0.25
local Maximumwidth = 0.4
local Smallestwidth = 0.2
local Facecap = 0.7
local Rotationrange = 20
local Minimumreachable = 0.95
local Minimumcells = 4
local Attempts = 60
local Shrinkrun = 10
local Shrink = 0.85
local Pixelsperstud = 50
local Grid = 32
local Castsperframe = 4000
local Edge = 1e-6
local Stainnames = { Ink = true, ScratchesFrame = true }
local Meshnote = " (some meshes did not load, so their collision shapes were used: check this one)"

local Replicatedstorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Changehistoryservice = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
assert(game:GetService("RunService"):IsEdit(), "Random inks: run this in Edit mode, not during Play")
local Shared = Replicatedstorage.Shared
local Objectconfig = require(Shared.Config.Object)
local Cleaningconfig = require(Shared.Config.Cleaning)
local Facemapping = require(Shared.Utils.FaceMapping)
local Stainlayout = require(Shared.Utils.StainLayout)
local Surfacecast = require(Shared.Utils.SurfaceCast)
local Templates = Replicatedstorage.Asset.Object
local Generator = Random.new()
local Casts = 0

local function Withroot(Root: Instance): { Instance }
	local List = { Root }
	for _, Descendant in ipairs(Root:GetDescendants()) do
		table.insert(List, Descendant)
	end
	return List
end

local function Findinks(Root: Instance): { GuiObject }
	local Inks = {}
	for _, Descendant in ipairs(Root:GetDescendants()) do
		if Descendant:IsA("GuiObject") and Descendant.Name == "Ink" then
			table.insert(Inks, Descendant)
		end
	end
	return Inks
end

local function Removeinks(Inks: { GuiObject })
	for _, Ink in ipairs(Inks) do
		local Surface = Ink.Parent
		Ink.Parent = nil
		if Surface and Surface:IsA("SurfaceGui") and #Surface:GetChildren() == 0 then
			Surface.Parent = nil
		end
	end
end

local function Onsticker(Target: Instance, Sticker: Instance?): boolean
	return Sticker ~= nil and (Target == Sticker or Target:IsDescendantOf(Sticker))
end

local function Guiextent(Size: Vector3, Facename: string): Vector2
	if Facename == "Top" or Facename == "Bottom" then
		return Vector2.new(Size.Z, Size.X)
	end
	if Facename == "Front" or Facename == "Back" then
		return Vector2.new(Size.X, Size.Y)
	end
	return Vector2.new(Size.Z, Size.Y)
end

local function Usablesurface(Part: BasePart, Facename: string): (boolean, SurfaceGui?)
	local Existing = Part:FindFirstChild("Ui" .. Facename)
	if not Existing then
		return true, nil
	end
	if Existing:IsA("SurfaceGui") and Existing.Face.Name == Facename and Existing.Enabled and not Existing:FindFirstChild("Ink") then
		return true, Existing
	end
	return false, nil
end

local function Buildink(Part: BasePart, Facename: string, Existing: SurfaceGui?, Centre: Vector2, Width: number, Height: number, Rotation: number): (SurfaceGui, Frame, ImageLabel)
	local Surface = Existing
	if not Surface then
		Surface = Instance.new("SurfaceGui")
		Surface.Name = "Ui" .. Facename
		Surface.Face = Enum.NormalId[Facename]
		Surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		Surface.PixelsPerStud = Pixelsperstud
		Surface.LightInfluence = 1
		Surface.ClipsDescendants = true
		Surface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	end
	local Extent = Guiextent(Part.Size, Facename)
	local Frame = Instance.new("Frame")
	Frame.Name = "Ink"
	Frame:SetAttribute("RandomInk", true)
	Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	Frame.BackgroundTransparency = 1
	Frame.BorderSizePixel = 0
	Frame.Position = UDim2.fromScale(Centre.X, Centre.Y)
	Frame.Size = UDim2.fromScale(Width / Extent.X, Height / Extent.Y)
	if Surface.SizingMode == Enum.SurfaceGuiSizingMode.PixelsPerStud then
		Frame.Rotation = Rotation
	end
	local Texture = Instance.new("ImageLabel")
	Texture.Name = "Texture"
	Texture.AnchorPoint = Vector2.new(0.5, 0.5)
	Texture.Position = UDim2.fromScale(0.5, 0.5)
	Texture.Size = UDim2.fromScale(1, 1)
	Texture.BackgroundTransparency = 1
	Texture.BorderSizePixel = 0
	Texture.ScaleType = Enum.ScaleType.Stretch
	Texture.Image = Inkimage
	Texture.Parent = Frame
	Frame.Parent = Surface
	Surface.Parent = Part
	return Surface, Frame, Texture
end

local function Coveredcells(Layout: Stainlayout.Layout): { number }
	local Cells = {}
	local Minimum, Maximum = Layout.Minimum, Layout.Maximum
	for Row = math.max(math.floor(Minimum.Y * Grid), 0), math.min(math.ceil(Maximum.Y * Grid), Grid) - 1 do
		for Column = math.max(math.floor(Minimum.X * Grid), 0), math.min(math.ceil(Maximum.X * Grid), Grid) - 1 do
			local Lowu, Lowv, Highu, Highv = math.huge, math.huge, -math.huge, -math.huge
			for Corner = 0, 3 do
				local Point = Stainlayout.GetTexturePoint(Layout, Vector2.new((Column + Corner % 2) / Grid, (Row + Corner // 2) / Grid))
				Lowu, Highu = math.min(Lowu, Point.X), math.max(Highu, Point.X)
				Lowv, Highv = math.min(Lowv, Point.Y), math.max(Highv, Point.Y)
			end
			if Lowu < 1 - Edge and Highu > Edge and Lowv < 1 - Edge and Highv > Edge then
				table.insert(Cells, Row * Grid + Column + 1)
			end
		end
	end
	return Cells
end

local function Forbiddencells(Root: Instance, Part: BasePart, Facename: string, Twin: { [Instance]: Instance }): { [number]: boolean }
	local Forbidden = {}
	for _, Frame in ipairs(Root:GetDescendants()) do
		local Surface = Frame.Parent :: Instance
		if Frame:IsA("GuiObject") and Stainnames[Frame.Name] and Surface:IsA("SurfaceGui") and Surface.Parent == Part and Surface.Face.Name == Facename then
			local Texture = Frame:FindFirstChild("Texture")
			assert(Texture, Twin[Frame]:GetFullName() .. " has no Texture, the game needs one")
			for _, Cell in ipairs(Coveredcells(Stainlayout.GetLayout(Twin[Texture] :: ImageLabel))) do
				local Column, Row = (Cell - 1) % Grid, (Cell - 1) // Grid
				for Nearrow = math.max(Row - 1, 0), math.min(Row + 1, Grid - 1) do
					for Nearcolumn = math.max(Column - 1, 0), math.min(Column + 1, Grid - 1) do
						Forbidden[Nearrow * Grid + Nearcolumn + 1] = true
					end
				end
			end
		end
	end
	return Forbidden
end

local function Coverage(Texture: ImageLabel, Reach: { boolean }, Forbidden: { [number]: boolean }): (number, number, boolean)
	local Layout = Stainlayout.GetLayout(Texture)
	for _, Corner in ipairs({ Vector2.zero, Vector2.xAxis, Vector2.yAxis, Vector2.one }) do
		local Point = Stainlayout.GetFacePoint(Layout, Corner)
		if Point.X < 0 or Point.X > 1 or Point.Y < 0 or Point.Y > 1 then
			return 0, 0, false
		end
	end
	if next(Forbidden) then
		for _, Cell in ipairs(Coveredcells(Layout)) do
			if Forbidden[Cell] then
				return 0, 0, false
			end
		end
	end
	local Required, Reachable = 0, 0
	for Row = 0, Grid - 1 do
		for Column = 0, Grid - 1 do
			if Stainlayout.Contains(Layout, Vector2.new((Column + 0.5) / Grid, (Row + 0.5) / Grid)) then
				Required += 1
				if Reach[Row * Grid + Column + 1] then
					Reachable += 1
				end
			end
		end
	end
	return Required, Reachable, math.max(Layout.Axisu.Magnitude, Layout.Axisv.Magnitude) <= 2
end

local function Resolveslot(Caster, Decal: Decal, Distance: number, Forbidden: { [number]: boolean })
	local Part = Decal.Parent :: BasePart
	local Facename = Decal.Face.Name
	local Normal = Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Decal.Face))
	local Length = Distance + Part.Size.Magnitude
	local Reach = table.create(Grid * Grid, false)
	local Cells = {}
	for Row = 0, Grid - 1 do
		for Column = 0, Grid - 1 do
			local Point = Part.CFrame:PointToWorldSpace(Facemapping.GetDecalLocalPoint(Part.Size, Facename, (Column + 0.5) / Grid, (Row + 0.5) / Grid))
			local Hit = Caster:Cast(Point + Normal * Distance, -Normal * Length)
			if Hit and Hit.Instance == Part and Facemapping.ShowsDecal(Decal, Hit.DecalNormal) then
				Reach[Row * Grid + Column + 1] = true
				if not Forbidden[Row * Grid + Column + 1] then
					table.insert(Cells, Row * Grid + Column + 1)
				end
			end
			Casts += 1
			if Casts % Castsperframe == 0 then
				task.wait()
			end
		end
	end
	local Extent = Facemapping.GetDecalSize(Part.Size, Facename)
	return { Part = Part, Facename = Facename, Reach = Reach, Cells = Cells, Forbidden = Forbidden, Weight = #Cells / (Grid * Grid) * Extent.X * Extent.Y }
end

local function Pickslot(Slots)
	local Total = 0
	for _, Slot in ipairs(Slots) do
		Total += Slot.Weight
	end
	local Roll = Generator:NextNumber() * Total
	for _, Slot in ipairs(Slots) do
		Roll -= Slot.Weight
		if Roll <= 0 then
			return Slot
		end
	end
	return Slots[#Slots]
end

local function Choosespot(Template: Instance, Clone: Instance, Copies: { Instance }, Sticker: Instance?, Twin: { [Instance]: Instance })
	local Caster = Surfacecast.new(Clone)
	local Loaded = Caster:Load()
	local Pivot = (Template :: PVInstance):GetPivot()
	local Extents = if Clone:IsA("Model") then Clone:GetExtentsSize() else (Clone :: BasePart).Size
	local Distance = Extents.Magnitude + 1
	local Slots = {}
	local Seen = {}
	for _, Decal in ipairs(Copies) do
		if Decal:IsA("Decal") and Cleaningconfig.DirtDecals[Decal.Name] and Decal.Parent and Decal.Parent:IsA("BasePart") and not Onsticker(Decal.Parent, Sticker) then
			local Part = Decal.Parent :: BasePart
			local Normal = Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Decal.Face))
			Seen[Part] = Seen[Part] or {}
			if
				not Seen[Part][Decal.Face]
				and Pivot:VectorToObjectSpace(Normal).Y >= -0.5
				and not (Template.Name == Objectconfig.Offer.TutorialObject and Decal.Face.Name == Objectconfig.Offer.TutorialDirtFace)
				and (Usablesurface(Part, Decal.Face.Name))
			then
				Seen[Part][Decal.Face] = true
				local Slot = Resolveslot(Caster, Decal, Distance, Forbiddencells(Clone, Part, Decal.Face.Name, Twin))
				if #Slot.Cells > 0 then
					table.insert(Slots, Slot)
				end
			end
		end
	end
	Caster:Destroy()
	if #Slots == 0 then
		return nil, Loaded
	end
	local Holder = Instance.new("Part")
	local Width = Generator:NextNumber(Minimumwidth, Maximumwidth) * Extents.Magnitude / 2
	for Attempt = 1, Attempts do
		if Attempt > 1 and (Attempt - 1) % Shrinkrun == 0 then
			Width *= Shrink
		end
		local Slot = Pickslot(Slots)
		local Cell = Slot.Cells[Generator:NextInteger(1, #Slot.Cells)] - 1
		local Decalpoint = Vector2.new((Cell % Grid + Generator:NextNumber()) / Grid, (Cell // Grid + Generator:NextNumber()) / Grid)
		local World = Slot.Part.CFrame:PointToWorldSpace(Facemapping.GetDecalLocalPoint(Slot.Part.Size, Slot.Facename, Decalpoint.X, Decalpoint.Y))
		local Centre = Facemapping.GetPoint(Slot.Part, World, Slot.Facename)
		local Extent = Guiextent(Slot.Part.Size, Slot.Facename)
		local Inkwidth = math.min(Width, Facecap * Extent.X, Facecap * Extent.Y * Inkaspect)
		if Inkwidth >= Smallestwidth then
			local _, Existing = Usablesurface(Slot.Part, Slot.Facename)
			local Copy = if Existing then Existing:Clone() else nil
			if Copy and Copy.Adornee == Slot.Part then
				Copy.Adornee = Holder
			end
			local Rotation = Generator:NextNumber(-Rotationrange, Rotationrange)
			Holder.Name = Slot.Part.Name
			Holder.Size = Slot.Part.Size
			local Surface, _, Texture = Buildink(Holder, Slot.Facename, Copy, Centre, Inkwidth, Inkwidth / Inkaspect, Rotation)
			local Required, Reachable, Fits = Coverage(Texture, Slot.Reach, Slot.Forbidden)
			Surface:Destroy()
			if Fits and Required >= Minimumcells and Reachable >= Required * Minimumreachable then
				Holder:Destroy()
				return { Part = Slot.Part, Facename = Slot.Facename, Centre = Centre, Width = Inkwidth, Rotation = Rotation, Share = Reachable / Required }, Loaded
			end
		end
	end
	Holder:Destroy()
	return nil, Loaded
end

local function Placeink(Key: string): (string, Frame?)
	local Template = Templates:FindFirstChild(Key)
	if not Template then
		return "no template named " .. Key .. " in ReplicatedStorage.Asset.Object", nil
	end
	local Oldinks = Findinks(Template)
	local Replace = false
	for _, Ink in ipairs(Oldinks) do
		if not (Replacekeys[Key] and Ink:GetAttribute("RandomInk") ~= true) then
			return "already has an Ink, nothing changed", nil
		end
		Replace = true
	end
	local Originals = Withroot(Template)
	local Clone = Template:Clone()
	local Copies = Withroot(Clone)
	if #Copies ~= #Originals then
		Clone:Destroy()
		return "has non-Archivable instances, skipped", nil
	end
	local Twin = {}
	for Index, Copy in ipairs(Copies) do
		Twin[Copy] = Originals[Index]
	end
	Removeinks(Findinks(Clone))
	local Sticker = Clone:FindFirstChild("Sticker")
	for _, Copy in ipairs(Copies) do
		if Copy:IsA("BasePart") and Onsticker(Copy, Sticker) then
			Copy.CanCollide = false
			Copy.CanQuery = false
		end
	end
	Clone.Parent = Workspace
	local Success, Chosen, Loaded = pcall(Choosespot, Template, Clone, Copies, Sticker, Twin)
	Clone.Parent = nil
	if not Success then
		error(Chosen, 0)
	end
	local Note = if Loaded then "" else Meshnote
	if not Chosen then
		return "no visible spot found (no dirt face facing out, or every face too small or hidden): place this Ink by hand"
			.. (if Replace then ", its old Ink was kept" else "")
			.. Note,
			nil
	end
	local Part = Twin[Chosen.Part] :: BasePart
	assert(
		Part and Part.ClassName == Chosen.Part.ClassName and Part.Name == Chosen.Part.Name and Part.Size == Chosen.Part.Size,
		"the working copy of " .. Chosen.Part.Name .. " does not match the template, nothing changed"
	)
	Removeinks(Oldinks)
	local _, Existing = Usablesurface(Part, Chosen.Facename)
	local _, Frame, Texture = Buildink(Part, Chosen.Facename, Existing, Chosen.Centre, Chosen.Width, Chosen.Width / Inkaspect, Chosen.Rotation)
	Stainlayout.GetLayout(Texture)
	return string.format(
		"%sInk on %s, face %s, %.2f x %.2f studs, rotation %.0f, %d %% reachable%s",
		if Replace then "old Ink replaced, new " else "",
		Part:GetFullName(),
		Chosen.Facename,
		Chosen.Width,
		Chosen.Width / Inkaspect,
		Frame.Rotation,
		math.floor(Chosen.Share * 100 + 0.5),
		Note
	),
		Frame
end

local Keys = {}
for Key, Entry in pairs(Objectconfig.Object) do
	if Entry.Sticker then
		table.insert(Keys, Key)
	end
end
table.sort(Keys)
local Recorded, Recording = pcall(Changehistoryservice.TryBeginRecording, Changehistoryservice, "RandomInks", "Random inks")
local Created = {}
for _, Key in ipairs(Keys) do
	local Success, Message, Frame = pcall(Placeink, Key)
	if not Success then
		warn(Key .. ": error, " .. tostring(Message))
	else
		if Frame then
			table.insert(Created, Frame)
		end
		print(Key .. ": " .. Message)
	end
end
if Recorded and Recording then
	Changehistoryservice:FinishRecording(Recording, Enum.FinishRecordingOperation.Commit)
end
Selection:Set(Created)
print(string.format("Random inks: %d created, %d casts", #Created, Casts))
