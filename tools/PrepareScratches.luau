local Backnormal = Enum.NormalId.Right
local Backface = Backnormal.Name
local Pixelsperstud = 50
local Cornertolerance = 1e-3
local Facetolerance = 1e-3
local Surfacenames = { UiTop = true, UiBottom = true, UiLeft = true, UiRight = true, UiFront = true, UiBack = true }

local Replicatedstorage = game:GetService("ReplicatedStorage")
local Changehistoryservice = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
assert(game:GetService("RunService"):IsEdit(), "Prepare scratches: run this in Edit mode, not during Play")
local Shared = Replicatedstorage.Shared
local Objectconfig = require(Shared.Config.Object)
local Facemapping = require(Shared.Utils.FaceMapping)
local Stainlayout = require(Shared.Utils.StainLayout)
local Templates = Replicatedstorage.Asset.Object
local Tutorialkey = Objectconfig.Offer.TutorialObject

local function Pathin(Root: Instance, Item: Instance): string
	local Names = {}
	local Node = Item
	while Node ~= Root do
		table.insert(Names, 1, Node.Name)
		Node = Node.Parent :: Instance
	end
	return table.concat(Names, ".")
end

local function Canvasextent(Size: Vector3, Facename: string): Vector2
	if Facename == "Top" or Facename == "Bottom" then
		return Vector2.new(Size.Z, Size.X)
	end
	if Facename == "Front" or Facename == "Back" then
		return Vector2.new(Size.X, Size.Y)
	end
	return Vector2.new(Size.Z, Size.Y)
end

local function Worldcorners(Layout: Stainlayout.Layout): { Vector3 }
	local Corners = {}
	for _, Corner in ipairs({ Vector2.zero, Vector2.xAxis, Vector2.yAxis, Vector2.one }) do
		local Point = Stainlayout.GetFacePoint(Layout, Corner)
		table.insert(Corners, Layout.Part.CFrame:PointToWorldSpace(Facemapping.GetDecalLocalPoint(Layout.Part.Size, Layout.Facename, Point.X, Point.Y)))
	end
	return Corners
end

local function Newcanvas(): SurfaceGui
	local Canvas = Instance.new("SurfaceGui")
	Canvas.Name = "Ui" .. Backface
	Canvas.Face = Backnormal
	Canvas.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	Canvas.PixelsPerStud = Pixelsperstud
	Canvas.LightInfluence = 1
	Canvas.ClipsDescendants = true
	Canvas.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	return Canvas
end

local function Planleftovers()
	local Keys = {}
	for Key in pairs(Objectconfig.Object) do
		if Key ~= Tutorialkey then
			table.insert(Keys, Key)
		end
	end
	table.sort(Keys)
	local Actions = {}
	local Count = 0
	for _, Key in ipairs(Keys) do
		local Template = Templates:FindFirstChild(Key)
		if not Template then
			table.insert(Actions, { Key = Key })
			continue
		end
		for _, Descendant in ipairs(Template:GetDescendants()) do
			if Descendant:IsA("GuiObject") and Descendant.Name == "ScratchesFrame" then
				table.insert(Actions, { Key = Key, Template = Template, Frame = Descendant })
				Count += 1
			end
		end
	end
	return Actions, Count
end

local function Planphoto()
	local Photo = Templates:FindFirstChild(Tutorialkey)
	assert(Photo, "Prepare scratches: no template named " .. Tutorialkey .. " in ReplicatedStorage.Asset.Object")
	local Plate = Photo:FindFirstChild("Cube.002")
	if not Plate then
		local Frames = {}
		for _, Descendant in ipairs(Photo:GetDescendants()) do
			if Descendant:IsA("GuiObject") and Descendant.Name == "ScratchesFrame" then
				table.insert(Frames, Descendant)
			end
		end
		local Canvas = if #Frames == 1 then Frames[1].Parent else nil
		local Board = if Canvas then Canvas.Parent else nil
		assert(
			Canvas and Canvas:IsA("SurfaceGui") and Canvas.Name == "Ui" .. Backface and Board and Board:IsA("BasePart") and Board.Name == "Base" and Board.Parent == Photo,
			"Prepare scratches: "
				.. Photo:GetFullName()
				.. " has no Cube.002 and its only ScratchesFrame is not on Base.Ui"
				.. Backface
				.. " ("
				.. #Frames
				.. " ScratchesFrame found): bring back the PhotoFrame as it was (Ctrl+Z or a saved copy) and run this again"
		)
		return { Photo = Photo, Prepared = true, Path = Pathin(Photo, Canvas) }
	end
	assert(Plate:IsA("BasePart"), "Prepare scratches: " .. Plate:GetFullName() .. " must be the invisible plate Part")
	local Old = Plate:FindFirstChild("UiBack")
	assert(Old and Old:IsA("SurfaceGui"), "Prepare scratches: " .. Plate:GetFullName() .. " has no SurfaceGui named UiBack, the tutorial ScratchesFrame must be in it")
	local Frames = {}
	for _, Child in ipairs(Old:GetChildren()) do
		if Child.Name == "ScratchesFrame" then
			table.insert(Frames, Child)
		end
	end
	assert(#Frames == 1, "Prepare scratches: " .. Old:GetFullName() .. " must hold exactly one ScratchesFrame (the tutorial scratch), it holds " .. #Frames)
	local Frame = Frames[1]
	local Texture = Frame:FindFirstChild("Texture")
	assert(Texture and Texture:IsA("ImageLabel"), "Prepare scratches: " .. Frame:GetFullName() .. " has no ImageLabel named Texture")
	for _, Descendant in ipairs(Photo:GetDescendants()) do
		assert(
			not (Descendant:IsA("GuiObject") and Descendant.Name == "Ink" and Descendant:GetAttribute("RandomInk") == true),
			"Prepare scratches: "
				.. Descendant:GetFullName()
				.. " was placed by RandomInks, which must run after this script: press Ctrl+Z to undo RandomInks or delete that Ink, then run this script, then RandomInks"
		)
	end
	local Platenormal = Plate.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Old.Face))
	local Boards = {}
	for _, Child in ipairs(Photo:GetChildren()) do
		if Child:IsA("BasePart") and Child.Name == "Base" then
			local Inside = Child.CFrame:PointToObjectSpace(Plate.Position)
			local Half = Child.Size / 2
			local Normal = Child.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Backnormal))
			if math.abs(Inside.X) <= Half.X and math.abs(Inside.Y) <= Half.Y and math.abs(Inside.Z) <= Half.Z and Normal:Dot(Platenormal) >= 1 - Facetolerance then
				table.insert(Boards, Child)
			end
		end
	end
	assert(
		#Boards == 1,
		"Prepare scratches: expected exactly one part named Base around "
			.. Plate:GetFullName()
			.. " with its "
			.. Backface
			.. " face turned like "
			.. Old.Name
			.. " (the back board), found "
			.. #Boards
	)
	local Board = Boards[1]
	local Target = Board:FindFirstChild("Ui" .. Backface)
	if Target then
		assert(
			Target:IsA("SurfaceGui")
				and Target.Face == Backnormal
				and Target.Enabled
				and Target.SizingMode == Enum.SurfaceGuiSizingMode.PixelsPerStud
				and (Target.Adornee == nil or Target.Adornee == Board)
				and not Target:FindFirstChild("ScratchesFrame"),
			"Prepare scratches: "
				.. Target:GetFullName()
				.. " cannot take the tutorial scratch: it must be an enabled SurfaceGui with Face "
				.. Backface
				.. ", SizingMode PixelsPerStud, no Adornee and no ScratchesFrame yet, fix or delete it and run this again"
		)
	end
	local Corners = Worldcorners(Stainlayout.GetLayout(Texture))
	local Density = if Target then Target.PixelsPerStud else Pixelsperstud
	local Extent = Canvasextent(Board.Size, Backface) * Density
	local function Pixel(World: Vector3): Vector2
		local Point = Facemapping.GetPoint(Board, World, Backface)
		return Vector2.new(Point.X * Extent.X, Point.Y * Extent.Y)
	end
	local Origin = Pixel(Corners[1])
	local Alongu = Pixel(Corners[2]) - Origin
	local Alongv = Pixel(Corners[3]) - Origin
	local Width, Height = Alongu.Magnitude, Alongv.Magnitude
	assert(
		Alongu.X * Alongv.Y - Alongu.Y * Alongv.X > 0 and math.abs(Alongu:Dot(Alongv)) / Width / Density <= Cornertolerance,
		"Prepare scratches: "
			.. Texture:GetFullName()
			.. " is drawn slanted ("
			.. Old.Name
			.. " is FixedSize and stretches a rotated frame), a PixelsPerStud canvas cannot keep that shape: set the SizingMode of "
			.. Old.Name
			.. " to PixelsPerStud or the Rotation to 0, check the scratch, and run this again"
	)
	local Centre = Origin + (Alongu + Alongv) / 2
	local Anchor = Frame.AnchorPoint
	local Position = UDim2.fromScale((Centre.X - (0.5 - Anchor.X) * Width) / Extent.X, (Centre.Y - (0.5 - Anchor.Y) * Height) / Extent.Y)
	local Size = UDim2.fromScale(Width / Extent.X, Height / Extent.Y)
	local Rotation = math.round(math.deg(math.atan2(Alongu.Y, Alongu.X)) * 1000) / 1000
	local Holder = Instance.new("Part")
	Holder.Name = Board.Name
	Holder.Size = Board.Size
	Holder.CFrame = Board.CFrame
	local Canvas = if Target then Target:Clone() else Newcanvas()
	if Canvas.Adornee == Board then
		Canvas.Adornee = Holder
	end
	Canvas.Parent = Holder
	local Copy = Frame:Clone()
	assert(Copy, "Prepare scratches: " .. Frame:GetFullName() .. " must be Archivable")
	Copy.Position = Position
	Copy.Size = Size
	Copy.Rotation = Rotation
	Copy.Parent = Canvas
	local Moved = Worldcorners(Stainlayout.GetLayout(Copy:FindFirstChild("Texture") :: ImageLabel))
	Holder:Destroy()
	local Normal = Board.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Backnormal))
	local Worst = 0
	for Index, Corner in ipairs(Corners) do
		local Offset = Moved[Index] - Corner
		Worst = math.max(Worst, (Offset - Normal * Offset:Dot(Normal)).Magnitude)
	end
	assert(
		Worst <= Cornertolerance,
		string.format(
			"Prepare scratches: %s would move by %.4f stud on %s.Ui%s, its Texture must fill its frame (Position 0.5, 0.5, Size 1, 1, AnchorPoint 0.5, 0.5, Rotation 0, no Offset): fix it and run this again",
			Frame:GetFullName(),
			Worst,
			Board.Name,
			Backface
		)
	)
	return {
		Photo = Photo,
		Prepared = false,
		Plate = Plate,
		Old = Old,
		Frame = Frame,
		Board = Board,
		Target = Target,
		Position = Position,
		Size = Size,
		Rotation = Rotation,
		Worst = Worst,
	}
end

local Actions, Leftovers = Planleftovers()
local Plan = Planphoto()
local Created = {}
local Removedframes, Removedsurfaces = 0, 0
local Recorded, Recording = false, nil
if Leftovers > 0 or not Plan.Prepared then
	Recorded, Recording = pcall(Changehistoryservice.TryBeginRecording, Changehistoryservice, "PrepareScratches", "Prepare scratches")
end
local Success, Failure = pcall(function()
	for _, Action in ipairs(Actions) do
		local Frame = Action.Frame
		if not Frame then
			print(Action.Key .. ": no template named " .. Action.Key .. " in ReplicatedStorage.Asset.Object, skipped")
		elseif Frame:IsDescendantOf(Action.Template) then
			local Surface = Frame.Parent :: Instance
			print(Action.Key .. ": removed " .. Pathin(Action.Template, Frame))
			Frame.Parent = nil
			Removedframes += 1
			if Surface:IsA("SurfaceGui") and Surfacenames[Surface.Name] and #Surface:GetChildren() == 0 then
				print(Action.Key .. ": removed " .. Pathin(Action.Template, Surface) .. ", left empty")
				Surface.Parent = nil
				Removedsurfaces += 1
			end
		end
	end
	if Plan.Prepared then
		print(Tutorialkey .. ": already prepared (no Cube.002, tutorial ScratchesFrame on " .. Plan.Path .. "), nothing changed")
		return
	end
	local Canvas = Plan.Target
	if not Canvas then
		Canvas = Newcanvas()
		Canvas.Parent = Plan.Board
		table.insert(Created, Canvas)
	end
	local From = Pathin(Plan.Photo, Plan.Old)
	Plan.Frame.Parent = Canvas
	Plan.Frame.Position = Plan.Position
	Plan.Frame.Size = Plan.Size
	Plan.Frame.Rotation = Plan.Rotation
	print(string.format("%s: tutorial ScratchesFrame moved from %s to %s, same place within %.6f stud", Tutorialkey, From, Pathin(Plan.Photo, Canvas), Plan.Worst))
	local Left = {}
	for _, Descendant in ipairs(Plan.Plate:GetDescendants()) do
		if Descendant:IsA("GuiObject") and Descendant.Parent:IsA("SurfaceGui") then
			table.insert(Left, Pathin(Plan.Plate, Descendant))
		end
	end
	print(Tutorialkey .. ": removed Cube.002" .. (if #Left > 0 then " with " .. table.concat(Left, ", ") else ""))
	Plan.Plate.Parent = nil
end)
if Recorded and Recording then
	Changehistoryservice:FinishRecording(Recording, Enum.FinishRecordingOperation.Commit)
end
if not Success then
	error(Failure, 0)
end
Selection:Set(Created)
print(
	string.format(
		"Prepare scratches: %d leftover ScratchesFrames and %d emptied SurfaceGuis removed, %s",
		Removedframes,
		Removedsurfaces,
		if Plan.Prepared
			then Tutorialkey .. " already prepared"
			else Tutorialkey .. " prepared: now run tools/RandomInks.luau, then lay the " .. Tutorialkey .. " Sticker over its new Ink"
	)
)
