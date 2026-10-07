local Replicatedstorage = game:GetService("ReplicatedStorage")
local Userinputservice = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)

local Toolassets = Replicatedstorage:WaitForChild("Asset"):WaitForChild("Tool")

local Displayedtool = {}
Displayedtool.__index = Displayedtool

local Raylength = 100
local Contactoffset = 0.006
local Normalsmoothing = 18
local Tiltsmoothing = 10
local Tiltsteps = 8
local Clearanceoffset = 0.03
local Maxbackoff = 0.15
local Cornersigns = {
	Vector3.new(1, 1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, -1, -1),
}

local function Pivotof(Instance: Instance): CFrame?
	if Instance:IsA("Model") then return Instance:GetPivot() end
	if Instance:IsA("BasePart") then return Instance.CFrame end
	return nil
end

local function Pivotto(Instance: Instance, Target: CFrame)
	if Instance:IsA("Model") then
		Instance:PivotTo(Target)
	elseif Instance:IsA("BasePart") then
		Instance.CFrame = Target
	end
end

local function Rotation(From: Vector3, To: Vector3): (Vector3, number)
	local Cross = From:Cross(To)
	local Angle = math.atan2(Cross.Magnitude, From:Dot(To))
	if Cross.Magnitude > 1e-6 then return Cross.Unit, Angle end
	local Axis = From:Cross(Vector3.xAxis)
	if Axis.Magnitude < 1e-3 then Axis = From:Cross(Vector3.yAxis) end
	return Axis.Unit, Angle
end

local function Slerp(From: Vector3, To: Vector3, Alpha: number): Vector3
	local Axis, Angle = Rotation(From, To)
	return CFrame.fromAxisAngle(Axis, Angle * Alpha):VectorToWorldSpace(From)
end

function Displayedtool.new()
	return setmetatable({ Camera = Workspace.CurrentCamera, Stroke = 0, OnObject = false, Tilt = 0 }, Displayedtool)
end

function Displayedtool:Destroy()
	if self.Instance then self.Instance:Destroy() end
	self.Instance, self.Tip, self.Definition = nil, nil, nil
	self.Hit, self.HitInstance, self.SurfacePosition, self.SurfaceNormal, self.DecalNormal = nil, nil, nil, nil, nil
	self.SmoothNormal = nil
	self.Tilt = 0
	self.OnObject = false
end

function Displayedtool:Select(Definition)
	self:Destroy()
	self.Definition = Definition
	if not Definition.AssetName then return end

	local Toolinstance = Toolassets:WaitForChild(Definition.AssetName):Clone()
	Toolinstance.Name = "Displayed" .. Definition.Name
	self.Instance = Toolinstance
	self.Tip = Toolinstance:WaitForChild("Tip") :: Attachment
	local Pivot = Pivotof(Toolinstance) :: CFrame
	local Parts = {}
	local Tipparts = {}
	for _, Descendant in ipairs(Toolinstance:GetDescendants()) do
		if Descendant:IsA("BasePart") then
			Descendant.Anchored = true
			Descendant.CanCollide, Descendant.CanQuery, Descendant.CanTouch = false, false, false
			Descendant.CastShadow = false
			table.insert(Parts, Descendant)
			if Definition.UsesCenteredTip and string.find(string.lower(Descendant.Name), "tip", 1, true) then
				table.insert(Tipparts, Descendant)
			end
		end
	end
	if Toolinstance:IsA("BasePart") then
		Toolinstance.Anchored = true
		Toolinstance.CanCollide, Toolinstance.CanQuery, Toolinstance.CanTouch = false, false, false
		Toolinstance.CastShadow = false
		table.insert(Parts, Toolinstance)
	end
	local Corners = {}
	local Weighted, Volume = Vector3.zero, 0
	for _, Part in ipairs(Parts) do
		for _, Sign in ipairs(Cornersigns) do
			table.insert(Corners, Pivot:PointToObjectSpace(Part.CFrame:PointToWorldSpace(Part.Size / 2 * Sign)))
		end
		local Partvolume = Part.Size.X * Part.Size.Y * Part.Size.Z
		Weighted += Pivot:PointToObjectSpace(Part.Position) * Partvolume
		Volume += Partvolume
	end
	self.Corners = Corners
	self.Centroid = Weighted / Volume
	if Definition.UsesCenteredTip and #Tipparts > 0 then
		local Average = Vector3.zero
		for _, Part in ipairs(Tipparts) do Average += Part.Position end
		local Tip = Instance.new("Attachment")
		Tip.Name = "RuntimeTip"
		Tip.CFrame = Tipparts[1].CFrame:ToObjectSpace(CFrame.new(Average / #Tipparts))
		Tip.Parent = Tipparts[1]
		self.Tip = Tip
	end
	if Definition.OnDisplayCreated then
		Definition.OnDisplayCreated(Toolinstance)
	end
	Toolinstance.Parent = Workspace
end

function Displayedtool:FindTilt(Pose: CFrame, Position: Vector3, Normal: Vector3, Free: Vector3): number
	local Body = Pose:PointToWorldSpace(self.Centroid) - Position
	if Body.Magnitude < 1e-3 then return 0 end
	local Reach = 0
	for _, Corner in ipairs(self.Corners) do
		Reach = math.max(Reach, (Pose:PointToWorldSpace(Corner) - Position).Magnitude)
	end
	local Start = Position + Normal * Clearanceoffset
	local Axis, Angle = Rotation(Body.Unit, Free)
	local Cleaningcontroller = Core:GetController("CleaningController")
	for Step = 0, Tiltsteps - 1 do
		local Direction = CFrame.fromAxisAngle(Axis, Angle * Step / Tiltsteps):VectorToWorldSpace(Body.Unit)
		if not Cleaningcontroller:CastSurface(Start, Direction * Reach) then
			return Step / Tiltsteps
		end
	end
	return 1
end

function Displayedtool:Backoff(Pose: CFrame, Position: Vector3, Normal: Vector3): number
	local Lowest = 0
	for _, Corner in ipairs(self.Corners) do
		Lowest = math.min(Lowest, (Pose:PointToWorldSpace(Corner) - Position):Dot(Normal))
	end
	return math.min(-Lowest, Maxbackoff)
end

function Displayedtool:Update(Deltatime: number, Object: Model | BasePart, Isusing: boolean, Lockedpivot: CFrame?)
	local Toolinstance, Definition = self.Instance, self.Definition
	if not Toolinstance or not Definition then return end
	if Lockedpivot then Pivotto(Toolinstance, Lockedpivot) return end

	local Mouse = Userinputservice:GetMouseLocation()
	local Ray = self.Camera:ViewportPointToRay(Mouse.X, Mouse.Y)
	local Hit = Core:GetController("CleaningController"):CastSurface(Ray.Origin, Ray.Direction * Raylength)
	self.Hit = Hit
	self.OnObject = Hit ~= nil
	self.HitInstance = if Hit then Hit.Instance else nil

	local Position, normal, Decalnormal
	if Hit then
		Position, normal, Decalnormal = Hit.Position, Hit.Normal, Hit.DecalNormal
	else
		local Objectpivot = Object:IsA("Model") and Object:GetPivot() or Object.CFrame
		local Planenormal = self.Camera.CFrame.LookVector
		local Denominator = Ray.Direction:Dot(Planenormal)
		local Distance = (Objectpivot.Position - Ray.Origin):Dot(Planenormal) / Denominator
		Position, normal = Ray.Origin + Ray.Direction * math.max(Distance, 1), -Planenormal
		Decalnormal = normal
	end
	self.SurfacePosition = Position
	self.SurfaceNormal = normal
	self.DecalNormal = Decalnormal

	local Smoothnormal = if self.SmoothNormal
		then Slerp(self.SmoothNormal, normal, 1 - math.exp(-Normalsmoothing * Deltatime))
		else normal
	self.SmoothNormal = Smoothnormal
	local Cameraright = self.Camera.CFrame.RightVector
	local Tangent = Cameraright - Smoothnormal * Cameraright:Dot(Smoothnormal)
	Tangent = if Tangent.Magnitude > 1e-3 then Tangent.Unit else Vector3.zero

	local Pulling = Definition.UsesPullMotion == true
	local Touching = Isusing and self.OnObject
	self.Stroke += Deltatime * (Touching and (Pulling and 10 or 24) or 5)
	local Stroke = Touching and not Pulling and math.sin(self.Stroke) * 0.045 or 0
	local Pull = Touching and Pulling and (0.08 + (math.sin(self.Stroke) + 1) * 0.09) or 0
	local Contact = Position + Smoothnormal * (Contactoffset + Pull) + Tangent * Stroke
	local Target
	if Definition.GetDisplayCFrame then
		Target = Definition.GetDisplayCFrame({
			Object = Object,
			SurfacePosition = Position,
			SurfaceNormal = Smoothnormal,
			Camera = self.Camera,
			IsUsing = Isusing,
			DeltaTime = Deltatime,
		})
	else
		Target = CFrame.lookAt(Contact, Contact + Smoothnormal, self.Camera.CFrame.UpVector)
			* (Definition.DisplayRotation or CFrame.identity)
	end
	local Current = Pivotof(Toolinstance)
	if Current and self.Tip then
		local Tipoffset = if self.Tip.Parent == Toolinstance
			then self.Tip.CFrame
			else Current:ToObjectSpace(self.Tip.WorldCFrame)
		Target *= Tipoffset:Inverse()
	end

	local Free = -Ray.Direction
	local Goal = if Hit then self:FindTilt(Target, Position, normal, Free) else 0
	self.Tilt += (Goal - self.Tilt) * (1 - math.exp(-Tiltsmoothing * Deltatime))
	local Body = Target:PointToWorldSpace(self.Centroid) - Position
	if Body.Magnitude > 1e-3 and self.Tilt > 1e-3 then
		local Axis, Angle = Rotation(Body.Unit, Free)
		Target = CFrame.new(Position) * CFrame.fromAxisAngle(Axis, Angle * self.Tilt) * CFrame.new(-Position) * Target
	end
	if Hit then
		Target += Smoothnormal * self:Backoff(Target, Position, Smoothnormal)
	end
	Pivotto(Toolinstance, Target)
end

return Displayedtool
