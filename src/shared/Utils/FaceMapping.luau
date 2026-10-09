local FaceMapping = {}

local Seamdot = 0.6
local Tiemargin = 0.001

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

function FaceMapping.GetDecalSize(Size: Vector3, Facename: string): Vector2
	if Facename == "Top" or Facename == "Bottom" then
		return Vector2.new(Size.X, Size.Z)
	end
	if Facename == "Front" or Facename == "Back" then
		return Vector2.new(Size.X, Size.Y)
	end
	return Vector2.new(Size.Z, Size.Y)
end

function FaceMapping.GetBrushRadius(Size: Vector3, Facename: string, Radius: number, Minimum: number): Vector2
	local Extent = FaceMapping.GetDecalSize(Size, Facename)
	return Vector2.new(math.max(Radius, Minimum / Extent.X), math.max(Radius, Minimum / Extent.Y))
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

local function Getmeshnormal(Decal: Decal, Worldnormal: Vector3): Vector3
	local Part = Decal.Parent :: BasePart
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	if Part:IsA("TriangleMeshPart") then
		return (Localnormal * Part.Size / (Part :: TriangleMeshPart).MeshSize).Unit
	end
	return Localnormal.Unit
end

function FaceMapping.ShowsDecal(Decal: Decal, Worldnormal: Vector3): boolean
	local Meshnormal = Getmeshnormal(Decal, Worldnormal)
	local Axis = Vector3.FromNormalId(Decal.Face)
	local Dot = Axis:Dot(Meshnormal)
	local Rest = Meshnormal - Axis * Dot
	return Dot >= math.max(math.abs(Rest.X), math.abs(Rest.Y), math.abs(Rest.Z)) + Tiemargin
end

function FaceMapping.TouchesDecal(Decal: Decal, Worldnormal: Vector3): boolean
	local Meshnormal = Getmeshnormal(Decal, Worldnormal)
	local Largest = math.max(math.abs(Meshnormal.X), math.abs(Meshnormal.Y), math.abs(Meshnormal.Z))
	return Vector3.FromNormalId(Decal.Face):Dot(Meshnormal) >= math.min(Seamdot, Largest)
end

return FaceMapping
