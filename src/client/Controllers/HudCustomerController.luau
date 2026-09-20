local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Customerconfig = require(Replicatedstorage.Shared.Config.Customer)
local Uifade = require(Replicatedstorage.Shared.Utils.UiFade)

local Hudcustomercontroller = {
	Name = "HudCustomerController",
	Priority = 1,
}

local Barmaxscale = 0.862

local function Formatcountdown(Seconds: number): string
	local Total = math.max(math.ceil(Seconds), 0)
	return string.format("%d:%02d", math.floor(Total / 60), Total % 60)
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
	Uifade.SetVisible(self.cooldownBar, Active)
	Uifade.SetVisible(self.nextText, Active)
	if not Active then
		return
	end
	local Interval = math.max(Lighting:GetAttribute("CustomerInterval") or Customerconfig.SpawnIntervalSeconds, 1)
	local Ratio = math.clamp(Remaining / Interval, 0, 1)
	self.cooldownBar.Size =
		UDim2.new(Ratio * Barmaxscale, 0, self.cooldownBarSize.Y.Scale, self.cooldownBarSize.Y.Offset)
	self.nextText.Text = "Next Customer in " .. Formatcountdown(Remaining)
end

function Hudcustomercontroller:Init()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local Hud = Playergui:WaitForChild("HUD")
	local Cooldownframe = Hud:WaitForChild("CooldownFrame")
	self.cooldownBar = Cooldownframe:WaitForChild("Bar") :: GuiObject
	self.customerText = Cooldownframe:WaitForChild("CustomerText") :: TextLabel
	self.nextText = Cooldownframe:WaitForChild("NextText") :: TextLabel
	self.cooldownBarSize = self.cooldownBar.Size

	Lighting:GetAttributeChangedSignal("CustomersToday"):Connect(function()
		self:UpdateCustomerText()
	end)
	Lighting:GetAttributeChangedSignal("MaxCustomersPerDay"):Connect(function()
		self:UpdateCustomerText()
	end)

	self:UpdateCustomerText()
end

function Hudcustomercontroller:Start()
	Runservice.Heartbeat:Connect(function()
		self:UpdateTimer()
	end)
end

return Hudcustomercontroller
