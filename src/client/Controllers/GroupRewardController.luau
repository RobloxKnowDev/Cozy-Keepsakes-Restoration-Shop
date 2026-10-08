local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Config = require(ReplicatedStorage.Shared.Config.FreeReward)
local Rarityconfig = require(ReplicatedStorage.Shared.Config.Rarity)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Icon = require(ReplicatedStorage.Shared:WaitForChild("Utils"):WaitForChild("Icon"))
local Shared = require(script.Parent.ComputerController.Apps.Shared)

local GroupRewardController = {
	Name = "GroupRewardController",
	Priority = 8.55,
	topbarImage = "rbxassetid://107150542972325",
}

local Player = Players.LocalPlayer
local OpenTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local CloseTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local FastCloseTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local ClaimedText = "Claimed"
local JoinText = "Join the group to claim your reward!"
local PendingText = "Your join request is pending"
local FailedText = "Unable to claim free reward"
local ErrorGradient = Rarityconfig.Mythic.Gradient

function GroupRewardController:IsOpen(): boolean
	return self.isOpen == true
end

function GroupRewardController:IsClaimed(): boolean
	return self.claimedLocally or Player:GetAttribute("FreeRewardClaimed") == true
end

function GroupRewardController:RefreshClaim()
	Shared.SetTopbarNotice(self.topbarIcon, Player:GetAttribute("FreeRewardClaimed") == false and not self.claimedLocally)
	if self:IsClaimed() then
		self.cooldownEnd = nil
		self.claimCover.Visible = true
		self.claimText.Text = ClaimedText
		return
	end
	local Remaining = if self.cooldownEnd then math.ceil(self.cooldownEnd - os.clock()) else 0
	if Remaining > 0 then
		self.claimCover.Visible = true
		self.claimText.Text = string.format("%ds", Remaining)
		return
	end
	self.cooldownEnd = nil
	self.claimCover.Visible = false
end

function GroupRewardController:Open()
	if self:IsOpen() then
		return
	end
	Core:GetController("SettingController"):CloseForSwitch()
	Core:GetController("DailyRewardController"):CloseForSwitch()
	Core:GetController("DonationController"):CloseForSwitch()
	local ComputerController = Core:GetController("ComputerController")
	local CustomerController = Core:GetController("CustomerController")
	local ExpositionController = Core:GetController("ExpositionController")
	if ComputerController:IsOpen() then ComputerController:Close() end
	if CustomerController:IsVisible() then CustomerController:CloseOfferUi(true) end
	if ExpositionController:IsSelectionOpen() then ExpositionController:CloseSelectionFrame(false, true) end
	self.isOpen = true
	self:RefreshClaim()
	if self.positionTween then self.positionTween:Cancel() end
	if self.scaleTween then self.scaleTween:Cancel() end
	self.frame.Position = self.framePosition + UDim2.fromOffset(0, 20)
	self.frameScale.Scale = 0.94
	self.frame.Visible = true
	self.positionTween = TweenService:Create(self.frame, OpenTweenInfo, { Position = self.framePosition })
	self.scaleTween = TweenService:Create(self.frameScale, OpenTweenInfo, { Scale = 1 })
	self.positionTween:Play()
	self.scaleTween:Play()
end

function GroupRewardController:Close(Fast: boolean?)
	if not self:IsOpen() then return end
	self.isOpen = false
	if self.positionTween then self.positionTween:Cancel() end
	if self.scaleTween then self.scaleTween:Cancel() end
	local TweenInfoValue = if Fast then FastCloseTweenInfo else CloseTweenInfo
	self.positionTween = TweenService:Create(self.frame, TweenInfoValue, {
		Position = self.framePosition + UDim2.fromOffset(0, 20),
	})
	self.scaleTween = TweenService:Create(self.frameScale, TweenInfoValue, { Scale = 0.94 })
	local PositionTween = self.positionTween
	PositionTween:Play()
	self.scaleTween:Play()
	PositionTween.Completed:Once(function(State)
		if self.positionTween ~= PositionTween or State ~= Enum.PlaybackState.Completed then return end
		self.frame.Visible = false
		self.frame.Position = self.framePosition
		self.frameScale.Scale = 1
		self.positionTween = nil
		self.scaleTween = nil
		Core:GetController("RestorationController"):ResumePendingEnter()
	end)
end

function GroupRewardController:CloseForSwitch()
	self:Close(true)
	self.topbarIcon:deselect()
end

function GroupRewardController:ClaimReward()
	self.busy = true
	local Success, Result = pcall(function()
		return RemoteManager:InvokeServer("FreeRewardService", "ClaimFreeReward")
	end)
	self.busy = false
	if Success and type(Result) == "table" and (Result.Success == true or Result.Reason == "Claimed") then
		self.claimedLocally = true
		self:RefreshClaim()
		return
	end
	if Success and type(Result) == "table" and Result.Reason == "NotInGroup" then
		self.joined = false
		Core:GetController("MessageController"):Show(JoinText, ErrorGradient)
		return
	end
	Core:GetController("MessageController"):Show(FailedText, ErrorGradient)
end

function GroupRewardController:PressClaim()
	if self.busy or self.cooldownEnd or self:IsClaimed() or Player:GetAttribute("FreeRewardClaimed") == nil then
		return
	end
	if self.joined then
		self:ClaimReward()
		return
	end
	self.busy = true
	local Member = false
	pcall(function()
		Member = Player:IsInGroup(Config.GroupId)
	end)
	if Member then
		self.busy = false
		self.joined = true
		self:ClaimReward()
		return
	end
	local Success, Status = pcall(function()
		return GroupService:PromptJoinAsync(Config.GroupId)
	end)
	self.busy = false
	if not Success then
		return
	end
	if Status == Enum.GroupMembershipStatus.AlreadyMember then
		self.joined = true
		self:ClaimReward()
	elseif Status == Enum.GroupMembershipStatus.Joined then
		self.joined = true
		self.cooldownEnd = os.clock() + Config.CooldownSeconds
		self:RefreshClaim()
	elseif Status == Enum.GroupMembershipStatus.JoinRequestPending then
		Core:GetController("MessageController"):Show(PendingText, ErrorGradient)
	end
end

function GroupRewardController:Init()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	self.ui = PlayerGui:WaitForChild("FreeRewardUi")
	self.frame = self.ui:WaitForChild("Frame")
	self.claimButton = self.frame:WaitForChild("ClaimButton")
	self.claimCover = self.claimButton:WaitForChild("Frame")
	self.claimText = self.claimCover:WaitForChild("Text")
	self.closeButton = self.frame:WaitForChild("CloseButton")
	self.isOpen = false
	self.busy = false
	self.joined = false
	self.claimedLocally = false
	self.cooldownEnd = nil
	self.framePosition = self.frame.Position
	self.frameScale = Shared.EnsureScale(self.frame)
	self.frame.Visible = false
	self.frame.Active = true
	self.claimCover.Visible = false

	self.topbarIcon = Icon.new()
		:setName("FreeReward")
		:setImage(self.topbarImage)
		:modifyTheme({ "IconImage", "ImageColor3", Color3.fromRGB(255, 255, 255) })
		:modifyTheme({ "IconImage", "ScaleType", Enum.ScaleType.Fit })
		:setCaption("Free Reward")
	self.topbarIcon.selected:Connect(function() self:Open() end)
	self.topbarIcon.deselected:Connect(function() self:Close() end)
	Shared.AnimateButton(self.claimButton, function() return false end)
	Shared.AnimateButton(self.closeButton, function() return false end)
	local Gamepad = Core:GetController("GamepadController")
	Gamepad:OnActivated(self.claimButton, function()
		task.spawn(self.PressClaim, self)
	end)
	Gamepad:OnActivated(self.closeButton, function() self.topbarIcon:deselect() end)
	Gamepad:RegisterMenu({
		Priority = 25,
		IsOpen = function()
			return self:IsOpen()
		end,
		Close = function()
			self.topbarIcon:deselect()
		end,
	})
end

function GroupRewardController:Start()
	Player:GetAttributeChangedSignal("FreeRewardClaimed"):Connect(function()
		self:RefreshClaim()
	end)
	RunService.Heartbeat:Connect(function()
		if self.cooldownEnd then
			self:RefreshClaim()
		end
	end)
	task.spawn(function()
		while true do
			self:RefreshClaim()
			task.wait(1)
		end
	end)
end

return GroupRewardController
