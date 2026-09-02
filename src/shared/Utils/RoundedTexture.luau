local RoundedTexture = {}

export type Shape = { Ratio: number, Inset: number }
export type Bounds = { Left: number, Top: number, Right: number, Bottom: number, Radius: number }

function RoundedTexture.GetShape(Texture: ImageLabel): Shape
	return {
		Ratio = math.clamp(tonumber(Texture:GetAttribute("CornerRadius")) or 0, 0, 0.5),
		Inset = math.clamp(tonumber(Texture:GetAttribute("TextureInset")) or 0, 0, 0.45),
	}
end

function RoundedTexture.IsCut(Shape: Shape): boolean
	return Shape.Ratio > 0 or Shape.Inset > 0
end

function RoundedTexture.GetKey(Shape: Shape): string
	return tostring(Shape.Ratio) .. "|" .. tostring(Shape.Inset)
end

function RoundedTexture.GetBounds(Width: number, Height: number, Shape: Shape): Bounds
	local Margin = math.min(Width, Height) * Shape.Inset
	local Left, Top = Margin, Margin
	local Right, Bottom = Width - Margin, Height - Margin
	return {
		Left = Left,
		Top = Top,
		Right = Right,
		Bottom = Bottom,
		Radius = math.min(Right - Left, Bottom - Top) * Shape.Ratio,
	}
end

function RoundedTexture.GetRowInset(Pointy: number, Bounds: Bounds): number?
	if Pointy < Bounds.Top or Pointy > Bounds.Bottom then
		return nil
	end
	local Topcenter = Bounds.Top + Bounds.Radius
	local Bottomcenter = Bounds.Bottom - Bounds.Radius
	local Deltay = 0
	if Pointy < Topcenter then
		Deltay = Topcenter - Pointy
	elseif Pointy > Bottomcenter then
		Deltay = Pointy - Bottomcenter
	end
	return Bounds.Radius - math.sqrt(math.max(Bounds.Radius * Bounds.Radius - Deltay * Deltay, 0))
end

function RoundedTexture.IsOutside(X: number, Y: number, Bounds: Bounds): boolean
	local Pointx = X + 0.5
	local Rowinset = RoundedTexture.GetRowInset(Y + 0.5, Bounds)
	if not Rowinset then
		return true
	end
	return Pointx < Bounds.Left + Rowinset or Pointx > Bounds.Right - Rowinset
end

return RoundedTexture
