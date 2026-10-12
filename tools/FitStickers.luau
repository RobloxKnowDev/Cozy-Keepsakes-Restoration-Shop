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
local Columns = 9
local Rows = 7
local Papercolor = Color3.fromRGB(250, 246, 235)
local Liftlimit = 0.03
local Sinklimit = 0.005
local Flatlimit = 0.01
local Nearlimit = 0.02
local Goodcurve = Flatlimit + Clearance
local Clearlyworse = 0.003
local Widthstep = 0.92
local Probecolumns = 49
local Proberows = 37
local Neighbourhood = 2
local Finer = 2
local Verifylimit = 8
local Trylimit = 48
local Curvetries = 4
local Curvelimit = 12
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
local Piercestep = 0.0015
local Planelimit = 0.01
local Flatmesh = 1e-4
local Footu = Cover / 2
local Footv = Cover * Inkaspect / (2 * Imageaspect)
local Meshnote = " (some meshes did not load, so their collision shapes were used: check this one)"
local Advice = "delete this object's Ink and Sticker, then run tools/RandomInks.luau, tools/PlaceStickers.luau and tools/FitStickers.luau again, or model a part shaped like the surface to carry the sticker"

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

local function Reach(Index: number, Count: number): number
	return math.min(Neighbourhood, Index, Count - 1 - Index)
end

local function Closed(Heights: { number }): { number }
	local Count = Probecolumns * Proberows
	local Highest = table.create(Count, -math.huge)
	for Row = 0, Proberows - 1 do
		local Along = Reach(Row, Proberows)
		for Column = 0, Probecolumns - 1 do
			local Across = Reach(Column, Probecolumns)
			local Top = -math.huge
			for Near = Row - Along, Row + Along do
				for Side = Column - Across, Column + Across do
					Top = math.max(Top, Heights[Near * Probecolumns + Side + 1])
				end
			end
			Highest[Row * Probecolumns + Column + 1] = Top
		end
	end
	local Result = table.create(Count, math.huge)
	for Row = 0, Proberows - 1 do
		for Column = 0, Probecolumns - 1 do
			local Least = math.huge
			for Near = math.max(Row - Neighbourhood, 0), math.min(Row + Neighbourhood, Proberows - 1) do
				if math.abs(Near - Row) <= Reach(Near, Proberows) then
					for Side = math.max(Column - Neighbourhood, 0), math.min(Column + Neighbourhood, Probecolumns - 1) do
						if math.abs(Side - Column) <= Reach(Side, Probecolumns) and Reach(Near, Proberows) + Reach(Side, Probecolumns) > 0 then
							Least = math.min(Least, Highest[Near * Probecolumns + Side + 1])
						end
					end
				end
			end
			Result[Row * Probecolumns + Column + 1] = Least
		end
	end
	return Result
end

local function Offcentre(Index: number): number
	local Column, Row = (Index - 1) % Probecolumns, (Index - 1) // Probecolumns
	return math.abs(Column / (Probecolumns - 1) - 0.5) + math.abs(Row / (Proberows - 1) - 0.5)
end

local function Probe(Caster, Cframe: CFrame, Size: Vector3, Distance: number, Part: BasePart?, Decal: Decal?)
	local Normal = Cframe.LookVector
	local Count = Probecolumns * Proberows
	local Result = { Lift = -math.huge, Sink = -math.huge, High = -math.huge, Mean = 0, Missed = 0, Empty = 0, Foreign = 0, Count = Count, Pierced = false }
	local Heights = table.create(Count, -math.huge)
	local Points = table.create(Count)
	local Hits = 0
	for Row = 0, Proberows - 1 do
		for Column = 0, Probecolumns - 1 do
			local Index = Row * Probecolumns + Column + 1
			local Point = Cframe:PointToWorldSpace(Vector3.new((Column / (Probecolumns - 1) - 0.5) * Size.X, (Row / (Proberows - 1) - 0.5) * Size.Y, Size.Z / 2))
			Points[Index] = Point
			local Hit = Cast(Caster, Point + Normal * Distance, -Normal * (Distance * 2))
			if not Hit then
				Result.Missed += 1
				Result.Obstacle = Result.Obstacle or Point
				continue
			end
			local Height = (Hit.Position - Point):Dot(Normal)
			Heights[Index] = Height
			Hits += 1
			Result.Mean += Height
			Result.Sink = math.max(Result.Sink, Height)
			if Height > Result.High then
				Result.High, Result.Highpoint = Height, Hit.Position
			end
			if Part and not (Hit.Instance == Part and Facemapping.ShowsDecal(Decal :: Decal, Hit.DecalNormal)) then
				Result.Foreign += 1
				Result.Obstacle = Result.Obstacle or Hit.Position
			end
		end
	end
	local Nearest = math.huge
	for Index, Height in ipairs(Closed(Heights)) do
		if Height == -math.huge then
			Result.Empty += 1
		elseif -Height > Result.Lift + Edge or -Height >= Result.Lift - Edge and Offcentre(Index) < Nearest then
			Result.Lift = math.max(Result.Lift, -Height)
			Result.Lowpoint, Nearest = Points[Index] + Normal * Height, Offcentre(Index)
		end
	end
	Result.Low = -Result.Lift
	Result.Mean /= math.max(Hits, 1)
	return Result
end

local function Pierced(Caster, Cframe: CFrame, Width: number, Height: number): Vector3?
	for _, Pass in ipairs({ { Vector3.xAxis, Width, Vector3.yAxis, Height }, { Vector3.yAxis, Height, Vector3.xAxis, Width } }) do
		local Along, Length, Side, Span = Pass[1], Pass[2], Pass[3], Pass[4]
		local Lines = math.ceil(Span / Piercestep)
		for Line = 0, Lines do
			local Offset = Side * ((Line / Lines - 0.5) * Span)
			for _, Sign in ipairs({ -1, 1 }) do
				local Start = Cframe:PointToWorldSpace(Offset - Along * (Sign * Length / 2))
				local Hit = Cast(Caster, Start, Cframe:VectorToWorldSpace(Along * (Sign * Length)))
				if Hit then
					return Hit.Position
				end
			end
		end
	end
	return nil
end

local function Describe(Measure): string
	local Parts = {}
	if Measure.Lift > -math.huge then
		table.insert(Parts, string.format("lifted by up to %.3f stud", Measure.Lift))
	end
	if Measure.Sink > Sinklimit then
		table.insert(Parts, string.format("sank %.3f stud into the surface", Measure.Sink))
	end
	if Measure.Empty > 0 then
		table.insert(Parts, string.format("had no surface under %d of its %d points", Measure.Empty, Measure.Count))
	end
	if Measure.Pierced then
		table.insert(Parts, "had something poking through it")
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

local function Highest(Caster, Centre: Vector3, Normal: Vector3, Right: Vector3, Below: Vector3, Width: number, Height: number, Distance: number): (number?, Vector3?)
	local Top, Toppoint = nil, nil
	for Row = 0, Rows - 1 do
		for Column = 0, Columns - 1 do
			local Point = Centre + Right * ((Column / (Columns - 1) - 0.5) * Width) + Below * ((Row / (Rows - 1) - 0.5) * Height)
			local Hit = Cast(Caster, Point + Normal * Distance, -Normal * (Distance * 2))
			if Hit then
				local Depth = (Hit.Position - Centre):Dot(Normal)
				if not Top or Depth > Top then
					Top, Toppoint = Depth, Hit.Position
				end
			end
		end
	end
	return Top, Toppoint
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

local function Seatflat(Frame, Caster, Distance: number, Floor: number): (CFrame, number, Vector3?)
	local Depth, Peak = Floor, nil
	for _, Extent in ipairs({ Vector2.new(Frame.Inkwidth, Frame.Inkheight), Vector2.new(Frame.Width, Frame.Height) }) do
		local Top, Point = Highest(Caster, Frame.Centre, Frame.Normal, Frame.Right, Frame.Below, Extent.X, Extent.Y, Distance)
		if Top and Top > Depth then
			Depth, Peak = Top, Point
		end
	end
	return CFrame.fromMatrix(Frame.Centre + Frame.Normal * (Depth + Clearance + Thickness / 2), -Frame.Right, -Frame.Below), Depth, Peak
end

local function Boxspan(Cframe: CFrame, Half: Vector3, Point: Vector3, Direction: Vector3): number?
	local Origin = Cframe:PointToObjectSpace(Point)
	local Vector = Cframe:VectorToObjectSpace(Direction)
	local Low, High = -math.huge, math.huge
	for _, Axis in ipairs({ "X", "Y", "Z" }) do
		local Start, Speed, Extent = Origin[Axis], Vector[Axis], Half[Axis]
		if math.abs(Speed) < 1e-9 then
			if math.abs(Start) > Extent then
				return nil
			end
		else
			local First, Second = (-Extent - Start) / Speed, (Extent - Start) / Speed
			Low, High = math.max(Low, math.min(First, Second)), math.min(High, math.max(First, Second))
		end
	end
	return if Low <= High then High else nil
end

local function Planegap(Layout: Stainlayout.Layout, Boxes): number
	local Part = Layout.Part
	local Normal = Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Layout.Face))
	local Worst = 0
	for Row = 0, 2 do
		for Column = 0, 4 do
			local Facepoint = Stainlayout.GetFacePoint(Layout, Vector2.new(Column / 4, Row / 2))
			local Point = Part.CFrame:PointToWorldSpace(Facemapping.GetDecalLocalPoint(Part.Size, Layout.Facename, Facepoint.X, Facepoint.Y))
			local Outer = nil
			for _, Box in ipairs(Boxes) do
				local Far = Boxspan(Box.Cframe, Box.Size / 2, Point, Normal)
				if Far and (not Outer or Far > Outer) then
					Outer = Far
				end
			end
			if Outer then
				Worst = math.max(Worst, -Outer)
			end
		end
	end
	return Worst
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
			Badsum[(Row + 1) * Stride + Column + 2] = Badsum[Row * Stride + Column + 2] + Badsum[(Row + 1) * Stride + Column + 1] - Badsum[Row * Stride + Column + 1] + (if Reach[Index] and not Forbidden[Index] then 0 else 1)
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

local function Survivors(Slot, Width: number, Rotation: number, List, Oldcentre: Vector3, Oldrotation: number, Limit: number)
	local Offsets, Spanu, Spanv, Boxcolumns, Boxrows = Footprint(Slot, Width, Rotation)
	local Reach, Depths, Forbidden = Slot.Reach, Slot.Depth, Slot.Forbidden
	for Row = math.max(math.ceil(Spanv * Grid - 0.5 - 1e-9), Boxrows), math.min(math.floor((1 - Spanv) * Grid - 0.5 + 1e-9), Grid - 1 - Boxrows) do
		for Column = math.max(math.ceil(Spanu * Grid - 0.5 - 1e-9), Boxcolumns), math.min(math.floor((1 - Spanu) * Grid - 0.5 + 1e-9), Grid - 1 - Boxcolumns) do
			local Bad, Low, High = Boxrange(Slot, Row - Boxrows, Row + Boxrows, Column - Boxcolumns, Column + Boxcolumns)
			local Flat = Bad == 0 and High - Low <= Limit
			if not Flat then
				Low, High = math.huge, -math.huge
				Flat = true
				for _, Offset in ipairs(Offsets) do
					local Index = (Row + Offset[2]) * Grid + Column + Offset[1] + 1
					if not Reach[Index] or Forbidden[Index] then
						Flat = false
						break
					end
					local Depth = Depths[Index]
					Low, High = math.min(Low, Depth), math.max(High, Depth)
					if High - Low > Limit then
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

local function Placeink(Search, Candidate, Holder: Part)
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
	local Placed = nil
	if Free and Fits and Required >= Minimumcells and Reachable >= Required * Minimumreachable then
		Placed = {
			Slot = Slot,
			Centre = Centre,
			Width = Candidate.Width,
			Rotation = Frame.Rotation,
			Share = Reachable / Required,
			Frame = Stickerframe(Search.Template, Search.Key, Layout, Slot.Part),
		}
	end
	Surface:Destroy()
	return Placed
end

local function Verifyflat(Search, Candidate, Placed, Limit: number)
	local Slot = Candidate.Slot
	local Sticker = Placed.Frame
	local Dense = Probe(Search.Caster, CFrame.fromMatrix(Sticker.Centre, -Sticker.Right, -Sticker.Below), Vector3.new(Sticker.Width, Sticker.Height, 0), Search.Distance, Slot.Part, Slot.Decal)
	if Dense.Missed > 0 or Dense.Foreign > 0 then
		return nil, Dense.Obstacle
	end
	local Gridlow, Gridhigh = math.huge, -math.huge
	for _, Offset in ipairs((Footprint(Slot, Candidate.Width, Candidate.Rotation))) do
		local Depth = Slot.Depth[(Candidate.Row + Offset[2]) * Grid + Candidate.Column + Offset[1] + 1]
		Gridlow, Gridhigh = math.min(Gridlow, Depth), math.max(Gridhigh, Depth)
	end
	local Low, High = math.min(Dense.Low, Gridlow), math.max(Dense.High, Gridhigh)
	if High - Low > Limit then
		if Dense.High - Dense.Low <= Limit then
			return nil, nil
		end
		return nil, if Dense.High - Dense.Mean > Dense.Mean - Dense.Low then Dense.Highpoint else Dense.Lowpoint
	end
	local Seat, Depth, Peak = Seatflat(Sticker, Search.Caster, Search.Distance, High)
	if Depth - Low > Limit then
		return nil, Peak
	end
	local Obstacle = Pierced(Search.Caster, Seat, Sticker.Width, Sticker.Height)
	if Obstacle then
		return nil, Obstacle
	end
	Placed.Gap = Depth + Clearance - Dense.Low
	Placed.Seat = Seat
	return Placed, nil
end

local function Covers(Candidate, Point: Vector3): boolean
	local Slot = Candidate.Slot
	local Facepoint = Facemapping.GetDecalPoint(Slot.Part, Point, Slot.Facename)
	local X = (Facepoint.X - (Candidate.Column + 0.5) / Grid) * Slot.Decalsize.X
	local Y = (Facepoint.Y - (Candidate.Row + 0.5) / Grid) * Slot.Decalsize.Y
	local Angle = math.rad(Candidate.Rotation)
	local Ux, Uy, Vx, Vy = math.cos(Angle), math.sin(Angle), -math.sin(Angle), math.cos(Angle)
	if Slot.Turned then
		Ux, Uy, Vx, Vy = -Uy, Ux, -Vy, Vx
	end
	return math.abs(X * Ux + Y * Uy) <= Cover * Candidate.Width / 2 and math.abs(X * Vx + Y * Vy) <= Cover * Candidate.Width / Imageaspect / 2
end

local function Blocked(Obstacles, Candidate): boolean
	for _, Point in ipairs(Obstacles[Candidate.Slot] or {}) do
		if Covers(Candidate, Point) then
			return true
		end
	end
	return false
end

local function Remember(Obstacles, Candidate, Point: Vector3)
	Obstacles[Candidate.Slot] = Obstacles[Candidate.Slot] or {}
	table.insert(Obstacles[Candidate.Slot], Point)
end

local function Newsearch(Template: Instance, Key: string, Clone: Instance, Copies: { Instance }, Twin: { [Instance]: Instance }, Caster, Distance: number, Extents: Vector3, Oldink: GuiObject)
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
	local Widths = {}
	local Bandwidth = Top
	while Bandwidth > Lowest do
		table.insert(Widths, Bandwidth)
		Bandwidth *= Widthstep
	end
	for _, Slot in ipairs(Slots) do
		if Slot.Top >= Slot.Lowest and not table.find(Widths, Slot.Lowest) then
			table.insert(Widths, Slot.Lowest)
		end
	end
	table.sort(Widths, function(First, Second)
		return First > Second
	end)
	return {
		Template = Template,
		Key = Key,
		Twin = Twin,
		Caster = Caster,
		Distance = Distance,
		Slots = Slots,
		Widths = Widths,
		Rotations = Rotations,
		Oldcentre = (Oldcorners[1] + Oldcorners[4]) / 2,
		Oldrotation = Oldrotation,
		Lowest = Lowest,
	}
end

local function Candidates(Search, Band: number, Limit: number)
	local Width = Search.Widths[Band]
	local Next = Search.Widths[Band + 1] or 0
	local List = {}
	for _, Slot in ipairs(Search.Slots) do
		local Slotwidth = math.min(Width, Slot.Top)
		if Slotwidth >= Slot.Lowest and Slotwidth > Next then
			for _, Rotation in ipairs(if Slot.Fixed then { 0 } else Search.Rotations) do
				Survivors(Slot, Slotwidth, Rotation, List, Search.Oldcentre, Search.Oldrotation, Limit)
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
	return List
end

local function Findflat(Search, Limit: number)
	local Holder = Instance.new("Part")
	local Chosen = nil
	local Obstacles = {}
	for Band = 1, #Search.Widths do
		local Failed, Tried = 0, 0
		for _, Candidate in ipairs(Candidates(Search, Band, Limit)) do
			if not Blocked(Obstacles, Candidate) then
				local Placed = Placeink(Search, Candidate, Holder)
				local Result, Obstacle = nil, nil
				if Placed then
					Result, Obstacle = Verifyflat(Search, Candidate, Placed, Limit)
				end
				if Result then
					Chosen = Result
					break
				end
				Tried += 1
				if Obstacle then
					Remember(Obstacles, Candidate, Obstacle)
				else
					Failed += 1
				end
				if Failed >= Verifylimit or Tried >= Trylimit then
					break
				end
			end
		end
		if Chosen then
			break
		end
	end
	Holder:Destroy()
	return Chosen
end

local function Rotate(Vector: Vector3, Axis: Vector3, Cosine: number, Sine: number): Vector3
	return Vector * Cosine + Axis:Cross(Vector) * Sine + Axis * (Axis:Dot(Vector) * (1 - Cosine))
end

local function Buildtiles(Frame: CFrame, Width: number, Height: number, Caster, Distance: number)
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
				local Point = Origin + Across * ((Column / Samplecolumns - 0.5) * Width) + Up * ((Row / Samplerows - 0.5) * Height)
				local Hit = Cast(Caster, Point + Normal * Distance, -Normal * (Distance * 2))
				if not Hit then
					return nil, "part of the sticker has no surface under it", Point
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
	local Heights = table.create(Probecolumns * Proberows, -math.huge)
	local Hits = {}
	for Row = 0, Proberows - 1 do
		for Column = 0, Probecolumns - 1 do
			local Point = Origin + Across * ((Column / (Probecolumns - 1) - 0.5) * Width) + Up * ((Row / (Proberows - 1) - 0.5) * Height)
			local Hit = Cast(Caster, Point + Normal * Distance, -Normal * (Distance * 2))
			if Hit then
				Heights[Row * Probecolumns + Column + 1] = (Hit.Position - Point):Dot(Normal)
				Hits[Row * Probecolumns + Column + 1] = Hit.Position
			end
		end
	end
	local Cellwidth, Cellheight = Width / Tilecolumns, Height / Tilerows
	local Tiles = {}
	local Shown = 0
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
				return nil, string.format("the surface under the sticker is too steep (it turns more than %d degrees, the sticker would wrap around an edge)", math.round(math.deg(math.acos(Steepest)))), Sample(Middlecolumn, Middlerow)
			end
			if Dot >= math.max(math.abs(Tilenormal:Dot(Across)), math.abs(Tilenormal:Dot(Up))) then
				Shown += 1
			end
			local Axis = Normal:Cross(Tilenormal)
			local Sine = Axis.Magnitude
			local Tileright, Tileup = Across, Up
			if Sine > 1e-9 then
				Tileright = Rotate(Across, Axis / Sine, Dot, Sine)
				Tileup = Rotate(Up, Axis / Sine, Dot, Sine)
			end
			local Lowx = Centrex - Cellwidth / 2 - (if Tilecolumn > 0 then Tileoverlap * Cellwidth else 0)
			local Highx = Centrex + Cellwidth / 2 + (if Tilecolumn < Tilecolumns - 1 then Tileoverlap * Cellwidth else 0)
			local Lowy = Centrey - Cellheight / 2 - (if Tilerow > 0 then Tileoverlap * Cellheight else 0)
			local Highy = Centrey + Cellheight / 2 + (if Tilerow < Tilerows - 1 then Tileoverlap * Cellheight else 0)
			local Anchor = Sample(Middlecolumn, Middlerow)
			local Seat = -math.huge
			for Row = math.max(Middlerow - 2, 0), math.min(Middlerow + 2, Samplerows) do
				for Column = math.max(Middlecolumn - 2, 0), math.min(Middlecolumn + 2, Samplecolumns) do
					Seat = math.max(Seat, (Sample(Column, Row) - Anchor):Dot(Tilenormal))
				end
			end
			for Row = math.max(math.ceil((Lowy / Height + 0.5) * (Proberows - 1) - 1e-9), 0), math.min(math.floor((Highy / Height + 0.5) * (Proberows - 1) + 1e-9), Proberows - 1) do
				for Column = math.max(math.ceil((Lowx / Width + 0.5) * (Probecolumns - 1) - 1e-9), 0), math.min(math.floor((Highx / Width + 0.5) * (Probecolumns - 1) + 1e-9), Probecolumns - 1) do
					local Point = Hits[Row * Probecolumns + Column + 1]
					if Point then
						Seat = math.max(Seat, (Point - Anchor):Dot(Tilenormal) - Clearance)
					end
				end
			end
			local Middle = Anchor + Normal * ((Clearance + Thickness / 2 + Seat) / Dot)
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
			local Tileframe = CFrame.fromMatrix(Centre, Tileright, Tileup)
			local Tilebox = Vector3.new(Halfx * 2, Halfy * 2, Thickness)
			local Hit = Pierced(Caster, Tileframe, Tilebox.X, Tilebox.Y)
			if Hit then
				return nil, "something pokes through the curved sticker", Hit
			end
			table.insert(Tiles, { Cframe = Tileframe, Size = Tilebox, Centre = Centre, Normal = Tilenormal })
		end
	end
	local Floors = Closed(Heights)
	for Index, Floor in ipairs(Floors) do
		if Floor == -math.huge then
			return nil, "part of the sticker has no surface under it", Origin + Across * (((Index - 1) % Probecolumns / (Probecolumns - 1) - 0.5) * Width) + Up * (((Index - 1) // Probecolumns / (Proberows - 1) - 0.5) * Height)
		end
	end
	local Gap = -math.huge
	for Row = 0, (Proberows - 1) * Finer do
		local Lowrow = math.min(Row // Finer, Proberows - 2)
		local Fraction = Row / Finer - Lowrow
		for Column = 0, (Probecolumns - 1) * Finer do
			local Lowcolumn = math.min(Column // Finer, Probecolumns - 2)
			local Part = Column / Finer - Lowcolumn
			local First = Lowrow * Probecolumns + Lowcolumn + 1
			local Floor = (Floors[First] * (1 - Part) + Floors[First + 1] * Part) * (1 - Fraction) + (Floors[First + Probecolumns] * (1 - Part) + Floors[First + Probecolumns + 1] * Part) * Fraction
			local X, Y = (Column / Finer / (Probecolumns - 1) - 0.5) * Width, (Row / Finer / (Proberows - 1) - 0.5) * Height
			local Point = Origin + Across * X + Up * Y
			local Least = math.huge
			local Tilecolumn = math.clamp(math.floor((X + Width / 2) / Cellwidth), 0, Tilecolumns - 1)
			local Tilerow = math.clamp(math.floor((Y + Height / 2) / Cellheight), 0, Tilerows - 1)
			for Near = math.max(Tilerow - 1, 0), math.min(Tilerow + 1, Tilerows - 1) do
				for Side = math.max(Tilecolumn - 1, 0), math.min(Tilecolumn + 1, Tilecolumns - 1) do
					local Tile = Tiles[Near * Tilecolumns + Side + 1]
					local Inner = Point + Normal * (((Tile.Centre - Point):Dot(Tile.Normal) - Thickness / 2) / Normal:Dot(Tile.Normal)) - Tile.Centre
					if math.abs(Inner:Dot(Tile.Cframe.RightVector)) <= Tile.Size.X / 2 + Edge and math.abs(Inner:Dot(Tile.Cframe.UpVector)) <= Tile.Size.Y / 2 + Edge then
						Least = math.min(Least, (Tile.Centre - Point - Normal * Floor):Dot(Tile.Normal) - Thickness / 2)
					end
				end
			end
			if Least < math.huge then
				Gap = math.max(Gap, Least)
			end
		end
	end
	local Low, High = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, Tile in ipairs(Tiles) do
		local Half = Tile.Size / 2
		for Corner = 0, 7 do
			local Point = Frame:PointToObjectSpace(Tile.Cframe:PointToWorldSpace(Half * Vector3.new(Corner % 2 * 2 - 1, Corner // 2 % 2 * 2 - 1, Corner // 4 * 2 - 1)))
			Low, High = Low:Min(Point), High:Max(Point)
		end
	end
	return {
		Frame = Frame,
		Width = Width,
		Height = Height,
		Tiles = Tiles,
		Gap = Gap,
		Shown = Shown / #Tiles,
		Referencepoint = Referencepoint,
		Expected = Frame:PointToWorldSpace((Low + High) / 2),
		Size = High - Low,
	},
		"",
		nil
end

local function Unionproblem(Union, Curve): string?
	if not (typeof(Union) == "Instance" and Union:IsA("PartOperation")) then
		return "returned no union"
	end
	local Made = Union :: PartOperation
	local Frame = Curve.Frame
	local Turned = Made.CFrame.RightVector:Dot(Frame.RightVector) < 0.9999 or Made.CFrame.UpVector:Dot(Frame.UpVector) < 0.9999 or Made.CFrame.LookVector:Dot(Frame.LookVector) < 0.9999
	local Difference = (Made.Size - Curve.Size):Abs()
	local Offset = Frame:VectorToObjectSpace(Made.Position - Curve.Expected)
	if Turned or math.abs(Offset.X) > Boxtolerance or math.abs(Offset.Y) > Boxtolerance or math.abs(Offset.Z) > Curve.Size.Z / 2 + Boxtolerance or math.max(Difference.X, Difference.Y, Difference.Z) > Boxtolerance then
		return string.format(
			"made a union that came out at another place or angle (%.3f x %.3f x %.3f stud from the tiles' box, size %.3f x %.3f x %.3f instead of %.3f x %.3f x %.3f)",
			Offset.X,
			Offset.Y,
			Offset.Z,
			Made.Size.X,
			Made.Size.Y,
			Made.Size.Z,
			Curve.Size.X,
			Curve.Size.Y,
			Curve.Size.Z
		)
	end
	return nil
end

local function Makeunion(Curve, Image: string): (PartOperation?, string)
	local Parts = {}
	for _, Tile in ipairs(Curve.Tiles) do
		local Tilepart = Instance.new("Part")
		Tilepart.Name = "Tile"
		Tilepart.Size = Tile.Size
		Tilepart.CFrame = Tile.Cframe
		Tilepart.Anchored = true
		Tilepart.CanCollide = false
		Tilepart.CanTouch = false
		Tilepart.CastShadow = false
		Tilepart.Material = Enum.Material.SmoothPlastic
		Tilepart.Color = Papercolor
		table.insert(Parts, Tilepart)
	end
	local Reference = Instance.new("Part")
	Reference.Name = "Reference"
	Reference.Size = Vector3.one * Referencesize
	Reference.CFrame = CFrame.fromMatrix(Curve.Referencepoint, Curve.Frame.RightVector, Curve.Frame.UpVector)
	Reference.Anchored = true
	Reference.CanCollide = false
	Reference.CanTouch = false
	Reference.CastShadow = false
	Reference.Material = Enum.Material.SmoothPlastic
	Reference.Color = Papercolor
	local Holder = Instance.new("Model")
	Holder.Name = "FitStickersTiles"
	for _, Tilepart in ipairs(Parts) do
		Tilepart.Parent = Holder
	end
	Reference.Parent = Holder
	Holder.Parent = Workspace
	local Success, Union = pcall(Reference.UnionAsync, Reference, Parts, Enum.CollisionFidelity.Hull, Enum.RenderFidelity.Precise)
	local Problem = if Success then Unionproblem(Union, Curve) else "failed (" .. tostring(Union) .. ")"
	local Note = ""
	if Problem then
		local Done, Results = pcall(function()
			return game:GetService("GeometryService"):UnionAsync(Reference, Parts, {
				CollisionFidelity = Enum.CollisionFidelity.Hull,
				RenderFidelity = Enum.RenderFidelity.Precise,
				SplitApart = false,
			})
		end)
		local Second = nil
		if not Done then
			Second = "failed too (" .. tostring(Results) .. ")"
		elseif typeof(Results) ~= "table" or #Results ~= 1 then
			Second = "returned " .. (if typeof(Results) == "table" then #Results else 0) .. " parts"
		else
			Second = Unionproblem(Results[1], Curve)
		end
		if Second then
			Holder.Parent = nil
			return nil, "BasePart:UnionAsync " .. Problem .. "; GeometryService:UnionAsync " .. Second
		end
		Union = Results[1]
		Note = " (made with GeometryService:UnionAsync because BasePart:UnionAsync " .. Problem .. ")"
	end
	Holder.Parent = nil
	local Made = Union :: PartOperation
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
	return Made, Note
end

local function Findcurve(Search)
	local Holder = Instance.new("Part")
	local Best = nil
	local Built = 0
	local Obstacles = {}
	for Band = 1, #Search.Widths do
		local Tried = 0
		for _, Candidate in ipairs(Candidates(Search, Band, math.huge)) do
			if Tried >= Curvetries or Built >= Curvelimit then
				break
			end
			if not Blocked(Obstacles, Candidate) then
				local Placed = Placeink(Search, Candidate, Holder)
				if Placed then
					local Frame = Placed.Frame
					local Curve, _, Point = Buildtiles(CFrame.fromMatrix(Frame.Centre, -Frame.Right, -Frame.Below), Frame.Width, Frame.Height, Search.Caster, Search.Distance)
					Tried += 1
					Built += 1
					if Curve and Curve.Gap <= Liftlimit and (not Best or Curve.Gap < Best.Curve.Gap) then
						Best = { Placed = Placed, Curve = Curve }
					elseif not Curve and Point then
						Remember(Obstacles, Candidate, Point)
					end
				end
			end
		end
		if Best and Best.Curve.Gap <= Goodcurve or Built >= Curvelimit then
			break
		end
	end
	Holder:Destroy()
	return Best
end

local function Inktext(Part: BasePart, Placed, Rotation: number): string
	return string.format(
		"Ink on %s, face %s, %.2f x %.2f studs, rotation %d, %d %% reachable",
		Part:GetFullName(),
		Placed.Slot.Facename,
		Placed.Width,
		Placed.Width / Inkaspect,
		math.round(Rotation),
		math.floor(Placed.Share * 100 + 0.5)
	)
end

local function Curvetext(Curve): string
	return string.format("curved sticker of %d tiles, %.2f x %.2f studs, image drawn on %d %% of it, gap now at most %.3f stud", #Curve.Tiles, Curve.Width, Curve.Height, math.floor(Curve.Shown * 100 + 0.5), Curve.Gap)
end

local function Joined(List: { string }): string
	if #List == 1 then
		return List[1]
	end
	return table.concat(List, ", ", 1, #List - 1) .. ", and " .. List[#List]
end

local function Twinpart(Search, Placed): BasePart
	local Part = Search.Twin[Placed.Slot.Part] :: BasePart
	assert(
		Part and Part.ClassName == Placed.Slot.Part.ClassName and Part.Name == Placed.Slot.Part.Name and Part.Size == Placed.Slot.Part.Size,
		"the working copy of " .. Placed.Slot.Part.Name .. " does not match the template, nothing changed"
	)
	return Part
end

local function Moveink(Search, Placed, Oldink: GuiObject): (BasePart, Frame, ImageLabel)
	local Part = Twinpart(Search, Placed)
	Removeinks({ Oldink })
	local _, Existing = Usablesurface(Part, Placed.Slot.Facename)
	local _, Frame, Texture = Buildink(Part, Placed.Slot.Facename, Existing, Placed.Centre, Placed.Width, Placed.Width / Inkaspect, Placed.Rotation)
	return Part, Frame, Texture
end

local function Moveflat(Search, Chosen, Old: BasePart, Oldink: GuiObject, Image: string): (string, { Instance }, number)
	Twinpart(Search, Chosen)
	local Sticker = Buildsticker(Image, Chosen.Seat, Chosen.Frame.Width, Chosen.Frame.Height)
	local After = Probe(Search.Caster, Sticker.CFrame, Sticker.Size, Search.Distance)
	local Part, Frame, Texture = Moveink(Search, Chosen, Oldink)
	Old.Parent = nil
	Sticker.Parent = Search.Template
	local Plane = Planegap(Stainlayout.GetLayout(Texture), { { Cframe = Sticker.CFrame, Size = Sticker.Size } })
	return string.format("%s; sticker %.2f x %.2f studs, gap now at most %.3f stud", Inktext(Part, Chosen, Frame.Rotation), Sticker.Size.X, Sticker.Size.Y, After.Lift), { Sticker, Frame }, Plane
end

local function Fitclone(Key: string, Template: Instance, Old: BasePart, Image: string, Oldink: GuiObject, Clone: Instance, Copies: { Instance }, Twin: { [Instance]: Instance }, Caster)
	local Loaded = Caster:Load()
	for _, Solid in ipairs(Caster.Solids) do
		if Solid:IsA("MeshPart") and math.min(Solid.MeshSize.X, Solid.MeshSize.Y, Solid.MeshSize.Z) > Flatmesh then
			Loaded = false
		end
	end
	local Note = if Loaded then "" else Meshnote
	local Extents = if Clone:IsA("Model") then Clone:GetExtentsSize() else (Clone :: BasePart).Size
	local Distance = Extents.Magnitude + 1
	local Before = Probe(Caster, Old.CFrame, Old.Size, Distance)
	Before.Pierced = Pierced(Caster, Old.CFrame, Old.Size.X, Old.Size.Y) ~= nil
	if Before.Empty == 0 and Before.Lift <= Liftlimit and Before.Sink <= Sinklimit and not Before.Pierced then
		return string.format("the sticker lies flat (gap at most %.3f stud), nothing changed%s", Before.Lift, Note), {}, "flat", 0
	end
	local Problem = Describe(Before)
	local Movable = Oldink:GetAttribute("RandomInk") == true
	local Search = nil
	local Flattext = ""
	if Movable then
		Search = Newsearch(Template, Key, Clone, Copies, Twin, Caster, Distance, Extents, Oldink)
		local Chosen = Findflat(Search, Flatlimit)
		if Chosen then
			local Text, Made, Plane = Moveflat(Search, Chosen, Old, Oldink, Image)
			return string.format("the sticker %s; Ink and sticker moved to a flat spot: %s%s", Problem, Text, Note), Made, "moved", Plane
		end
		Flattext = if Search.Lowest < math.huge then string.format("no flat spot (unevenness at most %.2f stud) fits an Ink of %.2f stud or more", Flatlimit, Search.Lowest) else "no dirt face can take an Ink"
	end
	local Layout = Stainlayout.GetLayout(Oldink:FindFirstChild("Texture") :: ImageLabel)
	local Curve, Failure = Buildtiles(Old.CFrame, Old.Size.X, Old.Size.Y, Caster, Distance)
	local Fits = Curve ~= nil and Curve.Gap <= Liftlimit
	local Sought = Movable and not (Fits and Curve.Gap <= Goodcurve)
	local Near = if Sought then Findflat(Search, Nearlimit) else nil
	if Fits and not (Near and Curve.Gap > Near.Gap + Clearlyworse) then
		local Made, Text = Makeunion(Curve, Image)
		if Made then
			Old.Parent = nil
			Made.Parent = Template
			return string.format(
				"the sticker %s%s; curved in place over the Ink on %s, face %s: %s%s%s%s",
				Problem,
				if Movable then " and " .. Flattext else " and its Ink was placed by hand (no RandomInk attribute), so it stays where it is",
				Layout.Part:GetFullName(),
				Layout.Facename,
				Curvetext(Curve),
				if Near then string.format(" (the best nearly flat spot would leave %.3f stud)", Near.Gap) else "",
				Text,
				Note
			),
				{ Made },
				"curved",
				Planegap(Layout, Curve.Tiles)
		end
		Curve, Failure = nil, Text
		if Movable and not Sought then
			Near = Findflat(Search, Nearlimit)
		end
	end
	local Standoff = if Curve then string.format("still stand up to %.3f stud off the surface", Curve.Gap) else nil
	if not Movable then
		return string.format("the sticker %s, but its Ink was placed by hand (no RandomInk attribute), so this script never moves it, and a curved sticker is not possible over it (%s): nothing changed, fix it by hand%s", Problem, if Standoff then "it would " .. Standoff else Failure, Note), {}, "skipped", 0
	end
	local Reasons = { "the sticker " .. Problem, Flattext, if Standoff then "a curved sticker over this Ink would " .. Standoff else "a curved sticker is not possible over this Ink (" .. Failure .. ")" }
	if Near then
		local Text, Made, Plane = Moveflat(Search, Near, Old, Oldink, Image)
		return string.format("%s; Ink and sticker moved to a nearly flat spot: %s%s", Joined(Reasons), Text, Note), Made, "nearly", Plane
	end
	if Search.Lowest < math.huge then
		table.insert(Reasons, string.format("no nearly flat spot (unevenness at most %.2f stud) fits one either", Nearlimit))
	end
	local Other = Findcurve(Search)
	if Other then
		local Made, Text = Makeunion(Other.Curve, Image)
		if Made then
			local Part, Frame, Texture = Moveink(Search, Other.Placed, Oldink)
			Old.Parent = nil
			Made.Parent = Template
			return string.format("%s; Ink moved and sticker curved: %s; %s%s%s", Joined(Reasons), Inktext(Part, Other.Placed, Frame.Rotation), Curvetext(Other.Curve), Text, Note),
				{ Made, Frame },
				"recurved",
				Planegap(Stainlayout.GetLayout(Texture), Other.Curve.Tiles)
		end
		table.insert(Reasons, "the curved sticker at another Ink position failed too (" .. Text .. ")")
	else
		table.insert(Reasons, "no other Ink position takes a curved sticker")
	end
	return string.format("%s: the flat sticker is kept, check it; to fix it, %s%s", Joined(Reasons), Advice, Note), {}, "kept", 0
end

local function Fitsticker(Key: string): (string, { Instance }, string, number)
	local Template = Templates:FindFirstChild(Key)
	if not Template then
		return "no template named " .. Key .. " in ReplicatedStorage.Asset.Object, skipped", {}, "skipped", 0
	end
	local Old = Template:FindFirstChild("Sticker")
	if not Old or Old:GetAttribute("RandomSticker") ~= true then
		return "no Sticker made by tools/PlaceStickers.luau, nothing changed", {}, "skipped", 0
	end
	if Old:GetAttribute("CurvedSticker") == true then
		return "already has a curved sticker from this script, nothing changed", {}, "skipped", 0
	end
	assert(Old:IsA("BasePart"), Old:GetFullName() .. " must be a Part")
	local Image = Old:FindFirstChild("Image")
	assert(Image and Image:IsA("Decal"), Old:GetFullName() .. " has no Decal named Image")
	local Oldinks = Findinks(Template)
	if #Oldinks ~= 1 then
		return string.format("has %d Inks instead of 1, nothing changed", #Oldinks), {}, "skipped", 0
	end
	local Originals = Withroot(Template)
	local Clone = Template:Clone()
	assert(Clone, Template:GetFullName() .. " must be Archivable")
	local Copies = Withroot(Clone)
	if #Copies ~= #Originals then
		return "has non-Archivable instances, skipped", {}, "skipped", 0
	end
	local Twin = {}
	for Index, Copy in ipairs(Copies) do
		Twin[Copy] = Originals[Index]
	end
	Clone:FindFirstChild("Sticker"):Destroy()
	Removeinks(Findinks(Clone))
	Clone.Parent = Workspace
	local Caster = Surfacecast.new(Clone)
	local Success, Message, Created, Kind, Plane = pcall(Fitclone, Key, Template, Old, Image.Texture, Oldinks[1], Clone, Copies, Twin, Caster)
	Caster:Destroy()
	Clone.Parent = nil
	if not Success then
		error(Message, 0)
	end
	return Message, Created, Kind, Plane
end

local Keys = {}
for Key, Entry in pairs(Objectconfig.Object) do
	if Entry.Sticker then
		table.insert(Keys, Key)
	end
end
table.sort(Keys)
local Recorded, Recording = pcall(Changehistoryservice.TryBeginRecording, Changehistoryservice, "FitStickers", "Fit stickers")
if not (Recorded and Recording) then
	warn(
		"Fit stickers: Studio did not open an undo recording ("
			.. (if Recorded then "TryBeginRecording returned nothing" else tostring(Recording))
			.. "), so one Ctrl+Z may not undo this whole run: keep a saved copy of the place before going on"
	)
end
local Created = {}
local Counts = { flat = 0, moved = 0, curved = 0, nearly = 0, recurved = 0, kept = 0, skipped = 0, failed = 0 }
local Floating = {}
for _, Key in ipairs(Keys) do
	local Success, Message, Made, Kind, Plane = pcall(Fitsticker, Key)
	if not Success then
		Counts.failed += 1
		warn(Key .. ": error, " .. tostring(Message))
	else
		Counts[Kind] += 1
		for _, Item in ipairs(Made) do
			table.insert(Created, Item)
		end
		if #Made > 0 and Plane > Planelimit then
			table.insert(Floating, string.format("%s (%.2f stud)", Key, Plane))
		end
		print(Key .. ": " .. Message)
	end
end
if Recorded and Recording then
	Changehistoryservice:FinishRecording(Recording, Enum.FinishRecordingOperation.Commit)
end
Selection:Set(Created)
print(
	string.format(
		"Fit stickers: %d already flat, %d moved to a flat spot, %d curved in place, %d moved to a nearly flat spot, %d with the Ink moved and the sticker curved, %d kept flat, %d skipped, %d errors, %d casts",
		Counts.flat,
		Counts.moved,
		Counts.curved,
		Counts.nearly,
		Counts.recurved,
		Counts.kept,
		Counts.skipped,
		Counts.failed,
		Casts
	)
)
if #Floating > 0 then
	print("Fit stickers: in Studio an Ink is drawn flat on its part's box face, so it can show in front of the sticker on " .. table.concat(Floating, ", ") .. "; in Play the game draws it on the mesh, under the sticker")
end
