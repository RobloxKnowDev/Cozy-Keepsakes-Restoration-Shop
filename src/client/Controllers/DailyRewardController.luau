local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Icon = require(ReplicatedStorage.Shared:WaitForChild("Utils"):WaitForChild("Icon"))
local Config = require(ReplicatedStorage.Shared.Config.DailyRewards)
local Core = require(ReplicatedStorage.Shared.Packages.Core)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.ComputerController.Apps.Shared)

local DailyRewardController = {
	Name = "DailyRewardController",
	Priority = 8.5,
}

local Player = Players.LocalPlayer
local ErrorColor = Color3.fromRGB(255, 138, 138)
local OpenTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local CloseTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local FastCloseTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

local function FormatTime(Seconds: number): string
	local Total = math.max(math.ceil(Seconds), 0)
	local Hours = math.floor(Total / 3600)
	local Minutes = math.floor(Total % 3600 / 60)
	return string.format("%02d:%02d:%02d", Hours, Minutes, Total % 60)
end

function DailyRewardController:IsRewardAvailable(): boolean
	if not self.state or self.state.CurrentDay <= 0 then return false end
	return self.state.ClaimedDays == 0 or workspace:GetServerTimeNow() >= self.state.NextClaimAt
end

function DailyRewardController:IsOpen(): boolean
	return self.isOpen == true
end

function DailyRewardController:CanOpen(): boolean
	return not self:IsOpen()
		and not Core:GetController("RestorationController"):IsEditingObject()
		and not Core:GetController("CompletionController"):IsVisible()
end

function DailyRewardController:DeselectOtherTopbarIcons()
	for _, OtherIcon in pairs(Icon.getIcons()) do
		if OtherIcon ~= self.topbarIcon then OtherIcon:deselect() end
	end
end

function DailyRewardController:Refresh()
	if not self.state then return end
	local ClaimedDays = self.state.ClaimedDays
	local CurrentDay = self.state.CurrentDay
	local Available = self:IsRewardAvailable()
	for Day, Card in ipairs(self.days) do
		local Claimed = Day <= ClaimedDays
		local IsCurrent = Day == CurrentDay
		Card.ClaimedFrame.Visible = Claimed
		if Claimed then
			Card.Text.Text = "CLAIMED"
		elseif IsCurrent and Available then
			Card.Text.Text = "CLAIM"
		elseif IsCurrent then
			Card.Text.Text = "SKIP"
		else
			Card.Text.Text = "LOCKED"
		end
		local Enabled = IsCurrent and (Available or self.state.SkipProductId > 0)
		Card.Button.Active = Enabled
		Card.Button.Interactable = Enabled
		Card.Button.AutoButtonColor = Enabled
	end

	local Remaining = self.state.NextClaimAt - workspace:GetServerTimeNow()
	self.timerText.Text = if CurrentDay > 0 and Available then "AVAILABLE NOW" else FormatTime(Remaining)
end

function DailyRewardController:ApplyState(State)
	if not State then return end
	self.state = State
	self:Refresh()
	Core:GetController("BoostController"):SetBoost("DailySaleBoost", self.saleBoostIcon, State.SaleBoostEndsAt, 3)
end

function DailyRewardController:Open()
	if not self:CanOpen() then
		self.topbarIcon:deselect()
		return
	end
	Core:GetController("SettingController"):CloseForSwitch()
	self:DeselectOtherTopbarIcons()
	local ComputerController = Core:GetController("ComputerController")
	local CustomerController = Core:GetController("CustomerController")
	local ExpositionController = Core:GetController("ExpositionController")
	if ComputerController:IsOpen() then ComputerController:Close() end
	if CustomerController:IsVisible() then CustomerController:CloseOfferUi(true) end
	if ExpositionController:IsSelectionOpen() then ExpositionController:CloseSelectionFrame(false, true) end
	self.isOpen = true
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

function DailyRewardController:Close(Fast: boolean?)
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

function DailyRewardController:CloseForSwitch()
	self:Close(true)
	self.topbarIcon:deselect()
end

function DailyRewardController:StartObjectReward()
	self:Close()
	self.topbarIcon:deselect()
	Core:GetController("RestorationController"):Enter()
end

function DailyRewardController:Claim()
	if self.processing then return end
	self.processing = true
	local Success, Result = pcall(function()
		return RemoteManager:InvokeServer("DailyRewardService", "ClaimReward")
	end)
	self.processing = false
	if not Success then
		Core:GetController("MessageController"):Show("Unable to claim daily reward", ErrorColor)
		return
	end
	if Result and Result.State then self:ApplyState(Result.State) end
	if Result and Result.Success then
		self.days[Result.Day].ClaimedFrame.Visible = true
		self.days[Result.Day].Text.Text = "CLAIMED"
		Core:GetController("FeedbackController"):Success(self.days[Result.Day].ClaimedFrame, Result.RewardType == "Object")
		Core:GetController("FeedbackController"):FloatingText(self.frame, "REWARD CLAIMED", Color3.fromRGB(255, 214, 122))
		Core:GetController("FeedbackController"):PlaySound("DailyReward", 0.2)
		if Result.RewardType == "Object" and Result.ObjectReady then self:StartObjectReward() end
	end
end

function DailyRewardController:Skip()
	local ProductId = tonumber(self.state.SkipProductId) or 0
	if ProductId <= 0 then
		Core:GetController("MessageController"):Show("Daily reward skip product is not configured", ErrorColor)
		return
	end
	MarketplaceService:PromptProductPurchase(Player, ProductId)
end

function DailyRewardController:ActivateDay(Day: number)
	if not self.state or Day ~= self.state.CurrentDay then return end
	if self:IsRewardAvailable() then
		self:Claim()
	else
		self:Skip()
	end
end

function DailyRewardController:Init()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	self.ui = PlayerGui:WaitForChild("DailyRewardUi")
	self.frame = self.ui:WaitForChild("Frame")
	self.exitButton = self.frame:WaitForChild("ExitButton")
	self.timerText = self.frame:WaitForChild("TimerText")
	self.days = {}
	self.processing = false
	self.isOpen = false
	self.framePosition = self.frame.Position
	self.frameScale = Shared.EnsureScale(self.frame)
	self.frame.Visible = false

	for Day, Reward in ipairs(Config.Rewards) do
		local DayFrame = self.frame:WaitForChild("Day" .. Day)
		local Button = DayFrame:WaitForChild("ClaimedButton")
		local Card = {
			Button = Button,
			ClaimedFrame = DayFrame:WaitForChild("ClaimedFrame"),
			Text = Button:WaitForChild("Text"),
		}
		DayFrame:WaitForChild("DayText").Text = "DAY " .. Day
		DayFrame:WaitForChild("ValueText").Text = Reward.ValueText
		self.days[Day] = Card
		Shared.AnimateButton(Button, function() return not Button.Active end)
		Button.Activated:Connect(function() self:ActivateDay(Day) end)
	end

	self.saleBoostIcon = self.frame:WaitForChild("Day4"):WaitForChild("Icon").Image
	self.topbarIcon = Icon.new()
		:setName("DailyRewards")
		:setImage("rbxassetid://72059845719520")
		:modifyTheme({ "IconImage", "ImageColor3", Color3.fromRGB(255, 255, 255) })
		:setCaption("Daily Rewards")
	self.topbarIcon.selected:Connect(function() self:Open() end)
	self.topbarIcon.deselected:Connect(function() self:Close() end)
	Shared.AnimateButton(self.exitButton, function() return false end)
	self.exitButton.Activated:Connect(function() self.topbarIcon:deselect() end)
	self:ApplyState(RemoteManager:InvokeServer("DailyRewardService", "GetState"))
end

function DailyRewardController:Start()
	RemoteManager:OnClientEvent("DailyRewardService", "StateUpdated", function(State)
		self:ApplyState(State)
	end)
	RemoteManager:OnClientEvent("DailyRewardService", "ObjectRewardReady", function()
		self:StartObjectReward()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			self:Refresh()
		end
	end)
end

return DailyRewardController
