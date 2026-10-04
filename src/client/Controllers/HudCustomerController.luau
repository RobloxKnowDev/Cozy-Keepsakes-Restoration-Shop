local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Customerconfig = require(Replicatedstorage.Shared.Config.Customer)
local Formatduration = require(Replicatedstorage.Shared.Utils.DurationFormatter)
local Uifade = require(Replicatedstorage.Shared.Utils.UiFade)

local Hudcustomercontroller = {
	Name = "HudCustomerController",
	Priority = 1,
	hudVisible = true,
}

local Player = Players.LocalPlayer
local Barmaxscale = 0.862

function Hudcustomercontroller:UpdateCustomerText()
	local Current = Player:GetAttribute("CustomersToday") or 0
	local Maximum = Player:GetAttribute("MaxCustomersPerDay") or 0
	self.customerText.Text = string.format("%d/%d", Current, Maximum)
end

function Hudcustomercontroller:UpdateTimer()
	local Target = Player:GetAttribute("NextCustomerAt") or 0
	local Remaining = Target - Workspace:GetServerTimeNow()
	local Active = Target > 0 and Remaining > 0
	self.cooldownFrame.Visible = self.hudVisible and Active
	Uifade.SetVisible(self.cooldownBar, Active)
	Uifade.SetVisible(self.nextText, Active)
	if not Active then
		return
	end
	local Interval = math.max(Player:GetAttribute("CustomerInterval") or Customerconfig.SpawnIntervalSeconds, 1)
	local Ratio = math.clamp(Remaining / Interval, 0, 1)
	self.cooldownBar.Size =
		UDim2.new(Ratio * Barmaxscale, 0, self.cooldownBarSize.Y.Scale, self.cooldownBarSize.Y.Offset)
	self.nextText.Text = "Next Customer in " .. Formatduration(Remaining)
end

function Hudcustomercontroller:SetHudVisible(Visible: boolean)
	self.hudVisible = Visible
	self:UpdateTimer()
end

function Hudcustomercontroller:Init()
	local Playergui = Player:WaitForChild("PlayerGui")
	local Hud = Playergui:WaitForChild("HUD")
	self.cooldownFrame = Hud:WaitForChild("CooldownFrame") :: GuiObject
	self.cooldownBar = self.cooldownFrame:WaitForChild("Bar") :: GuiObject
	self.customerText = self.cooldownFrame:WaitForChild("CustomerText") :: TextLabel
	self.nextText = self.cooldownFrame:WaitForChild("NextText") :: TextLabel
	self.cooldownBarSize = self.cooldownBar.Size

	Player:GetAttributeChangedSignal("CustomersToday"):Connect(function()
		self:UpdateCustomerText()
	end)
	Player:GetAttributeChangedSignal("MaxCustomersPerDay"):Connect(function()
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
