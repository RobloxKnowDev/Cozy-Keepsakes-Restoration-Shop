local Assetservice = game:GetService("AssetService")
local Workspace = game:GetService("Workspace")

local Surfacecast = {}
Surfacecast.__index = Surfacecast

export type Hit = {
	Instance: BasePart,
	Position: Vector3,
	Normal: Vector3,
	DecalNormal: Vector3,
	Distance: number,
}

type MeshEntry = {
	Mesh: EditableMesh,
	Center: Vector3,
	Scale: Vector3,
}

local Boxmargin = 0.01
local Backstep = 0.001
local Maxbackfaces = 4
local Flatmesh = 1e-4
local Deniedmeshes: { [string]: boolean } = {}

local function Slab(Origin: number, Vector: number, Half: number, Entry: number, Exit: number): (number, number)
	if math.abs(Vector) < 1e-9 then
		if math.abs(Origin) > Half then
			return 1, 0
		end
		return Entry, Exit
	end
	local Near, Far = (-Half - Origin) / Vector, (Half - Origin) / Vector
	return math.max(Entry, math.min(Near, Far)), math.min(Exit, math.max(Near, Far))
end

local function Boxentry(Origin: Vector3, Vector: Vector3, Half: Vector3): number?
	local Entry, Exit = Slab(Origin.X, Vector.X, Half.X, 0, 1)
	Entry, Exit = Slab(Origin.Y, Vector.Y, Half.Y, Entry, Exit)
	Entry, Exit = Slab(Origin.Z, Vector.Z, Half.Z, Entry, Exit)
	return if Entry <= Exit then Entry else nil
end

local function Facenormal(Mesh: EditableMesh, Face: number): Vector3
	local Vertices = Mesh:GetFaceVertices(Face)
	local First = Mesh:GetPosition(Vertices[1])
	local Normal = (Mesh:GetPosition(Vertices[2]) - First):Cross(Mesh:GetPosition(Vertices[3]) - First)
	local Shading = Vector3.zero
	for _, Normalid in ipairs(Mesh:GetFaceNormals(Face)) do
		Shading += Mesh:GetNormal(Normalid) or Vector3.zero
	end
	return if Shading:Dot(Normal) < 0 then -Normal else Normal
end

local function Loadmesh(Part: MeshPart): MeshEntry
	local Mesh = Assetservice:CreateEditableMeshAsync(Part.MeshContent)
	local Minimum = Vector3.one * math.huge
	local Maximum = -Minimum
	for _, Vertex in ipairs(Mesh:GetVertices()) do
		local Position = Mesh:GetPosition(Vertex)
		Minimum = Minimum:Min(Position)
		Maximum = Maximum:Max(Position)
	end
	local Center = (Minimum + Maximum) / 2
	Mesh:RaycastLocal(Center, Vector3.yAxis)
	return { Mesh = Mesh, Center = Center, Scale = Part.MeshSize / Part.Size }
end

local function Castmesh(Part: MeshPart, Entry: MeshEntry, Origin: Vector3, Vector: Vector3, Limit: number): Hit?
	if not Part.CanQuery then
		return nil
	end
	local Localorigin = Part.CFrame:PointToObjectSpace(Origin)
	local Localvector = Part.CFrame:VectorToObjectSpace(Vector)
	local Length = Localvector.Magnitude
	local Start = Boxentry(Localorigin, Localvector, Part.Size / 2 + Vector3.one * Boxmargin)
	if not Start or Start * Length >= Limit then
		return nil
	end
	local Direction = Localvector / Length
	local Travelled = 0
	for _ = 1, Maxbackfaces do
		if Travelled >= Length then
			return nil
		end
		local Face, Point = Entry.Mesh:RaycastLocal(
			(Localorigin + Direction * Travelled) * Entry.Scale + Entry.Center,
			Direction * (Length - Travelled) * Entry.Scale
		)
		if not Face then
			return nil
		end
		local Localpoint = (Point - Entry.Center) / Entry.Scale
		local Distance = (Localpoint - Localorigin):Dot(Direction)
		if Distance >= Limit or Distance > Length then
			return nil
		end
		local Localnormal = Facenormal(Entry.Mesh, Face) * Entry.Scale
		if Localnormal.Magnitude > 0 and (Part.DoubleSided or Localnormal:Dot(Direction) < 0) then
			local Decalnormal = Part.CFrame:VectorToWorldSpace(Localnormal.Unit)
			return {
				Instance = Part,
				Position = Part.CFrame:PointToWorldSpace(Localpoint),
				Normal = if Decalnormal:Dot(Vector) > 0 then -Decalnormal else Decalnormal,
				DecalNormal = Decalnormal,
				Distance = Distance,
			}
		end
		Travelled = Distance + Backstep
	end
	return nil
end

local function Fromresult(Result: RaycastResult): Hit
	return {
		Instance = Result.Instance :: BasePart,
		Position = Result.Position,
		Normal = Result.Normal,
		DecalNormal = Result.Normal,
		Distance = Result.Distance,
	}
end

function Surfacecast.new(Object: Instance)
	local Solids = {}
	if Object:IsA("BasePart") then
		table.insert(Solids, Object)
	end
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("BasePart") then
			table.insert(Solids, Descendant)
		end
	end
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = Solids
	local Partparams = RaycastParams.new()
	Partparams.FilterType = Enum.RaycastFilterType.Include
	return setmetatable({
		Solids = Solids,
		Params = Params,
		Partparams = Partparams,
		Meshes = {} :: { [BasePart]: MeshEntry },
		Destroyed = false,
	}, Surfacecast)
end

function Surfacecast:Load()
	local Pending = 0
	local Failed = 0
	local Lasterror = nil
	local Denied = {}
	for _, Part in ipairs(table.clone(self.Solids)) do
		if
			Part:IsA("MeshPart")
			and not Deniedmeshes[Part.MeshId]
			and math.min(Part.MeshSize.X, Part.MeshSize.Y, Part.MeshSize.Z) > Flatmesh
		then
			Pending += 1
			task.spawn(function()
				local Success, Entry = pcall(Loadmesh, Part)
				if not Success and string.find(tostring(Entry), "permission", 1, true) then
					if not Deniedmeshes[Part.MeshId] then
						Deniedmeshes[Part.MeshId] = true
						table.insert(Denied, Part.MeshId)
					end
				elseif not Success then
					Failed += 1
					Lasterror = Entry
				elseif self.Destroyed then
					Entry.Mesh:Destroy()
				else
					self.Meshes[Part] = Entry
					table.remove(self.Solids, table.find(self.Solids, Part))
					self.Params.FilterDescendantsInstances = self.Solids
				end
				Pending -= 1
			end)
		end
	end
	while Pending > 0 do
		task.wait()
	end
	if #Denied > 0 then
		warn("SurfaceCast: no permission to edit " .. table.concat(Denied, ", ") .. ", these meshes keep their collision geometry")
	end
	if Failed > 0 then
		warn(string.format("SurfaceCast: %d meshes stay on collision geometry: %s", Failed, tostring(Lasterror)))
	end
end

function Surfacecast:Cast(Origin: Vector3, Vector: Vector3): Hit?
	local Result = Workspace:Raycast(Origin, Vector, self.Params)
	local Best = if Result then Fromresult(Result) else nil
	for Part, Entry in pairs(self.Meshes) do
		local Hit = Castmesh(Part :: MeshPart, Entry, Origin, Vector, if Best then Best.Distance else Vector.Magnitude)
		if Hit then
			Best = Hit
		end
	end
	return Best
end

function Surfacecast:CastPart(Part: BasePart, Origin: Vector3, Vector: Vector3): Hit?
	local Entry = self.Meshes[Part]
	if Entry then
		return Castmesh(Part :: MeshPart, Entry, Origin, Vector, Vector.Magnitude)
	end
	self.Partparams.FilterDescendantsInstances = { Part }
	local Result = Workspace:Raycast(Origin, Vector, self.Partparams)
	return if Result then Fromresult(Result) else nil
end

function Surfacecast:Destroy()
	self.Destroyed = true
	for _, Entry in pairs(self.Meshes) do
		Entry.Mesh:Destroy()
	end
	table.clear(self.Meshes)
end

return Surfacecast
