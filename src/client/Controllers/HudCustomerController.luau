local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Customerconfig = require(Replicatedstorage.Shared.Config.Customer)

local Hudcustomercontroller = {
	Name = "HudCustomerController",
	Priority = 1,
}

local Barmaxscale = 0.862

local function Formatcountdown(Seconds: number): string
	local Total = math.max(math.ceil(Seconds), 0)
	return string.format("%d:%02d", math.floor(Total / 60), Total % 60)
end

function Hudcustomercontroller:IsCustomerCameraActive(): boolean
	local Camera = Workspace.CurrentCamera
	return Camera ~= nil
		and (Camera.CFrame.Position - self.cameraPart.Position).Magnitude < 0.05
end

function Hudcustomercontroller:UpdateVisibility()
	if not self.customerFrame then
		return
	end

	self.customerFrame.Visible = self:IsCustomerCameraActive()
end

function Hudcustomercontroller:UpdateCustomerText()
	local Current = Lighting:GetAttribute("CustomersToday") or 0
	local Maximum = Lighting:GetAttribute("MaxCustomersPerDay") or 0
	self.customerText.Text = string.format("%d/%d", Current, Maximum)
end

function Hudcustomercontroller:UpdateTimer()
	local Target = Lighting:GetAttribute("NextCustomerAt") or 0
	local Remaining = Target - Workspace:GetServerTimeNow()
	local Active = Target > 0
	self.cooldownFrame.Visible = Active and self:IsCustomerCameraActive()
	if not Active then
		return
	end
	local Interval = math.max(Lighting:GetAttribute("CustomerInterval") or Customerconfig.SpawnIntervalSeconds, 1)
	local Ratio = math.clamp(Remaining / Interval, 0, 1)
	self.cooldownBar.Size =
		UDim2.new(Ratio * Barmaxscale, 0, self.cooldownBarSize.Y.Scale, self.cooldownBarSize.Y.Offset)
	self.cooldownText.Text = "Next Customer in " .. Formatcountdown(Remaining)
end

function Hudcustomercontroller:BindCamera(Camera: Camera?)
	if self.cameraCFrameConnection then
		self.cameraCFrameConnection:Disconnect()
		self.cameraCFrameConnection = nil
	end

	if Camera then
		self.cameraCFrameConnection = Camera:GetPropertyChangedSignal("CFrame"):Connect(function()
			self:UpdateVisibility()
		end)
	end

	self:UpdateVisibility()
end

function Hudcustomercontroller:Init()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local Hud = Playergui:WaitForChild("HUD")
	self.customerFrame = Hud:WaitForChild("CustomerFrame") :: GuiObject
	self.customerText = self.customerFrame:WaitForChild("CustomerText") :: TextLabel
	self.cooldownFrame = Hud:WaitForChild("CooldownFrame") :: GuiObject
	self.cooldownBar = self.cooldownFrame:WaitForChild("Bar") :: GuiObject
	self.cooldownText = self.cooldownFrame:WaitForChild("Text") :: TextLabel
	self.cooldownBarSize = self.cooldownBar.Size
	self.cooldownFrame.Visible = false
	self.cameraPart = Workspace:WaitForChild("Map"):WaitForChild("Slot1"):WaitForChild("Camera"):WaitForChild("CamPart") :: BasePart

	Lighting:GetAttributeChangedSignal("CustomersToday"):Connect(function()
		self:UpdateCustomerText()
	end)
	Lighting:GetAttributeChangedSignal("MaxCustomersPerDay"):Connect(function()
		self:UpdateCustomerText()
	end)

	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self:BindCamera(Workspace.CurrentCamera)
	end)

	self:UpdateCustomerText()
	self:BindCamera(Workspace.CurrentCamera)
end

function Hudcustomercontroller:Start()
	Runservice.Heartbeat:Connect(function()
		self:UpdateTimer()
	end)
end

return Hudcustomercontroller
