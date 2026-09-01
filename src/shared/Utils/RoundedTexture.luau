local RoundedTexture = {}

function RoundedTexture.GetRatio(Texture: ImageLabel): number
	return math.clamp(tonumber(Texture:GetAttribute("CornerRadius")) or 0, 0, 0.5)
end

function RoundedTexture.GetRadius(Width: number, Height: number, Ratio: number): number
	return math.min(Width, Height) * Ratio
end

function RoundedTexture.IsOutside(X: number, Y: number, Width: number, Height: number, Radius: number): boolean
	local Pointx = X + 0.5
	local Pointy = Y + 0.5
	local Centerx = math.clamp(Pointx, Radius, Width - Radius)
	local Centery = math.clamp(Pointy, Radius, Height - Radius)
	local Deltax = Pointx - Centerx
	local Deltay = Pointy - Centery
	return Deltax * Deltax + Deltay * Deltay > Radius * Radius
end

return RoundedTexture
