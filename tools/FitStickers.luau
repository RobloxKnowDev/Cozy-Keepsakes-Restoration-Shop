local Inkimage = "rbxassetid://95412805630635"
local Inkaspect = 1.6
local Minimumwidth = 0.25
local Smallestwidth = 0.2
local Facecap = 0.7
local Rotationrange = 20
local Rotationstep = 5
local Minimumreachable = 0.95
local Minimumcells = 4
local Shrink = 0.85
local Shrinks = 5
local Pixelsperstud = 50
local Grid = 32
local Levels = 6
local Edge = 1e-6
local Margin = 0.5 / Grid
local Stainnames = { Ink = true, ScratchesFrame = true }
local Imageaspect = 1.5
local Cover = 1.1
local Thickness = 0.0064
local Clearance = 0.002
local Rise = 0.05
local Columns = 9
local Rows = 7
local Papercolor = Color3.fromRGB(250, 246, 235)
local Liftlimit = 0.03
local Sinklimit = 0.005
local Flatlimit = 0.02
local Widthstep = 0.92
local Probecolumns = 49
local Proberows = 37
local Verifylimit = 8
local Tilesize = 0.04
local Mintilecolumns = 4
local Mintilerows = 3
local Maxtiles = 20
local Maxtotal = 240
local Sagtarget = 0.0015
local Refinements = 3
local Tileoverlap = 0.15
local Steepest = 0.26
local Referencesize = 0.002
local Smoothing = 30
local Boxtolerance = 0.01
local Castsperframe = 2000
local Footu = Cover / 2
local Footv = Cover * Inkaspect / (2 * Imageaspect)
local Meshnote = " (some meshes did not load, so their collision shapes were used: check this one)"

local Replicatedstorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Changehistoryservice = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
assert(game:GetService("RunService"):IsEdit(), "Fit stickers: run this in Edit mode, not during Play")
local Shared = Replicatedstorage.Shared
local Objectconfig = require(Shared.Config.Object)
local Cleaningconfig = require(Shared.Config.Cleaning)
local Facemapping = require(Shared.Utils.FaceMapping)
local Stainlayout = require(Shared.Utils.StainLayout)
local Surfacecast = require(Shared.Utils.SurfaceCast)
local Getobjectrotation = require(Shared.Utils.ObjectRotation)
local Templates = Replicatedstorage.Asset.Object
local Casts = 0

local function Cast(Caster, Origin: Vector3, Vector: Vector3)
	Casts += 1
	if Casts % Castsperframe == 0 then
		task.wait()
	end
	return Caster:Cast(Origin, Vector)
end

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

local function Cellsunder(Layout: Stainlayout.Layout, Lowu: number, Highu: number, Lowv: number, Highv: number): { number }
	local Cells = {}
	local Minimum, Maximum = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
	for _, Corner in ipairs({ Vector2.new(Lowu, Lowv), Vector2.new(Highu, Lowv), Vector2.new(Lowu, Highv), Vector2.new(Highu, Highv) }) do
		local Point = Stainlayout.GetFacePoint(Layout, Corner)
		Minimum = Minimum:Min(Point)
		Maximum = Maximum:Max(Point)
	end
	for Row = math.max(math.floor(Minimum.Y * Grid), 0), math.min(math.ceil(Maximum.Y * Grid), Grid) - 1 do
		for Column = math.max(math.floor(Minimum.X * Grid), 0), math.min(math.ceil(Maximum.X * Grid), Grid) - 1 do
			local Cornerlowu, Cornerlowv, Cornerhighu, Cornerhighv = math.huge, math.huge, -math.huge, -math.huge
			for Corner = 0, 3 do
				local Point = Stainlayout.GetTexturePoint(Layout, Vector2.new((Column + Corner % 2) / Grid, (Row + Corner // 2) / Grid))
				Cornerlowu, Cornerhighu = math.min(Cornerlowu, Point.X), math.max(Cornerhighu, Point.X)
				Cornerlowv, Cornerhighv = math.min(Cornerlowv, Point.Y), math.max(Cornerhighv, Point.Y)
			end
			if Cornerlowu < Highu - Edge and Cornerhighu > Lowu + Edge and Cornerlowv < Highv - Edge and Cornerhighv > Lowv + Edge then
				table.insert(Cells, Row * Grid + Column + 1)
			end
		end
	end
	return Cells
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

local function Coverage(Texture: ImageLabel, Slot): (number, number, boolean, number)
	local Layout = Stainlayout.GetLayout(Texture)
	for _, Corner in ipairs({ Vector2.zero, Vector2.xAxis, Vector2.yAxis, Vector2.one }) do
		local Point = Stainlayout.GetFacePoint(Layout, Corner)
		if Point.X < Margin or Point.X > 1 - Margin or Point.Y < Margin or Point.Y > 1 - Margin then
			return 0, 0, false, math.huge
		end
	end
	local Nearest, Farthest = math.huge, -math.huge
	for _, Cell in ipairs(Coveredcells(Layout)) do
		if Slot.Forbidden[Cell] then
			return 0, 0, false, math.huge
		end
		local Column, Row = (Cell - 1) % Grid, (Cell - 1) // Grid
		for Nearrow = math.max(Row - 1, 0), math.min(Row + 1, Grid - 1) do
			for Nearcolumn = math.max(Column - 1, 0), math.min(Column + 1, Grid - 1) do
				local Depth = Slot.Depth[Nearrow * Grid + Nearcolumn + 1]
				Nearest = math.min(Nearest, Depth)
				Farthest = math.max(Farthest, Depth)
			end
		end
	end
	local Required, Reachable = 0, 0
	for Row = 0, Grid - 1 do
		for Column = 0, Grid - 1 do
			if Stainlayout.Contains(Layout, Vector2.new((Column + 0.5) / Grid, (Row + 0.5) / Grid)) then
				Required += 1
				if Slot.Reach[Row * Grid + Column + 1] then
					Reachable += 1
				end
			end
		end
	end
	return Required, Reachable, math.max(Layout.Axisu.Magnitude, Layout.Axisv.Magnitude) <= 2, math.max(Farthest - Nearest, 0)
end

local function Probe(Caster, Cframe: CFrame, Size: Vector3, Distance: number, Part: BasePart?, Decal: Decal?)
	local Normal = Cframe.LookVector
	local Result = { Lift = -math.huge, Sink = -math.huge, Low = math.huge, High = -math.huge, Missed = 0, Foreign = 0, Count = Probecolumns * Proberows }
	for Row = 0, Proberows - 1 do
		for Column = 0, Probecolumns - 1 do
			local Point = Cframe:PointToWorldSpace(Vector3.new((Column / (Probecolumns - 1) - 0.5) * Size.X, (Row / (Proberows - 1) - 0.5) * Size.Y, Size.Z / 2))
			local Hit = Cast(Caster, Point + Normal * Distance, -Normal * (Distance * 2))
			if not Hit then
				Result.Missed += 1
				continue
			end
			local Gap = (Point - Hit.Position):Dot(Normal)
			Result.Lift = math.max(Result.Lift, Gap)
			Result.Sink = math.max(Result.Sink, -Gap)
			Result.Low = math.min(Result.Low, -Gap)
			Result.High = math.max(Result.High, -Gap)
			if Part and not (Hit.Instance == Part and Facemapping.ShowsDecal(Decal :: Decal, Hit.DecalNormal)) then
				Result.Foreign += 1
			end
		end
	end
	return Result
end

local function Describe(Measure): string
	local Parts = {}
	if Measure.Lift > -math.huge then
		table.insert(Parts, string.format("lifted by up to %.3f stud", Measure.Lift))
	end
	if Measure.Sink > Sinklimit then
		table.insert(Parts, string.format("sank %.3f stud into the surface", Measure.Sink))
	end
	if Measure.Missed > 0 then
		table.insert(Parts, string.format("had no surface under %d of its %d points", Measure.Missed, Measure.Count))
	end
	return table.concat(Parts, ", ")
end

local function Worldcorners(Layout: Stainlayout.Layout, Part: BasePart): { Vector3 }
	local Corners = {}
	for _, Corner in ipairs({ Vector2.zero, Vector2.xAxis, Vector2.yAxis, Vector2.one }) do
		local Point = Stainlayout.GetFacePoint(Layout, Corner)
		table.insert(Corners, Part.CFrame:PointToWorldSpace(Facemapping.GetDecalLocalPoint(Part.Size, Layout.Facename, Point.X, Point.Y)))
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

local function Stickerframe(Template: Instance, Key: string, Layout: Stainlayout.Layout, Part: BasePart)
	local Corners = Worldcorners(Layout, Part)
	local Normal = Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Layout.Face))
	local Across = Corners[2] - Corners[1]
	local Right = Across.Unit
	local Down = Corners[3] - Corners[1]
	local Downflat = Down - Right * Down:Dot(Right)
	local Below = Downflat.Unit
	local Inkwidth, Inkheight = Across.Magnitude, Downflat.Magnitude
	local Width = Cover * math.max(Inkwidth, Inkheight * Imageaspect)
	if (-Below):Dot(Wantedup(Template :: PVInstance, Key, Normal)) < 0 then
		Right, Below = -Right, -Below
	end
	return {
		Centre = (Corners[1] + Corners[4]) / 2,
		Normal = Normal,
		Right = Right,
		Below = Below,
		Inkwidth = Inkwidth,
		Inkheight = Inkheight,
		Width = Width,
		Height = Width / Imageaspect,
	}
end

local function Highest(Caster, Centre: Vector3, Normal: Vector3, Right: Vector3, Below: Vector3, Width: number, Height: number, Distance: number): number?
	local Top = nil
	for Row = 0, Rows - 1 do
		for Column = 0, Columns - 1 do
			local Point = Centre + Right * ((Column / (Columns - 1) - 0.5) * Width) + Below * ((Row / (Rows - 1) - 0.5) * Height)
			local Hit = Cast(Caster, Point + Normal * Distance, -Normal * (Distance * 2))
			if Hit then
				local Depth = (Hit.Position - Centre):Dot(Normal)
				Top = if Top then math.max(Top, Depth) else Depth
			end
		end
	end
	return Top
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

local function Placeflat(Frame, Image: string, Caster, Distance: number, Floor: number): Part
	local Underink = Highest(Caster, Frame.Centre, Frame.Normal, Frame.Right, Frame.Below, Frame.Inkwidth, Frame.Inkheight, Distance)
	local Understicker = Highest(Caster, Frame.Centre, Frame.Normal, Frame.Right, Frame.Below, Frame.Width, Frame.Height, Distance)
	assert(Underink, "no surface found under the new Ink")
	local Depth = if Understicker and Understicker - Underink > Rise then Underink else math.max(Underink, Understicker or Underink)
	local Dense = Probe(Caster, CFrame.fromMatrix(Frame.Centre, -Frame.Right, -Frame.Below), Vector3.new(Frame.Width, Frame.Height, 0), Distance)
	Depth = math.max(Depth, Dense.High, Floor)
	local Position = Frame.Centre + Frame.Normal * (Depth + Clearance + Thickness / 2)
	return Buildsticker(Image, CFrame.fromMatrix(Position, -Frame.Right, -Frame.Below), Frame.Width, Frame.Height)
end

local function Resolveslot(Caster, Decal: Decal, Distance: number, Forbidden: { [number]: boolean })
	local Part = Decal.Parent :: BasePart
	local Facename = Decal.Face.Name
	local Normal = Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Decal.Face))
	local Length = Distance + Part.Size.Magnitude
	local Reach = table.create(Grid * Grid, false)
	local Depth = table.create(Grid * Grid, Distance - Length)
	local Cells = 0
	for Row = 0, Grid - 1 do
		for Column = 0, Grid - 1 do
			local Point = Part.CFrame:PointToWorldSpace(Facemapping.GetDecalLocalPoint(Part.Size, Facename, (Column + 0.5) / Grid, (Row + 0.5) / Grid))
			local Hit = Cast(Caster, Point + Normal * Distance, -Normal * Length)
			if Hit then
				Depth[Row * Grid + Column + 1] = (Hit.Position - Point):Dot(Normal)
			end
			if Hit and Hit.Instance == Part and Facemapping.ShowsDecal(Decal, Hit.DecalNormal) then
				Reach[Row * Grid + Column + 1] = true
				if not Forbidden[Row * Grid + Column + 1] then
					Cells += 1
				end
			end
		end
	end
	local Stride = Grid + 1
	local Badsum = table.create(Stride * Stride, 0)
	local Lowtable = table.create(Grid * Levels * Grid, 0)
	local Hightable = table.create(Grid * Levels * Grid, 0)
	for Row = 0, Grid - 1 do
		for Column = 0, Grid - 1 do
			local Index = Row * Grid + Column + 1
			Badsum[(Row + 1) * Stride + Column + 2] = Badsum[Row * Stride + Column + 2] + Badsum[(Row + 1) * Stride + Column + 1] - Badsum[Row * Stride + Column + 1] + (if Reach[Index] then 0 else 1)
			Lowtable[Row * Levels * Grid + Column + 1] = Depth[Index]
			Hightable[Row * Levels * Grid + Column + 1] = Depth[Index]
		end
		for Level = 1, Levels - 1 do
			local Span = 2 ^ (Level - 1)
			for Column = 0, Grid - 2 * Span do
				local Target = (Row * Levels + Level) * Grid + Column + 1
				local Source = (Row * Levels + Level - 1) * Grid + Column + 1
				Lowtable[Target] = math.min(Lowtable[Source], Lowtable[Source + Span])
				Hightable[Target] = math.max(Hightable[Source], Hightable[Source + Span])
			end
		end
	end
	local Existing = Part:FindFirstChild("Ui" .. Facename)
	local Extent = Guiextent(Part.Size, Facename)
	return {
		Decal = Decal,
		Part = Part,
		Facename = Facename,
		Normal = Normal,
		Reach = Reach,
		Depth = Depth,
		Forbidden = Forbidden,
		Cells = Cells,
		Badsum = Badsum,
		Lowtable = Lowtable,
		Hightable = Hightable,
		Turned = Facename == "Top" or Facename == "Bottom",
		Fixed = Existing ~= nil and (Existing :: SurfaceGui).SizingMode ~= Enum.SurfaceGuiSizingMode.PixelsPerStud,
		Extent = Extent,
		Decalsize = Facemapping.GetDecalSize(Part.Size, Facename),
		Cap = math.min(Facecap * Extent.X, Facecap * Extent.Y * Inkaspect),
	}
end

local function Footprint(Slot, Width: number, Rotation: number)
	local Angle = math.rad(Rotation)
	local Ux, Uy, Vx, Vy = math.cos(Angle), math.sin(Angle), -math.sin(Angle), math.cos(Angle)
	if Slot.Turned then
		Ux, Uy, Vx, Vy = -Uy, Ux, -Vy, Vx
	end
	local Halfwidth = Cover * Width / 2
	local Halfheight = Cover * Width / Imageaspect / 2
	local Du, Dv = Slot.Decalsize.X, Slot.Decalsize.Y
	local Reachu = Halfwidth * math.abs(Ux) + Halfheight * math.abs(Vx)
	local Reachv = Halfwidth * math.abs(Uy) + Halfheight * math.abs(Vy)
	local Offsets = {}
	for Row = -math.ceil(Reachv * Grid / Dv), math.ceil(Reachv * Grid / Dv) do
		for Column = -math.ceil(Reachu * Grid / Du), math.ceil(Reachu * Grid / Du) do
			local X, Y = Column * Du / Grid, Row * Dv / Grid
			local Alongu, Alongv = X * Ux + Y * Uy, X * Vx + Y * Vy
			if math.abs(Alongu) <= Halfwidth + 1e-9 and math.abs(Alongv) <= Halfheight + 1e-9 then
				table.insert(Offsets, { Column, Row, X * X + Y * Y })
			end
		end
	end
	table.sort(Offsets, function(First, Second)
		return First[3] > Second[3]
	end)
	return Offsets, Reachu / Du + Margin, Reachv / Dv + Margin, math.floor(Reachu * Grid / Du + 1e-9), math.floor(Reachv * Grid / Dv + 1e-9)
end

local function Boxrange(Slot, Lowrow: number, Highrow: number, Lowcolumn: number, Highcolumn: number): (number, number, number)
	local Stride = Grid + 1
	local Badsum = Slot.Badsum
	local Bad = Badsum[(Highrow + 1) * Stride + Highcolumn + 2] - Badsum[Lowrow * Stride + Highcolumn + 2] - Badsum[(Highrow + 1) * Stride + Lowcolumn + 1] + Badsum[Lowrow * Stride + Lowcolumn + 1]
	if Bad > 0 then
		return Bad, 0, 0
	end
	local Level = math.floor(math.log(Highcolumn - Lowcolumn + 1, 2) + 1e-9)
	local Span = 2 ^ Level
	local Lowtable, Hightable = Slot.Lowtable, Slot.Hightable
	local Low, High = math.huge, -math.huge
	for Row = Lowrow, Highrow do
		local First = (Row * Levels + Level) * Grid + Lowcolumn + 1
		local Second = (Row * Levels + Level) * Grid + Highcolumn - Span + 2
		Low = math.min(Low, Lowtable[First], Lowtable[Second])
		High = math.max(High, Hightable[First], Hightable[Second])
	end
	return 0, Low, High
end

local function Survivors(Slot, Width: number, Rotation: number, List, Oldcentre: Vector3, Oldrotation: number)
	local Offsets, Spanu, Spanv, Boxcolumns, Boxrows = Footprint(Slot, Width, Rotation)
	local Reach, Depths = Slot.Reach, Slot.Depth
	for Row = math.max(math.ceil(Spanv * Grid - 0.5 - 1e-9), Boxrows), math.min(math.floor((1 - Spanv) * Grid - 0.5 + 1e-9), Grid - 1 - Boxrows) do
		for Column = math.max(math.ceil(Spanu * Grid - 0.5 - 1e-9), Boxcolumns), math.min(math.floor((1 - Spanu) * Grid - 0.5 + 1e-9), Grid - 1 - Boxcolumns) do
			local Bad, Low, High = Boxrange(Slot, Row - Boxrows, Row + Boxrows, Column - Boxcolumns, Column + Boxcolumns)
			local Flat = Bad == 0 and High - Low <= Flatlimit
			if not Flat then
				Low, High = math.huge, -math.huge
				Flat = true
				for _, Offset in ipairs(Offsets) do
					local Index = (Row + Offset[2]) * Grid + Column + Offset[1] + 1
					if not Reach[Index] then
						Flat = false
						break
					end
					local Depth = Depths[Index]
					Low, High = math.min(Low, Depth), math.max(High, Depth)
					if High - Low > Flatlimit then
						Flat = false
						break
					end
				end
			end
			if Flat then
				local World = Slot.Part.CFrame:PointToWorldSpace(Facemapping.GetDecalLocalPoint(Slot.Part.Size, Slot.Facename, (Column + 0.5) / Grid, (Row + 0.5) / Grid))
				table.insert(List, {
					Slot = Slot,
					Width = Width,
					Rotation = Rotation,
					Column = Column,
					Row = Row,
					Spread = math.floor((High - Low) * 1000 + 0.5),
					Away = math.floor((World - Oldcentre).Magnitude * 10000 + 0.5),
					Turn = math.floor(math.abs(Rotation - Oldrotation) * 100 + 0.5),
					Order = #List + 1,
				})
			end
		end
	end
end

local function Verify(Template: Instance, Key: string, Candidate, Holder: Part, Caster, Distance: number)
	local Slot = Candidate.Slot
	local U, V = (Candidate.Column + 0.5) / Grid, (Candidate.Row + 0.5) / Grid
	local Centre = if Slot.Turned then Vector2.new(V, 1 - U) else Vector2.new(U, V)
	local _, Existing = Usablesurface(Slot.Part, Slot.Facename)
	local Copy = if Existing then Existing:Clone() else nil
	if Copy and Copy.Adornee == Slot.Part then
		Copy.Adornee = Holder
	end
	Holder.Name = Slot.Part.Name
	Holder.Size = Slot.Part.Size
	local Surface, Frame, Texture = Buildink(Holder, Slot.Facename, Copy, Centre, Candidate.Width, Candidate.Width / Inkaspect, Candidate.Rotation)
	local Required, Reachable, Fits = Coverage(Texture, Slot)
	local Layout = Stainlayout.GetLayout(Texture)
	local Free = true
	if Fits and Required >= Minimumcells and Reachable >= Required * Minimumreachable then
		for _, Cell in ipairs(Cellsunder(Layout, 0.5 - Footu, 0.5 + Footu, 0.5 - Footv, 0.5 + Footv)) do
			if Slot.Forbidden[Cell] then
				Free = false
				break
			end
		end
	end
	for _, Corner in ipairs({ Vector2.new(0.5 - Footu, 0.5 - Footv), Vector2.new(0.5 + Footu, 0.5 - Footv), Vector2.new(0.5 - Footu, 0.5 + Footv), Vector2.new(0.5 + Footu, 0.5 + Footv) }) do
		local Point = Stainlayout.GetFacePoint(Layout, Corner)
		if Point.X < Margin or Point.X > 1 - Margin or Point.Y < Margin or Point.Y > 1 - Margin then
			Free = false
		end
	end
	local Rotation = Frame.Rotation
	local Valid = Free and Fits and Required >= Minimumcells and Reachable >= Required * Minimumreachable
	local Result = nil
	if Valid then
		local Sticker = Stickerframe(Template, Key, Layout, Slot.Part)
		local Dense = Probe(Caster, CFrame.fromMatrix(Sticker.Centre, -Sticker.Right, -Sticker.Below), Vector3.new(Sticker.Width, Sticker.Height, 0), Distance, Slot.Part, Slot.Decal)
		local Gridlow, Gridhigh = math.huge, -math.huge
		for _, Offset in ipairs((Footprint(Slot, Candidate.Width, Candidate.Rotation))) do
			local Depth = Slot.Depth[(Candidate.Row + Offset[2]) * Grid + Candidate.Column + Offset[1] + 1]
			Gridlow, Gridhigh = math.min(Gridlow, Depth), math.max(Gridhigh, Depth)
		end
		local Low, High = math.min(Dense.Low, Gridlow), math.max(Dense.High, Gridhigh)
		if Dense.Missed == 0 and Dense.Foreign == 0 and High - Low <= Flatlimit then
			Result = {
				Slot = Slot,
				Centre = Centre,
				Width = Candidate.Width,
				Rotation = Rotation,
				Share = Reachable / Required,
				Spread = High - Low,
				Floor = High,
				Frame = Sticker,
			}
		end
	end
	Surface:Destroy()
	return Result
end

local function Findflat(Template: Instance, Key: string, Clone: Instance, Copies: { Instance }, Twin: { [Instance]: Instance }, Caster, Distance: number, Extents: Vector3, Oldink: GuiObject)
	local Pivot = (Template :: PVInstance):GetPivot()
	local Slots = {}
	local Seen = {}
	for _, Decal in ipairs(Copies) do
		if Decal:IsA("Decal") and Cleaningconfig.DirtDecals[Decal.Name] and Decal.Parent and Decal.Parent:IsA("BasePart") then
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
				if Slot.Cells > 0 then
					table.insert(Slots, Slot)
				end
			end
		end
	end
	local Oldlayout = Stainlayout.GetLayout(Oldink:FindFirstChild("Texture") :: ImageLabel)
	local Oldcorners = Worldcorners(Oldlayout, Oldlayout.Part)
	local Oldcentre = (Oldcorners[1] + Oldcorners[4]) / 2
	local Oldwidth = (Oldcorners[2] - Oldcorners[1]).Magnitude
	local Oldrotation = Oldink.Rotation
	local Floor = Minimumwidth * Shrink ^ Shrinks * Extents.Magnitude / 2
	local Lowest, Top = math.huge, 0
	for _, Slot in ipairs(Slots) do
		Slot.Lowest = math.max(Smallestwidth, math.min(Floor, Slot.Cap))
		Slot.Top = math.min(Slot.Cap, math.max(Oldwidth, Slot.Lowest))
		if Slot.Top >= Slot.Lowest then
			Lowest = math.min(Lowest, Slot.Lowest)
			Top = math.max(Top, Slot.Top)
		end
	end
	local Rotations = { Oldrotation }
	for Rotation = -Rotationrange, Rotationrange, Rotationstep do
		if math.abs(Rotation - Oldrotation) > 0.5 then
			table.insert(Rotations, Rotation)
		end
	end
	local Holder = Instance.new("Part")
	local Chosen = nil
	local Band = 0
	while not Chosen and Top * Widthstep ^ Band >= Lowest * Widthstep do
		local Width = Top * Widthstep ^ Band
		local Next = Width * Widthstep
		local List = {}
		for _, Slot in ipairs(Slots) do
			local Slotwidth = math.min(Width, Slot.Top)
			if Slotwidth >= Slot.Lowest and Slotwidth > Next then
				for _, Rotation in ipairs(if Slot.Fixed then { 0 } else Rotations) do
					Survivors(Slot, Slotwidth, Rotation, List, Oldcentre, Oldrotation)
				end
			end
		end
		table.sort(List, function(First, Second)
			if First.Spread ~= Second.Spread then
				return First.Spread < Second.Spread
			end
			if First.Away ~= Second.Away then
				return First.Away < Second.Away
			end
			if First.Turn ~= Second.Turn then
				return First.Turn < Second.Turn
			end
			return First.Order < Second.Order
		end)
		local Failed = 0
		for _, Candidate in ipairs(List) do
			Chosen = Verify(Template, Key, Candidate, Holder, Caster, Distance)
			if Chosen then
				break
			end
			Failed += 1
			if Failed >= Verifylimit then
				break
			end
		end
		Band += 1
	end
	Holder:Destroy()
	return Chosen, Lowest
end

local function Rotate(Vector: Vector3, Axis: Vector3, Cosine: number, Sine: number): Vector3
	return Vector * Cosine + Axis:Cross(Vector) * Sine + Axis * (Axis:Dot(Vector) * (1 - Cosine))
end

local function Buildcurve(Old: BasePart, Image: string, Caster, Distance: number)
	local Frame = Old.CFrame
	local Width, Height = Old.Size.X, Old.Size.Y
	local Normal, Across, Up, Origin = Frame.LookVector, Frame.RightVector, Frame.UpVector, Frame.Position
	local Startsize = math.max(Tilesize, math.sqrt(Width * Height * 2 / Maxtotal))
	local Tilecolumns = math.clamp(math.ceil(Width / Startsize), Mintilecolumns, Maxtiles)
	local Tilerows = math.clamp(math.ceil(Height / Startsize), Mintilerows, Maxtiles)
	local Samplecolumns, Samplerows, Surface
	for Pass = 1, Refinements do
		Samplecolumns, Samplerows = Tilecolumns * 2, Tilerows * 2
		Surface = {}
		local Depths = {}
		for Row = 0, Samplerows do
			for Column = 0, Samplecolumns do
				local X, Y = (Column / Samplecolumns - 0.5) * Width, (Row / Samplerows - 0.5) * Height
				local Hit = Cast(Caster, Origin + Across * X + Up * Y + Normal * Distance, -Normal * (Distance * 2))
				if not Hit then
					return nil, "part of the sticker has no surface under it"
				end
				Surface[Row * (Samplecolumns + 1) + Column + 1] = Hit.Position
				Depths[Row * (Samplecolumns + 1) + Column + 1] = (Hit.Position - Origin):Dot(Normal)
			end
		end
		local Bendx, Bendy, Bendboth = 0, 0, 0
		local Stride = Samplecolumns + 1
		for Row = 0, Samplerows do
			for Column = 0, Samplecolumns do
				local Index = Row * Stride + Column + 1
				if Column > 0 and Column < Samplecolumns then
					Bendx = math.max(Bendx, math.abs(Depths[Index - 1] - 2 * Depths[Index] + Depths[Index + 1]))
				end
				if Row > 0 and Row < Samplerows then
					Bendy = math.max(Bendy, math.abs(Depths[Index - Stride] - 2 * Depths[Index] + Depths[Index + Stride]))
				end
				if Column > 0 and Column < Samplecolumns and Row > 0 and Row < Samplerows then
					Bendboth = math.max(
						Bendboth,
						math.abs(Depths[Index - Stride - 1] - 2 * Depths[Index] + Depths[Index + Stride + 1]),
						math.abs(Depths[Index - Stride + 1] - 2 * Depths[Index] + Depths[Index + Stride - 1])
					)
				end
			end
		end
		local Both = math.sqrt(math.max(Bendboth / 2 / Sagtarget, 1))
		local Needcolumns = math.clamp(math.ceil(Tilecolumns * math.max(math.sqrt(Bendx / 2 / Sagtarget), Both)), Tilecolumns, Maxtiles)
		local Needrows = math.clamp(math.ceil(Tilerows * math.max(math.sqrt(Bendy / 2 / Sagtarget), Both)), Tilerows, Maxtiles)
		while Needcolumns * Needrows > Maxtotal do
			if Needcolumns > Tilecolumns and (Needcolumns >= Needrows or Needrows == Tilerows) then
				Needcolumns -= 1
			elseif Needrows > Tilerows then
				Needrows -= 1
			else
				break
			end
		end
		if Pass == Refinements or Needcolumns == Tilecolumns and Needrows == Tilerows then
			break
		end
		Tilecolumns, Tilerows = Needcolumns, Needrows
	end
	local function Sample(Column: number, Row: number): Vector3
		return Surface[Row * (Samplecolumns + 1) + Column + 1]
	end
	local Cellwidth, Cellheight = Width / Tilecolumns, Height / Tilerows
	local Tiles: { BasePart } = {}
	local Gap = 0
	local Referencepoint = Origin
	for Tilerow = 0, Tilerows - 1 do
		for Tilecolumn = 0, Tilecolumns - 1 do
			local Middlecolumn, Middlerow = Tilecolumn * 2 + 1, Tilerow * 2 + 1
			local Centrex, Centrey = (Middlecolumn / Samplecolumns - 0.5) * Width, (Middlerow / Samplerows - 0.5) * Height
			local Sumx, Sumy, Sumxx, Sumyy, Sumd = 0, 0, 0, 0, 0
			for Row = Middlerow - 1, Middlerow + 1 do
				for Column = Middlecolumn - 1, Middlecolumn + 1 do
					local X, Y = (Column - Middlecolumn) * Cellwidth / 2, (Row - Middlerow) * Cellheight / 2
					local Depth = (Sample(Column, Row) - Origin):Dot(Normal)
					Sumx += X * Depth
					Sumy += Y * Depth
					Sumxx += X * X
					Sumyy += Y * Y
					Sumd += Depth
				end
			end
			local Slopex, Slopey = Sumx / Sumxx, Sumy / Sumyy
			local Tilenormal = (Normal - Across * Slopex - Up * Slopey).Unit
			local Dot = Tilenormal:Dot(Normal)
			if Dot < Steepest then
				return nil, "the surface under the sticker is too steep"
			end
			local Axis = Normal:Cross(Tilenormal)
			local Sine = Axis.Magnitude
			local Tileright, Tileup = Across, Up
			if Sine > 1e-9 then
				Tileright = Rotate(Across, Axis / Sine, Dot, Sine)
				Tileup = Rotate(Up, Axis / Sine, Dot, Sine)
			end
			local Anchor = Sample(Middlecolumn, Middlerow)
			local Seat = -math.huge
			for Row = math.max(Middlerow - 2, 0), math.min(Middlerow + 2, Samplerows) do
				for Column = math.max(Middlecolumn - 2, 0), math.min(Middlecolumn + 2, Samplecolumns) do
					Seat = math.max(Seat, (Sample(Column, Row) - Anchor):Dot(Tilenormal))
				end
			end
			local Middle = Anchor + Normal * ((Clearance + Thickness / 2 + Seat) / Dot)
			local Lowx = Centrex - Cellwidth / 2 - (if Tilecolumn > 0 then Tileoverlap * Cellwidth else 0)
			local Highx = Centrex + Cellwidth / 2 + (if Tilecolumn < Tilecolumns - 1 then Tileoverlap * Cellwidth else 0)
			local Lowy = Centrey - Cellheight / 2 - (if Tilerow > 0 then Tileoverlap * Cellheight else 0)
			local Highy = Centrey + Cellheight / 2 + (if Tilerow < Tilerows - 1 then Tileoverlap * Cellheight else 0)
			local function Lift(X: number, Y: number): Vector3
				local Base = Origin + Across * X + Up * Y
				return Base + Normal * ((Middle - Base):Dot(Tilenormal) / Dot)
			end
			local Centre = Lift((Lowx + Highx) / 2, (Lowy + Highy) / 2)
			if Tilecolumn == Tilecolumns // 2 and Tilerow == Tilerows // 2 then
				Referencepoint = Lift(0, 0)
			end
			local Halfx, Halfy = 0, 0
			for _, Corner in ipairs({ Lift(Lowx, Lowy), Lift(Highx, Lowy), Lift(Lowx, Highy), Lift(Highx, Highy) }) do
				Halfx = math.max(Halfx, math.abs((Corner - Centre):Dot(Tileright)))
				Halfy = math.max(Halfy, math.abs((Corner - Centre):Dot(Tileup)))
			end
			for Row = Middlerow - 1, Middlerow + 1 do
				for Column = Middlecolumn - 1, Middlecolumn + 1 do
					Gap = math.max(Gap, (Centre - Sample(Column, Row)):Dot(Tilenormal) - Thickness / 2)
				end
			end
			local Tile = Instance.new("Part")
			Tile.Name = "Tile"
			Tile.Size = Vector3.new(Halfx * 2, Halfy * 2, Thickness)
			Tile.CFrame = CFrame.fromMatrix(Centre, Tileright, Tileup)
			Tile.Anchored = true
			Tile.CanCollide = false
			Tile.CanTouch = false
			Tile.CastShadow = false
			Tile.Material = Enum.Material.SmoothPlastic
			Tile.Color = Papercolor
			table.insert(Tiles, Tile)
		end
	end
	local Low, High = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, Tile in ipairs(Tiles) do
		local Half = Tile.Size / 2
		for Corner = 0, 7 do
			local Point = Frame:PointToObjectSpace(Tile.CFrame:PointToWorldSpace(Half * Vector3.new(Corner % 2 * 2 - 1, Corner // 2 % 2 * 2 - 1, Corner // 4 * 2 - 1)))
			Low, High = Low:Min(Point), High:Max(Point)
		end
	end
	local Expected = Frame:PointToWorldSpace((Low + High) / 2)
	local Size = High - Low
	local Reference = Instance.new("Part")
	Reference.Name = "Reference"
	Reference.Size = Vector3.one * Referencesize
	Reference.CFrame = CFrame.fromMatrix(Referencepoint, Across, Up)
	Reference.Anchored = true
	Reference.CanCollide = false
	Reference.CanTouch = false
	Reference.CastShadow = false
	Reference.Material = Enum.Material.SmoothPlastic
	Reference.Color = Papercolor
	local Holder = Instance.new("Model")
	Holder.Name = "FitStickersTiles"
	for _, Tile in ipairs(Tiles) do
		Tile.Parent = Holder
	end
	Reference.Parent = Holder
	Holder.Parent = Workspace
	local Success, Union = pcall(Reference.UnionAsync, Reference, Tiles, Enum.CollisionFidelity.Hull, Enum.RenderFidelity.Precise)
	local Failure = if Success then "" else tostring(Union)
	if not Success then
		local Done, Results = pcall(function()
			return game:GetService("GeometryService"):UnionAsync(Reference, Tiles, {
				CollisionFidelity = Enum.CollisionFidelity.Hull,
				RenderFidelity = Enum.RenderFidelity.Precise,
				SplitApart = false,
			})
		end)
		Success = Done and typeof(Results) == "table" and #Results == 1
		Union = if Success then Results[1] else nil
		Failure ..= if Done then "; GeometryService:UnionAsync returned " .. (if typeof(Results) == "table" then #Results else 0) .. " parts" else "; GeometryService:UnionAsync failed too (" .. tostring(Results) .. ")"
	end
	Holder.Parent = nil
	if not Success then
		return nil, "BasePart:UnionAsync failed (" .. Failure .. ")"
	end
	if not (typeof(Union) == "Instance" and Union:IsA("PartOperation")) then
		return nil, "UnionAsync returned no union"
	end
	local Made = Union :: PartOperation
	local Turned = Made.CFrame.RightVector:Dot(Across) < 0.9999 or Made.CFrame.UpVector:Dot(Up) < 0.9999 or Made.CFrame.LookVector:Dot(Normal) < 0.9999
	local Difference = (Made.Size - Size):Abs()
	local Offset = Frame:VectorToObjectSpace(Made.Position - Expected)
	if Turned or math.abs(Offset.X) > Boxtolerance or math.abs(Offset.Y) > Boxtolerance or math.abs(Offset.Z) > Size.Z / 2 + Boxtolerance or math.max(Difference.X, Difference.Y, Difference.Z) > Boxtolerance then
		return nil, string.format("the union came out at another place or angle (%.3f x %.3f x %.3f stud from the tiles' box, size %.3f x %.3f x %.3f instead of %.3f x %.3f x %.3f)", Offset.X, Offset.Y, Offset.Z, Made.Size.X, Made.Size.Y, Made.Size.Z, Size.X, Size.Y, Size.Z)
	end
	Made.Name = "Sticker"
	Made:SetAttribute("RandomSticker", true)
	Made:SetAttribute("CurvedSticker", true)
	Made.Anchored = true
	Made.CanCollide = false
	Made.CanTouch = false
	Made.CastShadow = false
	Made.Material = Enum.Material.SmoothPlastic
	Made.Color = Papercolor
	Made.UsePartColor = true
	Made.SmoothingAngle = Smoothing
	local Decal = Instance.new("Decal")
	Decal.Name = "Image"
	Decal.Face = Enum.NormalId.Front
	Decal.Texture = Image
	Decal.Parent = Made
	return { Union = Made, Tiles = #Tiles, Gap = Gap }, ""
end

local function Fitclone(Key: string, Template: Instance, Old: BasePart, Image: string, Oldink: GuiObject, Clone: Instance, Copies: { Instance }, Twin: { [Instance]: Instance }, Caster)
	local Loaded = Caster:Load()
	local Note = if Loaded then "" else Meshnote
	local Extents = if Clone:IsA("Model") then Clone:GetExtentsSize() else (Clone :: BasePart).Size
	local Distance = Extents.Magnitude + 1
	local Before = Probe(Caster, Old.CFrame, Old.Size, Distance)
	if Before.Missed == 0 and Before.Lift <= Liftlimit and Before.Sink <= Sinklimit then
		return string.format("the sticker lies flat (gap at most %.3f stud), nothing changed%s", Before.Lift, Note), {}, "flat"
	end
	local Problem = Describe(Before)
	local Chosen, Lowest = Findflat(Template, Key, Clone, Copies, Twin, Caster, Distance, Extents, Oldink)
	if Chosen then
		local Part = Twin[Chosen.Slot.Part] :: BasePart
		assert(
			Part and Part.ClassName == Chosen.Slot.Part.ClassName and Part.Name == Chosen.Slot.Part.Name and Part.Size == Chosen.Slot.Part.Size,
			"the working copy of " .. Chosen.Slot.Part.Name .. " does not match the template, nothing changed"
		)
		local Sticker = Placeflat(Chosen.Frame, Image, Caster, Distance, Chosen.Floor)
		local After = Probe(Caster, Sticker.CFrame, Sticker.Size, Distance)
		Removeinks({ Oldink })
		local _, Existing = Usablesurface(Part, Chosen.Slot.Facename)
		local _, Frame = Buildink(Part, Chosen.Slot.Facename, Existing, Chosen.Centre, Chosen.Width, Chosen.Width / Inkaspect, Chosen.Rotation)
		Old.Parent = nil
		Sticker.Parent = Template
		return string.format(
			"the sticker %s; Ink and sticker moved to a flat spot: Ink on %s, face %s, %.2f x %.2f studs, rotation %.0f, %d %% reachable; sticker %.2f x %.2f studs, gap now at most %.3f stud%s",
			Problem,
			Part:GetFullName(),
			Chosen.Slot.Facename,
			Chosen.Width,
			Chosen.Width / Inkaspect,
			Frame.Rotation,
			math.floor(Chosen.Share * 100 + 0.5),
			Sticker.Size.X,
			Sticker.Size.Y,
			After.Lift,
			Note
		),
			{ Sticker, Frame },
			"moved"
	end
	local Floortext = if Lowest < math.huge then string.format("no flat spot fits an Ink of %.2f stud or more", Lowest) else "no dirt face can take an Ink"
	local Curved, Failure = Buildcurve(Old, Image, Caster, Distance)
	if not Curved then
		return string.format("the sticker %s, %s, and %s: the flat sticker is kept, check it%s", Problem, Floortext, Failure, Note), {}, "kept"
	end
	local Layout = Stainlayout.GetLayout(Oldink:FindFirstChild("Texture") :: ImageLabel)
	Old.Parent = nil
	Curved.Union.Parent = Template
	return string.format(
		"the sticker %s and %s; curved sticker of %d tiles over the Ink on %s, face %s, %.2f x %.2f studs, gap now at most %.3f stud%s",
		Problem,
		Floortext,
		Curved.Tiles,
		Layout.Part:GetFullName(),
		Layout.Facename,
		Old.Size.X,
		Old.Size.Y,
		Curved.Gap,
		Note
	),
		{ Curved.Union },
		"curved"
end

local function Fitsticker(Key: string): (string, { Instance }, string)
	local Template = Templates:FindFirstChild(Key)
	if not Template then
		return "no template named " .. Key .. " in ReplicatedStorage.Asset.Object, skipped", {}, "skipped"
	end
	local Old = Template:FindFirstChild("Sticker")
	if not Old or Old:GetAttribute("RandomSticker") ~= true then
		return "no Sticker made by tools/PlaceStickers.luau, nothing changed", {}, "skipped"
	end
	if Old:GetAttribute("CurvedSticker") == true then
		return "already has a curved sticker from this script, nothing changed", {}, "skipped"
	end
	assert(Old:IsA("BasePart"), Old:GetFullName() .. " must be a Part")
	local Image = Old:FindFirstChild("Image")
	assert(Image and Image:IsA("Decal"), Old:GetFullName() .. " has no Decal named Image")
	local Oldinks = Findinks(Template)
	if #Oldinks ~= 1 then
		return string.format("has %d Inks instead of 1, nothing changed", #Oldinks), {}, "skipped"
	end
	local Originals = Withroot(Template)
	local Clone = Template:Clone()
	assert(Clone, Template:GetFullName() .. " must be Archivable")
	local Copies = Withroot(Clone)
	if #Copies ~= #Originals then
		return "has non-Archivable instances, skipped", {}, "skipped"
	end
	local Twin = {}
	for Index, Copy in ipairs(Copies) do
		Twin[Copy] = Originals[Index]
	end
	Clone:FindFirstChild("Sticker"):Destroy()
	Removeinks(Findinks(Clone))
	Clone.Parent = Workspace
	local Caster = Surfacecast.new(Clone)
	local Success, Message, Created, Kind = pcall(Fitclone, Key, Template, Old, Image.Texture, Oldinks[1], Clone, Copies, Twin, Caster)
	Caster:Destroy()
	Clone.Parent = nil
	if not Success then
		error(Message, 0)
	end
	return Message, Created, Kind
end

local Keys = {}
for Key, Entry in pairs(Objectconfig.Object) do
	if Entry.Sticker then
		table.insert(Keys, Key)
	end
end
table.sort(Keys)
local Recorded, Recording = pcall(Changehistoryservice.TryBeginRecording, Changehistoryservice, "FitStickers", "Fit stickers")
local Created = {}
local Counts = { flat = 0, moved = 0, curved = 0, kept = 0, skipped = 0, failed = 0 }
for _, Key in ipairs(Keys) do
	local Success, Message, Made, Kind = pcall(Fitsticker, Key)
	if not Success then
		Counts.failed += 1
		warn(Key .. ": error, " .. tostring(Message))
	else
		Counts[Kind] += 1
		for _, Item in ipairs(Made) do
			table.insert(Created, Item)
		end
		print(Key .. ": " .. Message)
	end
end
if Recorded and Recording then
	Changehistoryservice:FinishRecording(Recording, Enum.FinishRecordingOperation.Commit)
end
Selection:Set(Created)
print(string.format("Fit stickers: %d already flat, %d moved to a flat spot, %d curved, %d kept flat, %d skipped, %d errors, %d casts", Counts.flat, Counts.moved, Counts.curved, Counts.kept, Counts.skipped, Counts.failed, Casts))