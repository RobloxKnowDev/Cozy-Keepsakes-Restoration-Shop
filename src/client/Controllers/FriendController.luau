local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local BoostConfig = require(ReplicatedStorage.Shared.Config.Boosts)
local Icon = require(ReplicatedStorage.Shared:WaitForChild("Utils"):WaitForChild("Icon"))

local FriendController = {
	Name = "FriendController",
	Priority = 8.66,
}

local Config = BoostConfig.FriendBoost

function FriendController:Invite()
	local Player = Players.LocalPlayer
	local Success, CanInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, Player)
	if not Success or not CanInvite then
		Core:GetController("MessageController"):Show("Invites are not available right now")
		return
	end
	SocialService:PromptGameInvite(Player)
end

function FriendController:Apply()
	local Count = Players.LocalPlayer:GetAttribute("Friends") or 0
	local BoostController = Core:GetController("BoostController")
	BoostController:SetPermanentBoost(
		"FriendBoost",
		5,
		string.format("+%g%%", Count * Config.SellPercent),
		"+{1}% on all sales per friend in your server",
		string.format("%g", Config.SellPercent)
	)
	if Count > self.count then
		BoostController:PlayGain("FriendBoost", true)
	end
	self.count = Count
end

function FriendController:Start()
	self.count = Players.LocalPlayer:GetAttribute("Friends") or 0
	self:Apply()
	Players.LocalPlayer:GetAttributeChangedSignal("Friends"):Connect(function()
		self:Apply()
	end)
	Core:GetController("BoostController"):OnClick("FriendBoost", function()
		Core:GetController("FeedbackController"):UiClick()
		task.spawn(self.Invite, self)
	end)
	self.topbarIcon = Icon.new()
		:setName("Invite")
		:setImage(Config.Icon)
		:modifyTheme({ "IconImage", "ImageColor3", Color3.fromRGB(255, 255, 255) })
		:modifyTheme({ "IconImage", "ScaleType", Enum.ScaleType.Fit })
		:setLabel("Invite")
		:setCaption("Invite Friends")
		:align("Right")
		:oneClick(true)
		:autoDeselect(false)
	self.topbarIcon.selected:Connect(function()
		task.spawn(self.Invite, self)
	end)
end

return FriendController
