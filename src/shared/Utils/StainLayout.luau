local StainLayout = {}

export type Layout = {
	Texture: ImageLabel,
	Frame: Frame,
	Surface: SurfaceGui,
	Part: BasePart,
	Face: Enum.NormalId,
	Facename: string,
	Origin: Vector2,
	Axisu: Vector2,
	Axisv: Vector2,
	Inverseorigin: Vector2,
	Inverseu: Vector2,
	Inversev: Vector2,
	Minimum: Vector2,
	Maximum: Vector2,
}

local Rotatedfaces = { Top = true, Bottom = true }

local function Assertplain(Container: Instance)
	for _, Child in ipairs(Container:GetChildren()) do
		assert(
			not Child:IsA("UIComponent"),
			"StainLayout: delete "
				.. Child:GetFullName()
				.. " ("
				.. Child.ClassName
				.. "), stains do not support UI modifiers, round a Texture with its CornerRadius attribute (0 to 0.5) instead"
		)
	end
end

local function Getcanvas(Surface: SurfaceGui, Part: BasePart, Facename: string): (number, number)
	if Surface.SizingMode == Enum.SurfaceGuiSizingMode.FixedSize then
		return Surface.CanvasSize.X, Surface.CanvasSize.Y
	end
	local Size = Part.Size * Surface.PixelsPerStud
	if Rotatedfaces[Facename] then
		return Size.Z, Size.X
	end
	if Facename == "Left" or Facename == "Right" then
		return Size.Z, Size.Y
	end
	return Size.X, Size.Y
end

local function Getrect(Object: GuiObject, Parentwidth: number, Parentheight: number): (number, number, number, number)
	assert(Object.AutomaticSize == Enum.AutomaticSize.None, "StainLayout: " .. Object:GetFullName() .. " must have AutomaticSize None")
	local Size, Position, Anchor = Object.Size, Object.Position, Object.AnchorPoint
	local Constraint = Object.SizeConstraint
	local Width = Size.X.Scale * (if Constraint == Enum.SizeConstraint.RelativeYY then Parentheight else Parentwidth) + Size.X.Offset
	local Height = Size.Y.Scale * (if Constraint == Enum.SizeConstraint.RelativeXX then Parentwidth else Parentheight) + Size.Y.Offset
	assert(
		Width > 0 and Height > 0,
		string.format(
			"StainLayout: %s must have a positive size (%.3f x %.3f px inside %.3f x %.3f px)",
			Object:GetFullName(),
			Width,
			Height,
			Parentwidth,
			Parentheight
		)
	)
	return Position.X.Scale * Parentwidth + Position.X.Offset + (0.5 - Anchor.X) * Width,
		Position.Y.Scale * Parentheight + Position.Y.Offset + (0.5 - Anchor.Y) * Height,
		Width,
		Height
end

function StainLayout.GetLayout(Texture: ImageLabel): Layout
	assert(Texture:IsA("ImageLabel"), "StainLayout: " .. Texture:GetFullName() .. " must be an ImageLabel")
	local Frame = Texture.Parent :: Frame
	assert(Frame and Frame:IsA("Frame"), "StainLayout: the parent of " .. Texture:GetFullName() .. " must be a Frame")
	local Surface = Frame.Parent :: SurfaceGui
	assert(Surface and Surface:IsA("SurfaceGui"), "StainLayout: " .. Frame:GetFullName() .. " must be a direct child of a SurfaceGui")
	local Part = Surface.Parent :: BasePart
	assert(Part and Part:IsA("BasePart"), "StainLayout: " .. Surface:GetFullName() .. " must be a direct child of a BasePart")
	assert(
		not Surface.Adornee or Surface.Adornee == Part,
		"StainLayout: " .. Surface:GetFullName() .. " must not use Adornee, parent it to its part instead"
	)
	assert(Texture.ScaleType == Enum.ScaleType.Stretch, "StainLayout: " .. Texture:GetFullName() .. " must use ScaleType Stretch")
	assert(
		Texture.ImageRectOffset == Vector2.zero and Texture.ImageRectSize == Vector2.zero,
		"StainLayout: " .. Texture:GetFullName() .. " must keep ImageRectOffset and ImageRectSize at 0, 0"
	)
	Assertplain(Surface)
	Assertplain(Frame)
	Assertplain(Texture)
	local Face = Surface.Face
	local Facename = Face.Name
	local Rotated = Rotatedfaces[Facename] == true
	local Canvaswidth, Canvasheight = Getcanvas(Surface, Part, Facename)
	local Framex, Framey, Framewidth, Frameheight = Getrect(Frame, Canvaswidth, Canvasheight)
	local Texturex, Texturey, Texturewidth, Textureheight = Getrect(Texture, Framewidth, Frameheight)
	local Shiftx, Shifty = Texturex - Framewidth * 0.5, Texturey - Frameheight * 0.5
	local Frameangle, Textureangle = math.rad(Frame.Rotation), math.rad(Texture.Rotation)
	local Framecos, Framesin = math.cos(Frameangle), math.sin(Frameangle)
	local Texturecos, Texturesin = math.cos(Textureangle), math.sin(Textureangle)
	local function Map(U: number, V: number): (number, number)
		local X, Y = (U - 0.5) * Texturewidth, (V - 0.5) * Textureheight
		X, Y = X * Texturecos - Y * Texturesin + Shiftx, X * Texturesin + Y * Texturecos + Shifty
		X, Y = (X * Framecos - Y * Framesin + Framex) / Canvaswidth, (X * Framesin + Y * Framecos + Framey) / Canvasheight
		if Rotated then
			return 1 - Y, X
		end
		return X, Y
	end
	local Originx, Originy = Map(0, 0)
	local Endux, Enduy = Map(1, 0)
	local Endvx, Endvy = Map(0, 1)
	local Axisux, Axisuy = Endux - Originx, Enduy - Originy
	local Axisvx, Axisvy = Endvx - Originx, Endvy - Originy
	local Cornerx, Cornery = Endux + Axisvx, Enduy + Axisvy
	local Determinant = Axisux * Axisvy - Axisuy * Axisvx
	local Inverseux, Inverseuy = Axisvy / Determinant, -Axisuy / Determinant
	local Inversevx, Inversevy = -Axisvx / Determinant, Axisux / Determinant
	return {
		Texture = Texture,
		Frame = Frame,
		Surface = Surface,
		Part = Part,
		Face = Face,
		Facename = Facename,
		Origin = Vector2.new(Originx, Originy),
		Axisu = Vector2.new(Axisux, Axisuy),
		Axisv = Vector2.new(Axisvx, Axisvy),
		Inverseorigin = Vector2.new(-(Inverseux * Originx + Inversevx * Originy), -(Inverseuy * Originx + Inversevy * Originy)),
		Inverseu = Vector2.new(Inverseux, Inverseuy),
		Inversev = Vector2.new(Inversevx, Inversevy),
		Minimum = Vector2.new(math.min(Originx, Endux, Endvx, Cornerx), math.min(Originy, Enduy, Endvy, Cornery)),
		Maximum = Vector2.new(math.max(Originx, Endux, Endvx, Cornerx), math.max(Originy, Enduy, Endvy, Cornery)),
	}
end

function StainLayout.GetFacePoint(Layout: Layout, Texturepoint: Vector2): Vector2
	local Origin, Axisu, Axisv = Layout.Origin, Layout.Axisu, Layout.Axisv
	return Vector2.new(
		Origin.X + Axisu.X * Texturepoint.X + Axisv.X * Texturepoint.Y,
		Origin.Y + Axisu.Y * Texturepoint.X + Axisv.Y * Texturepoint.Y
	)
end

function StainLayout.GetTexturePoint(Layout: Layout, Facepoint: Vector2): Vector2
	local Origin, Axisu, Axisv = Layout.Inverseorigin, Layout.Inverseu, Layout.Inversev
	return Vector2.new(
		Origin.X + Axisu.X * Facepoint.X + Axisv.X * Facepoint.Y,
		Origin.Y + Axisu.Y * Facepoint.X + Axisv.Y * Facepoint.Y
	)
end

function StainLayout.Contains(Layout: Layout, Facepoint: Vector2): boolean
	local Point = StainLayout.GetTexturePoint(Layout, Facepoint)
	return Point.X >= 0 and Point.X <= 1 and Point.Y >= 0 and Point.Y <= 1
end

function StainLayout.GetMaskCell(Layout: Layout, Facepoint: Vector2, Grid: number): number?
	local Point = StainLayout.GetTexturePoint(Layout, Facepoint)
	if Point.X < 0 or Point.X > 1 or Point.Y < 0 or Point.Y > 1 then
		return nil
	end
	return math.min(math.floor(Point.Y * Grid), Grid - 1) * Grid + math.min(math.floor(Point.X * Grid), Grid - 1) + 1
end

function StainLayout.Touches(Layout: Layout, Facepoint: Vector2, Radius: Vector2): boolean
	local Minimum, Maximum = Layout.Minimum, Layout.Maximum
	return Facepoint.X >= Minimum.X - Radius.X
		and Facepoint.X <= Maximum.X + Radius.X
		and Facepoint.Y >= Minimum.Y - Radius.Y
		and Facepoint.Y <= Maximum.Y + Radius.Y
end

return StainLayout
