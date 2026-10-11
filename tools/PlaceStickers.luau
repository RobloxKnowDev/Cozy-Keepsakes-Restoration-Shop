local Images = {
	PhotoFrame = "rbxassetid://118617501533014",
	AlarmClock = "rbxassetid://72421880488456",
	ClothesIron = "rbxassetid://75838609445826",
	Teapot = "rbxassetid://94340781823480",
	ToyCar = "rbxassetid://80253668854545",
	KitchenScale = "rbxassetid://75631476794540",
	RetroFan = "rbxassetid://77652686038594",
	AntiqueGlasses = "rbxassetid://113508220449747",
	RotaryPhone = "rbxassetid://103731294449649",
	ElectricTrain = "rbxassetid://95195129322283",
	WallClock = "rbxassetid://81685925589739",
	Typewriter = "rbxassetid://140616596637498",
	RecordPlayer = "rbxassetid://75882371022385",
	SewingMachine = "rbxassetid://94412039440432",
	VintageGuitar = "rbxassetid://138984512757021",
	FilmProjector = "rbxassetid://110221902946184",
	MantelClock = "rbxassetid://88136800024175",
	Television = "rbxassetid://100590894875137",
	SlotMachine = "rbxassetid://114960986264127",
	CuckooClock = "rbxassetid://102748916623478",
	AntiqueSafe = "rbxassetid://110240517338334",
	Jukebox = "rbxassetid://110948313037285",
	AntiqueTelescope = "rbxassetid://90102798659829",
	AntiqueStatue = "rbxassetid://123917683285818",
	MagicMirror = "rbxassetid://112359431026493",
}
local Imageaspect = 1.5
local Cover = 1.1
local Thickness = 0.0064
local Clearance = 0.002
local Rise = 0.05
local Lift = 0.01
local Standoff = 0.02
local Upright = 45
local Inkgrid = Vector2.new(9, 7)
local Footgrid = Vector2.new(17, 13)
local Papercolor = Color3.fromRGB(250, 246, 235)
local Meshnote = " (some meshes did not load, so their collision shapes were used: check this one)"

local Replicatedstorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Changehistoryservice = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
assert(game:GetService("RunService"):IsEdit(), "Place stickers: run this in Edit mode, not during Play")
local Shared = Replicatedstorage.Shared
local Objectconfig = require(Shared.Config.Object)
local Facemapping = require(Shared.Utils.FaceMapping)
local Stainlayout = require(Shared.Utils.StainLayout)
local Surfacecast = require(Shared.Utils.SurfaceCast)
local Getobjectrotation = require(Shared.Utils.ObjectRotation)
local Templates = Replicatedstorage.Asset.Object

local function Findinks(Root: Instance): { GuiObject }
	local Inks = {}
	for _, Descendant in ipairs(Root:GetDescendants()) do
		if Descendant:IsA("GuiObject") and Descendant.Name == "Ink" then
			table.insert(Inks, Descendant)
		end
	end
	return Inks
end

local function Worldcorners(Layout: Stainlayout.Layout): { Vector3 }
	local Corners = {}
	for _, Corner in ipairs({ Vector2.zero, Vector2.xAxis, Vector2.yAxis, Vector2.one }) do
		local Point = Stainlayout.GetFacePoint(Layout, Corner)
		table.insert(Corners, Layout.Part.CFrame:PointToWorldSpace(Facemapping.GetDecalLocalPoint(Layout.Part.Size, Layout.Facename, Point.X, Point.Y)))
	end
	return Corners
end

local function Wantedup(Template: PVInstance, Key: string, Normal: Vector3): Vector3
	local Pivot = Template:GetPivot()
	local Flat = Pivot.UpVector - Normal * Pivot.UpVector:Dot(Normal)
	if Flat.Magnitude >= 0.5 then
		return Flat
	end
	local Back = Pivot:VectorToWorldSpace(Getobjectrotation(Key):VectorToObjectSpace(Vector3.xAxis))
	return Back - Normal * Back:Dot(Normal)
end

local function Survey(Caster, Part: BasePart?, Origin: Vector3, Edgeu: Vector3, Edgev: Vector3, Grid: Vector2, Centre: Vector3, Normal: Vector3, Distance: number)
	local Top, Toppart, Samples = nil, nil, {}
	for Row = 0, Grid.Y - 1 do
		for Column = 0, Grid.X - 1 do
			local Point = Origin + Edgeu * (Column / (Grid.X - 1)) + Edgev * (Row / (Grid.Y - 1))
			local Hit = if Part
				then Caster:CastPart(Part, Point + Normal * Distance, -Normal * (Distance * 2))
				else Caster:Cast(Point + Normal * Distance, -Normal * (Distance * 2))
			local Depth = if Hit then (Hit.Position - Centre):Dot(Normal) else -math.huge
			if Hit and (not Top or Depth > Top) then
				Top, Toppart = Depth, Hit.Instance
			end
			local Weight = (if Row == 0 or Row == Grid.Y - 1 then 0.5 else 1) * (if Column == 0 or Column == Grid.X - 1 then 0.5 else 1)
			table.insert(Samples, { Depth = Depth, Weight = Weight })
		end
	end
	return { Top = Top, Part = Toppart, Samples = Samples }
end

local function Measure(Clone: Instance, Inkpart: BasePart, Corner: Vector3, Across: Vector3, Down: Vector3, Centre: Vector3, Normal: Vector3, Right: Vector3, Below: Vector3, Width: number, Height: number)
	local Caster = Surfacecast.new(Clone)
	local Loaded = Caster:Load()
	local Extents = if Clone:IsA("Model") then Clone:GetExtentsSize() else (Clone :: BasePart).Size
	local Distance = Extents.Magnitude + 1
	local Ink = Survey(Caster, nil, Corner, Across, Down, Inkgrid, Centre, Normal, Distance)
	local Own = Survey(Caster, Inkpart, Corner, Across, Down, Inkgrid, Centre, Normal, Distance)
	local Foot = Survey(Caster, nil, Centre - (Right * Width + Below * Height) / 2, Right * Width, Below * Height, Footgrid, Centre, Normal, Distance)
	Caster:Destroy()
	return Ink, Own, Foot, Loaded
end

local function Buildsticker(Image: string, Cframe: CFrame, Width: number, Height: number): Part
	local Sticker = Instance.new("Part")
	Sticker.Name = "Sticker"
	Sticker:SetAttribute("RandomSticker", true)
	Sticker.Size = Vector3.new(Width, Height, Thickness)
	Sticker.CFrame = Cframe
	Sticker.Anchored = true
	Sticker.CanCollide = false
	Sticker.CanTouch = false
	Sticker.CastShadow = false
	Sticker.Material = Enum.Material.SmoothPlastic
	Sticker.Color = Papercolor
	Sticker.TopSurface = Enum.SurfaceType.Smooth
	Sticker.BottomSurface = Enum.SurfaceType.Smooth
	local Decal = Instance.new("Decal")
	Decal.Name = "Image"
	Decal.Face = Enum.NormalId.Front
	Decal.Texture = Image
	Decal.Parent = Sticker
	return Sticker
end

local function Placesticker(Key: string): (string, BasePart?, boolean)
	local Image = Images[Key]
	if not Image then
		return "no sticker image for " .. Key .. " in this script, skipped", nil, false
	end
	local Template = Templates:FindFirstChild(Key)
	if not Template then
		return "no template named " .. Key .. " in ReplicatedStorage.Asset.Object, skipped", nil, false
	end
	local Old = Template:FindFirstChild("Sticker")
	if Old and Old:GetAttribute("RandomSticker") == true then
		return "already has a sticker from this script, nothing changed", nil, false
	end
	local Inks = Findinks(Template)
	if #Inks ~= 1 then
		return string.format("has %d Inks instead of 1 (run tools/RandomInks.luau first), nothing changed", #Inks), nil, false
	end
	local Texture = Inks[1]:FindFirstChild("Texture")
	assert(Texture and Texture:IsA("ImageLabel"), Inks[1]:GetFullName() .. " has no ImageLabel named Texture")
	local Layout = Stainlayout.GetLayout(Texture)
	local Corners = Worldcorners(Layout)
	local Normal = Layout.Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Layout.Face))
	local Across = Corners[2] - Corners[1]
	local Down = Corners[3] - Corners[1]
	local Right = Across.Unit
	local Below = (Down - Right * Down:Dot(Right)).Unit
	local Centre = (Corners[1] + Corners[4]) / 2
	local Inkwidth, Inkheight = 0, 0
	for _, Corner in ipairs(Corners) do
		Inkwidth = math.max(Inkwidth, 2 * math.abs((Corner - Centre):Dot(Right)))
		Inkheight = math.max(Inkheight, 2 * math.abs((Corner - Centre):Dot(Below)))
	end
	local Width = Cover * math.max(Inkwidth, Inkheight * Imageaspect)
	local Height = Width / Imageaspect
	local Wanted = Wantedup(Template :: PVInstance, Key, Normal).Unit
	if (-Below):Dot(Wanted) < 0 then
		Right, Below = -Right, -Below
	end
	local Turn = math.deg(math.acos(math.min((-Below):Dot(Wanted), 1)))
	local Clone = Template:Clone()
	assert(Clone, Template:GetFullName() .. " must be Archivable")
	local Copy = Clone:FindFirstChild("Sticker")
	if Copy then
		Copy:Destroy()
	end
	local Copies = Findinks(Clone)
	assert(#Copies == 1, Inks[1]:GetFullName() .. " and its SurfaceGui must be Archivable")
	local Inkpart = (Copies[1].Parent :: SurfaceGui).Parent :: BasePart
	Clone.Parent = Workspace
	local Success, Ink, Own, Foot, Loaded = pcall(Measure, Clone, Inkpart, Corners[1], Across, Down, Centre, Normal, Right, Below, Width, Height)
	Clone.Parent = nil
	if not Success then
		error(Ink, 0)
	end
	local Depth, Setter, Notes = 0, nil, {}
	if not Ink.Top then
		table.insert(Notes, ", no surface found under the Ink, laid on the face of the part box: check it")
	elseif Foot.Top and Foot.Top - Ink.Top > Rise then
		Depth, Setter = Ink.Top, Ink.Part
		table.insert(Notes, string.format(", something next to the Ink stands %.2f stud higher, the sticker may go into it: check it", Foot.Top - Ink.Top))
	elseif Foot.Top and Foot.Top > Ink.Top then
		Depth, Setter = Foot.Top, Foot.Part
	else
		Depth, Setter = Ink.Top, Ink.Part
	end
	if Ink.Top and not Own.Top then
		table.insert(Notes, ", the Ink's part was not found under the Ink: check it")
	elseif Ink.Top and Depth - Own.Top > Lift then
		table.insert(Notes, string.format(", it sits %.2f stud above the Ink to clear %s next to it or over it: check it", Depth - Own.Top, Setter.Name))
	end
	local Lifted, Area = 0, 0
	for _, Sample in ipairs(Foot.Samples) do
		Area += Sample.Weight
		if Depth + Clearance - Sample.Depth > Rise then
			Lifted += Sample.Weight
		end
	end
	if Lifted / Area >= Standoff then
		table.insert(Notes, string.format(", the flat sticker stands more than %.2f stud off the surface under %d%% of its area (curved or uneven surface, or past an edge): check it", Rise, math.round(Lifted / Area * 100)))
	end
	if Turn > Upright then
		table.insert(Notes, string.format(", the Ink runs sideways, so the image is turned %d degrees from upright: check it", math.round(Turn)))
	end
	local Position = Centre + Normal * (Depth + Clearance + Thickness / 2)
	local Sticker = Buildsticker(Image, CFrame.fromMatrix(Position, -Right, -Below), Width, Height)
	if Old then
		Old.Parent = nil
	end
	Sticker.Parent = Template
	return string.format(
		"%sSticker over the Ink on %s, face %s, %.2f x %.2f studs%s%s",
		if Old then "old Sticker replaced, new " else "",
		Layout.Part:GetFullName(),
		Layout.Facename,
		Width,
		Height,
		table.concat(Notes),
		if Loaded then "" else Meshnote
	),
		Sticker,
		Old ~= nil
end

local Keys = {}
for Key, Entry in pairs(Objectconfig.Object) do
	if Entry.Sticker then
		table.insert(Keys, Key)
	end
end
table.sort(Keys)
local Recorded, Recording = pcall(Changehistoryservice.TryBeginRecording, Changehistoryservice, "PlaceStickers", "Place stickers")
local Created = {}
local Replaced = 0
for _, Key in ipairs(Keys) do
	local Success, Message, Sticker, Wasreplaced = pcall(Placesticker, Key)
	if not Success then
		warn(Key .. ": error, " .. tostring(Message))
	else
		if Sticker then
			table.insert(Created, Sticker)
		end
		if Wasreplaced then
			Replaced += 1
		end
		print(Key .. ": " .. Message)
	end
end
if Recorded and Recording then
	Changehistoryservice:FinishRecording(Recording, Enum.FinishRecordingOperation.Commit)
end
Selection:Set(Created)
print(string.format("Place stickers: %d created, %d of them replace an old Sticker", #Created, Replaced))
