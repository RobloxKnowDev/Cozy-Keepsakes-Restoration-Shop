local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Hudcustomercontroller = {
	Name = "HudCustomerController",
	Priority = 1,
}

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
	self.cameraPart = Workspace:WaitForChild("CamPart") :: BasePart

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

return Hudcustomercontroller
