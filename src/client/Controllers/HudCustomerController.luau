local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Customerconfig = require(Replicatedstorage.Shared.Config.Customer)
local Monetizationconfig = require(Replicatedstorage.Shared.Config.Monetization)
local Rarityconfig = require(Replicatedstorage.Shared.Config.Rarity)
local Formatduration = require(Replicatedstorage.Shared.Utils.DurationFormatter)
local Uifade = require(Replicatedstorage.Shared.Utils.UiFade)

local Hudcustomercontroller = {
	Name = "HudCustomerController",
	Priority = 1,
	hudVisible = true,
	pendingSkips = 0,
}

local Player = Players.LocalPlayer
local Barmaxscale = 0.862
local Robuxicon = "\u{E002}"
local Skipsavedgradient = Rarityconfig.Common.Gradient

local function Loadskipprice(Robuxtext: TextLabel)
	Robuxtext.Text = "..."
	task.spawn(function()
		local Success, Productinfo = pcall(function()
			return MarketplaceService:GetProductInfoAsync(Monetizationconfig.SkipCooldownProductId, Enum.InfoType.Product)
		end)
		local Price = if Success then tonumber(Productinfo.PriceInRobux) else nil
		Robuxtext.Text = if Price then string.format("%s%d", Robuxicon, math.floor(Price)) else "N/A"
	end)
end

function Hudcustomercontroller:UpdateCustomerText()
	local Current = Player:GetAttribute("CustomersToday") or 0
	local Maximum = Player:GetAttribute("MaxCustomersPerDay") or 0
	self.customerText.Text = string.format("%d/%d", Current, Maximum)
end

function Hudcustomercontroller:UpdateTimer()
	local Target = Player:GetAttribute("NextCustomerAt") or 0
	local Remaining = Target - Workspace:GetServerTimeNow()
	local Active = Target > 0 and Remaining > 0
	local Canskip = Monetizationconfig.SkipCooldownProductId > 0 and Remaining > Customerconfig.GetSkipThreshold()
	self.cooldownFrame.Visible = self.hudVisible and Active
	Uifade.SetVisible(self.cooldownBar, Active)
	Uifade.SetVisible(self.nextText, Active)
	if Uifade.SetVisible(self.skipButton, Canskip) and Canskip then
		Uifade.Pop(self.skipButton)
	end
	Uifade.SetVisible(self.skipRobuxText, Canskip)
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
	self.skipButton = self.cooldownFrame:WaitForChild("SkipButton") :: GuiButton
	self.skipRobuxText = self.skipButton:WaitForChild("RobuxText") :: TextLabel
	self.cooldownBarSize = self.cooldownBar.Size

	Loadskipprice(self.skipRobuxText)
	Uifade.BindButton(self.skipButton)
	Core:GetController("GamepadController"):OnActivated(self.skipButton, function()
		MarketplaceService:PromptProductPurchase(Player, Monetizationconfig.SkipCooldownProductId)
	end)

	Player:GetAttributeChangedSignal("CustomersToday"):Connect(function()
		self:UpdateCustomerText()
	end)
	Player:GetAttributeChangedSignal("MaxCustomersPerDay"):Connect(function()
		self:UpdateCustomerText()
	end)
	self.pendingSkips = Player:GetAttribute("PendingSkips") or 0
	Player:GetAttributeChangedSignal("PendingSkips"):Connect(function()
		local Pending = Player:GetAttribute("PendingSkips")
		if Pending > self.pendingSkips then
			Core:GetController("MessageController"):Show("Skip saved for your next customer!", Skipsavedgradient)
		end
		self.pendingSkips = Pending
	end)

	self:UpdateCustomerText()
end

function Hudcustomercontroller:Start()
	Runservice.Heartbeat:Connect(function()
		self:UpdateTimer()
	end)
end

return Hudcustomercontroller
