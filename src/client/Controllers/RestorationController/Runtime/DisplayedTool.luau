local Guiservice = game:GetService("GuiService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Userinputservice = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Toolassets = Replicatedstorage:WaitForChild("Asset"):WaitForChild("Tool")

local Displayedtool = {}
Displayedtool.__index = Displayedtool

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

function Displayedtool.new()
	return setmetatable({ Camera = Workspace.CurrentCamera, Stroke = 0, OnObject = false }, Displayedtool)
end

function Displayedtool:Destroy()
	if self.Instance then self.Instance:Destroy() end
	self.Instance, self.Tip, self.Definition = nil, nil, nil
	self.HitInstance, self.SurfacePosition, self.SurfaceNormal = nil, nil, nil
	self.OnObject = false
end

function Displayedtool:Select(Definition)
	self:Destroy()
	self.Definition = Definition
	if not Definition.AssetName then return end

	local Toolinstance = Toolassets:WaitForChild(Definition.AssetName):Clone()
	Toolinstance.Name = "Displayed" .. Definition.Name
	self.Instance = Toolinstance
	local Tipparts = {}
	for _, Descendant in ipairs(Toolinstance:GetDescendants()) do
		if Descendant:IsA("BasePart") then
			Descendant.Anchored = true
			Descendant.CanCollide, Descendant.CanQuery, Descendant.CanTouch = false, false, false
			Descendant.CastShadow = false
			if Definition.UsesCenteredTip and string.find(string.lower(Descendant.Name), "tip", 1, true) then
				table.insert(Tipparts, Descendant)
			end
		elseif Descendant:IsA("Attachment") and Descendant.Name == "Tip" then
			self.Tip = Descendant
		end
	end
	if Toolinstance:IsA("BasePart") then
		Toolinstance.Anchored = true
		Toolinstance.CanCollide, Toolinstance.CanQuery, Toolinstance.CanTouch = false, false, false
		Toolinstance.CastShadow = false
		self.Tip = Toolinstance:FindFirstChild("Tip") or self.Tip
	end
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

function Displayedtool:Update(Deltatime: number, Object: Model | BasePart, Isusing: boolean, Lockedpivot: CFrame?)
	local Toolinstance, Definition = self.Instance, self.Definition
	if not Toolinstance or not Definition then return end
	if Lockedpivot then Pivotto(Toolinstance, Lockedpivot) return end

	local Mouse = Userinputservice:GetMouseLocation() - Guiservice:GetGuiInset()
	local Ray = self.Camera:ViewportPointToRay(Mouse.X, Mouse.Y)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Object }
	local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 100, Params)
	self.OnObject = Result ~= nil
	self.HitInstance = Result and Result.Instance or nil

	local Position, normal
	if Result then
		Position, normal = Result.Position, Result.Normal
	else
		local Objectpivot = Object:IsA("Model") and Object:GetPivot() or Object.CFrame
		local Planenormal = self.Camera.CFrame.LookVector
		local Denominator = Ray.Direction:Dot(Planenormal)
		local Distance = (Objectpivot.Position - Ray.Origin):Dot(Planenormal) / Denominator
		Position, normal = Ray.Origin + Ray.Direction * math.max(Distance, 1), -Planenormal
	end
	self.SurfacePosition = Position
	self.SurfaceNormal = normal

	local Pulling = Definition.UsesPullMotion == true
	local Touching = Isusing and self.OnObject
	self.Stroke += Deltatime * (Touching and (Pulling and 10 or 24) or 5)
	local Stroke = Touching and not Pulling and math.sin(self.Stroke) * 0.045 or 0
	local Pull = Touching and Pulling and (0.08 + (math.sin(self.Stroke) + 1) * 0.09) or 0
	local Contact = Position + normal * (0.006 + Pull) + self.Camera.CFrame.RightVector * Stroke
	local Target
	if Definition.GetDisplayCFrame then
		Target = Definition.GetDisplayCFrame({
			Object = Object,
			SurfacePosition = Position,
			SurfaceNormal = normal,
			Camera = self.Camera,
			IsUsing = Isusing,
			DeltaTime = Deltatime,
		})
	else
		Target = CFrame.lookAt(Contact, Contact + normal, self.Camera.CFrame.UpVector)
			* (Definition.DisplayRotation or CFrame.identity)
	end
	local Current = Pivotof(Toolinstance)
	if Current and self.Tip then Target *= Current:ToObjectSpace(self.Tip.WorldCFrame):Inverse() end
	Pivotto(Toolinstance, Target)
end

return Displayedtool
