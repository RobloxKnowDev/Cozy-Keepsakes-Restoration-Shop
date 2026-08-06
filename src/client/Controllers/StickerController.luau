local Debris = game:GetService("Debris")
local Guiservice = game:GetService("GuiService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Userinputservice = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Stickercontroller = { Name = "StickerController", Priority = 9 }

local function Instancepivot(Instance: Instance?): CFrame?
	if not Instance then return nil end
	if Instance:IsA("Model") then return Instance:GetPivot() end
	if Instance:IsA("BasePart") then return Instance.CFrame end
	return nil
end

function Stickercontroller:Init()
	self.gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("PackageUi")
	self.camera = Workspace.CurrentCamera
	self.looseStickers = {}
	self:Reset()
end

function Stickercontroller:Reset()
	self.spot = nil
	self.clone = nil
	self.completed = false
	self.lockedToolPivot = nil
	if self.tensionLine then self.tensionLine:Destroy() end
	self.tensionLine = nil
end

function Stickercontroller:GetLockedToolPivot(): CFrame?
	return self.lockedToolPivot
end

function Stickercontroller:Begin(Object: Model | BasePart, Tooltip: Attachment?, Displayedtool: Instance?)
	if self.spot then return end
	self.toolTip = Tooltip
	self.displayedTool = Displayedtool
	local Mouseposition = Userinputservice:GetMouseLocation() - Guiservice:GetGuiInset()
	local Ray = self.camera:ViewportPointToRay(Mouseposition.X, Mouseposition.Y)
	local Contact = Tooltip and Tooltip.WorldCFrame or Instancepivot(Displayedtool)
	if not Contact then return end

	local Loosetargets = {}
	for Index = #self.looseStickers, 1, -1 do
		local Loose = self.looseStickers[Index]
		if Loose.Parent then table.insert(Loosetargets, Loose) else table.remove(self.looseStickers, Index) end
	end
	if #Loosetargets > 0 then
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Include
		Params.FilterDescendantsInstances = Loosetargets
		local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 100, Params)
		if Result and Result.Instance:IsA("BasePart") then
			local Loose = Result.Instance
			Loose.Anchored = true
			Loose.CanCollide = false
			Loose.CanQuery = false
			Loose.AssemblyLinearVelocity = Vector3.zero
			Loose.AssemblyAngularVelocity = Vector3.zero
			self.spot, self.clone = Loose, Loose
			self.startMouse = Userinputservice:GetMouseLocation()
			self.lastMouse = self.startMouse
			self.motion = Vector2.zero
			self.fromTool = Contact:ToObjectSpace(Loose.CFrame)
			self.completed = true
			return
		end
	end

	local Targets = {}
	local Folder = Object:FindFirstChild("RestorationSpots")
	if Folder then
		for _, Item in Folder:GetDescendants() do
			if Item:IsA("BasePart") and Item:GetAttribute("SpotKind") == "Sticker" then table.insert(Targets, Item) end
		end
	end
	if #Targets == 0 then return end
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = Targets
	local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 100, Params)
	local Spot = Result and Result.Instance
	if not Spot or not Spot:IsA("BasePart") or not Remotemanager:InvokeServer("RestorationService", "BeginPeel", Spot) then return end

	local Clone = Spot:Clone()
	local Weld = Clone:FindFirstChildOfClass("WeldConstraint")
	if Weld then Weld:Destroy() end
	Clone.Name = "PeelingSticker"
	Clone.Anchored = true
	Clone.CanCollide = false
	Clone.CanQuery = false
	Clone.CanTouch = false
	Clone.Parent = Workspace
	Spot.LocalTransparencyModifier = 1
	self.spot, self.clone = Spot, Clone
	self.startMouse = Userinputservice:GetMouseLocation()
	self.lastMouse = self.startMouse
	self.motion = Vector2.zero
	self.fromTool = Contact:ToObjectSpace(Clone.CFrame)
	self.lockedToolPivot = Instancepivot(Displayedtool)
	self.completed = false
	local Line = Instance.new("Frame")
	Line.Name = "PeelTensionLine"
	Line.AnchorPoint = Vector2.new(0.5, 0.5)
	Line.BackgroundColor3 = Color3.new(1, 1, 1)
	Line.BackgroundTransparency = 0.12
	Line.BorderSizePixel = 0
	Line.Size = UDim2.fromOffset(0, 3)
	Line.ZIndex = 100
	Line.Parent = self.gui
	self.tensionLine = Line
end

function Stickercontroller:Update()
	if not self.spot or not self.clone then return end
	local Currentmouse = Userinputservice:GetMouseLocation()
	local Mousedelta = Currentmouse - self.lastMouse
	self.lastMouse = Currentmouse
	self.motion = self.motion:Lerp(Mousedelta, 0.28)
	local Dragdistance = (Currentmouse - self.startMouse).Magnitude
	local Ratio = math.clamp(Dragdistance / 85, 0, 1)
	local Contact = self.toolTip and self.toolTip.WorldCFrame or Instancepivot(self.displayedTool)
	if Contact then
		local Flutterx = math.clamp(-self.motion.Y * 1.8, -24, 24)
		local Flutterz = math.clamp(self.motion.X * 1.6, -28, 28)
		local Wind = self.completed and math.sin(os.clock() * 13) * math.min(self.motion.Magnitude, 8) or 0
		self.clone.CFrame = Contact * self.fromTool * CFrame.Angles(math.rad(Ratio * 38 + Flutterx), math.rad(Ratio * 8 + Wind), math.rad(Ratio * 16 + Flutterz))
	end
	if self.tensionLine and self.toolTip then
		local Screen, Visible = self.camera:WorldToViewportPoint(self.toolTip.WorldPosition)
		local Mouse = Userinputservice:GetMouseLocation()
		if not self.gui.IgnoreGuiInset then Mouse -= Guiservice:GetGuiInset() end
		local Tip = Vector2.new(Screen.X, Screen.Y)
		local Delta = Mouse - Tip
		self.tensionLine.Visible = Visible and Dragdistance > 10
		self.tensionLine.Position = UDim2.fromOffset((Mouse.X + Tip.X) * 0.5, (Mouse.Y + Tip.Y) * 0.5)
		self.tensionLine.Size = UDim2.fromOffset(Delta.Magnitude, 3)
		self.tensionLine.Rotation = math.deg(math.atan2(Delta.Y, Delta.X))
	end
	if not self.completed and Dragdistance >= 85 then
		self.completed = true
		self.lockedToolPivot = nil
		if self.tensionLine then self.tensionLine:Destroy() end
		self.tensionLine = nil
		Remotemanager:FireServer("RestorationService", "CompletePeel", self.spot)
	end
end

function Stickercontroller:Release()
	local Spot, Clone, Completed = self.spot, self.clone, self.completed
	self:Reset()
	if not Spot or not Clone then return end
	Clone.Anchored = false
	Clone.CanCollide = true
	Clone.CanTouch = true
	Clone.Massless = false
	Clone.AssemblyLinearVelocity = self.camera.CFrame.LookVector * 1.5 + Vector3.new(0, -0.6, 0)
	Clone.AssemblyAngularVelocity = Vector3.new(math.random() * 4, math.random() * 3, math.random() * 4)
	if Completed then
		Clone:SetAttribute("LooseSticker", true)
		Clone.CanQuery = true
		if not table.find(self.looseStickers, Clone) then table.insert(self.looseStickers, Clone) end
	else
		Debris:AddItem(Clone, 2)
		task.delay(0.9, function()
			if Spot.Parent then Spot.LocalTransparencyModifier = 0 end
			Remotemanager:FireServer("RestorationService", "CancelPeel", Spot)
		end)
	end
end

return Stickercontroller
