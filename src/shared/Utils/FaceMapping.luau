local FaceMapping = {}

local Seamdot = 0.6

function FaceMapping.GetPoint(Part: BasePart, Worldposition: Vector3, Facename: string): Vector2
	local Position = Part.CFrame:PointToObjectSpace(Worldposition)
	local Size = Part.Size
	if Facename == "Front" then
		return Vector2.new(0.5 - Position.X / Size.X, 0.5 - Position.Y / Size.Y)
	end
	if Facename == "Back" then
		return Vector2.new(0.5 + Position.X / Size.X, 0.5 - Position.Y / Size.Y)
	end
	if Facename == "Left" then
		return Vector2.new(0.5 + Position.Z / Size.Z, 0.5 - Position.Y / Size.Y)
	end
	if Facename == "Right" then
		return Vector2.new(0.5 - Position.Z / Size.Z, 0.5 - Position.Y / Size.Y)
	end
	if Facename == "Top" then
		return Vector2.new(0.5 - Position.Z / Size.Z, 0.5 + Position.X / Size.X)
	end
	return Vector2.new(0.5 - Position.Z / Size.Z, 0.5 - Position.X / Size.X)
end

function FaceMapping.GetLocalPoint(Size: Vector3, Facename: string, U: number, V: number): Vector3
	local Half = Size * 0.5
	if Facename == "Front" then
		return Vector3.new((0.5 - U) * Size.X, (0.5 - V) * Size.Y, -Half.Z)
	end
	if Facename == "Back" then
		return Vector3.new((U - 0.5) * Size.X, (0.5 - V) * Size.Y, Half.Z)
	end
	if Facename == "Left" then
		return Vector3.new(-Half.X, (0.5 - V) * Size.Y, (U - 0.5) * Size.Z)
	end
	if Facename == "Right" then
		return Vector3.new(Half.X, (0.5 - V) * Size.Y, (0.5 - U) * Size.Z)
	end
	if Facename == "Top" then
		return Vector3.new((V - 0.5) * Size.X, Half.Y, (0.5 - U) * Size.Z)
	end
	return Vector3.new((0.5 - V) * Size.X, -Half.Y, (0.5 - U) * Size.Z)
end

function FaceMapping.GetDecalPoint(Part: BasePart, Worldposition: Vector3, Facename: string): Vector2
	local Position = Part.CFrame:PointToObjectSpace(Worldposition)
	local Size = Part.Size
	if Facename == "Top" then
		return Vector2.new(0.5 - Position.X / Size.X, 0.5 - Position.Z / Size.Z)
	end
	if Facename == "Bottom" then
		return Vector2.new(0.5 + Position.X / Size.X, 0.5 - Position.Z / Size.Z)
	end
	return FaceMapping.GetPoint(Part, Worldposition, Facename)
end

function FaceMapping.GetDecalLocalPoint(Size: Vector3, Facename: string, U: number, V: number): Vector3
	local Half = Size * 0.5
	if Facename == "Top" then
		return Vector3.new((0.5 - U) * Size.X, Half.Y, (0.5 - V) * Size.Z)
	end
	if Facename == "Bottom" then
		return Vector3.new((U - 0.5) * Size.X, -Half.Y, (0.5 - V) * Size.Z)
	end
	return FaceMapping.GetLocalPoint(Size, Facename, U, V)
end

function FaceMapping.ShowsDecal(Face: Enum.NormalId, Localnormal: Vector3): boolean
	local Largest = math.max(math.abs(Localnormal.X), math.abs(Localnormal.Y), math.abs(Localnormal.Z))
	return Vector3.FromNormalId(Face):Dot(Localnormal) >= Largest
end

function FaceMapping.TouchesDecal(Face: Enum.NormalId, Localnormal: Vector3): boolean
	local Largest = math.max(math.abs(Localnormal.X), math.abs(Localnormal.Y), math.abs(Localnormal.Z))
	return Vector3.FromNormalId(Face):Dot(Localnormal) >= math.min(Seamdot, Largest)
end

return FaceMapping
