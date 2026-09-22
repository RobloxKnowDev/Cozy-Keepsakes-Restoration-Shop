local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Icon = require(ReplicatedStorage.Shared:WaitForChild("Utils"):WaitForChild("Icon"))
local Config = require(ReplicatedStorage.Shared.Config.DailyRewards)
local Core = require(ReplicatedStorage.Shared.Packages.Core)
local FormatDuration = require(ReplicatedStorage.Shared.Utils.DurationFormatter)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.ComputerController.Apps.Shared)

local DailyRewardController = {
	Name = "DailyRewardController",
	Priority = 8.5,
}

local Player = Players.LocalPlayer
local ErrorColor = Color3.fromRGB(255, 0, 4)
local ClaimColor = Color3.fromRGB(255, 214, 122)
local OpenTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local CloseTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local FastCloseTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local SwingTweenInfo = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local ButtonTweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HopCrouchTweenInfo = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HopRiseTweenInfo = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HopFallTweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HopLandTweenInfo = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HopSettleTweenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HopSequence = {
	{ Scale = 0.95, Offset = 2, Info = HopCrouchTweenInfo, Wait = 0.09 },
	{ Scale = 1.04, Offset = -12, Info = HopRiseTweenInfo, Wait = 0.14 },
	{ Scale = 1, Offset = 0, Info = HopFallTweenInfo, Wait = 0.12 },
	{ Scale = 0.97, Offset = 2, Info = HopLandTweenInfo, Wait = 0.07 },
	{ Scale = 1, Offset = 0, Info = HopSettleTweenInfo, Wait = 0.16 },
}
local HopRestTime = 2.2
local HopRestVariance = 2.4
local HoverScale = 1.06
local PressScale = 0.96
local SwingRotation = 5
local ReadyText = "Time !"
local CompleteText = "Complete !"

local function CardMode(Card): string
	if Card.Pressing then
		return "Press"
	end
	if Card.Hovering then
		return "Hover"
	end
	if Card.Hopping then
		return "Hop"
	end
	return "Idle"
end

function DailyRewardController:IsRewardAvailable(): boolean
	if not self.state or self.state.CurrentDay <= 0 then
		return false
	end
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
		if OtherIcon ~= self.topbarIcon then
			OtherIcon:deselect()
		end
	end
end

function DailyRewardController:TweenCard(Card, Scale: number, Offset: number, Info: TweenInfo)
	if Card.ScaleTween then
		Card.ScaleTween:Cancel()
	end
	if Card.HopTween then
		Card.HopTween:Cancel()
	end
	Card.ScaleTween = TweenService:Create(Card.Scale, Info, { Scale = Scale })
	Card.HopTween = TweenService:Create(Card.Button, Info, { Position = Card.Position + UDim2.fromOffset(0, Offset) })
	Card.ScaleTween:Play()
	Card.HopTween:Play()
end

function DailyRewardController:RunHop(Card)
	local Token = {}
	Card.HopToken = Token
	task.spawn(function()
		while Card.HopToken == Token do
			for _, Step in ipairs(HopSequence) do
				if Card.HopToken ~= Token then
					return
				end
				self:TweenCard(Card, Step.Scale, Step.Offset, Step.Info)
				task.wait(Step.Wait)
			end
			task.wait(HopRestTime + math.random() * HopRestVariance)
		end
	end)
end

function DailyRewardController:ApplyCardMotion(Card)
	local Mode = CardMode(Card)
	if Card.Mode == Mode then
		return
	end
	Card.Mode = Mode
	Card.HopToken = nil
	if Mode == "Press" then
		self:TweenCard(Card, PressScale, 0, ButtonTweenInfo)
	elseif Mode == "Hover" then
		self:TweenCard(Card, HoverScale, 0, ButtonTweenInfo)
	elseif Mode == "Idle" then
		self:TweenCard(Card, 1, 0, ButtonTweenInfo)
	else
		self:RunHop(Card)
	end
end

function DailyRewardController:SetHop(Card, Active: boolean)
	Card.Hopping = Active
	self:ApplyCardMotion(Card)
end

function DailyRewardController:SetSwing(Active: boolean)
	if self.swinging == Active then
		return
	end
	self.swinging = Active
	if self.swingTween then
		self.swingTween:Cancel()
		self.swingTween = nil
	end
	self.timeText.Rotation = 0
	if not Active then
		return
	end
	self.timeText.Rotation = -SwingRotation
	self.swingTween = TweenService:Create(self.timeText, SwingTweenInfo, { Rotation = SwingRotation })
	self.swingTween:Play()
end

function DailyRewardController:Refresh()
	if not self.state then
		return
	end
	local ClaimedDays = self.state.ClaimedDays
	local CurrentDay = self.state.CurrentDay
	local Available = self:IsRewardAvailable()
	for Day, Card in ipairs(self.days) do
		local Claimed = Day <= ClaimedDays
		local IsCurrent = Day == CurrentDay
		Card.Claimed.Visible = Claimed
		if Claimed then
			Card.Text.Text = "Claimed"
		elseif IsCurrent and Available then
			Card.Text.Text = "Claim"
		elseif IsCurrent then
			Card.Text.Text = "Skip"
		else
			Card.Text.Text = "Locked"
		end
		local Enabled = IsCurrent and (Available or self.state.SkipProductId > 0)
		Card.Button.Active = Enabled
		Card.Button.Interactable = Enabled
		Card.Button.AutoButtonColor = Enabled
		if not Enabled then
			Card.Hovering = false
			Card.Pressing = false
		end
		self:SetHop(Card, IsCurrent and Available and not Claimed)
	end

	local Complete = CurrentDay <= 0
	local Ready = not Complete and Available
	if Complete then
		self.timeText.Text = CompleteText
	elseif Ready then
		self.timeText.Text = ReadyText
	else
		self.timeText.Text = FormatDuration(self.state.NextClaimAt - workspace:GetServerTimeNow())
	end
	self:SetSwing(Ready)
end

function DailyRewardController:ApplyState(State)
	if not State then
		return
	end
	self.state = State
	self:Refresh()
	Core:GetController("BoostController"):SetBoost("DailySaleBoost", Config.SaleBoostIcon, State.SaleBoostEndsAt, 3)
end

function DailyRewardController:Open()
	if not self:CanOpen() then
		self.topbarIcon:deselect()
		return
	end
	Core:GetController("SettingController"):CloseForSwitch()
	Core:GetController("DonationController"):CloseForSwitch()
	self:DeselectOtherTopbarIcons()
	local ComputerController = Core:GetController("ComputerController")
	local CustomerController = Core:GetController("CustomerController")
	local ExpositionController = Core:GetController("ExpositionController")
	if ComputerController:IsOpen() then
		ComputerController:Close()
	end
	if CustomerController:IsVisible() then
		CustomerController:CloseOfferUi(true)
	end
	if ExpositionController:IsSelectionOpen() then
		ExpositionController:CloseSelectionFrame(false, true)
	end
	self.isOpen = true
	if self.positionTween then
		self.positionTween:Cancel()
	end
	if self.scaleTween then
		self.scaleTween:Cancel()
	end
	self.frame.Position = self.framePosition + UDim2.fromOffset(0, 20)
	self.frameScale.Scale = 0.94
	self.frame.Visible = true
	self.positionTween = TweenService:Create(self.frame, OpenTweenInfo, { Position = self.framePosition })
	self.scaleTween = TweenService:Create(self.frameScale, OpenTweenInfo, { Scale = 1 })
	self.positionTween:Play()
	self.scaleTween:Play()
end

function DailyRewardController:Close(Fast: boolean?)
	if not self:IsOpen() then
		return
	end
	self.isOpen = false
	if self.positionTween then
		self.positionTween:Cancel()
	end
	if self.scaleTween then
		self.scaleTween:Cancel()
	end
	local TweenInfoValue = if Fast then FastCloseTweenInfo else CloseTweenInfo
	self.positionTween = TweenService:Create(self.frame, TweenInfoValue, {
		Position = self.framePosition + UDim2.fromOffset(0, 20),
	})
	self.scaleTween = TweenService:Create(self.frameScale, TweenInfoValue, { Scale = 0.94 })
	local PositionTween = self.positionTween
	PositionTween:Play()
	self.scaleTween:Play()
	PositionTween.Completed:Once(function(State)
		if self.positionTween ~= PositionTween or State ~= Enum.PlaybackState.Completed then
			return
		end
		self.frame.Visible = false
		self.frame.Position = self.framePosition
		self.frameScale.Scale = 1
		self.positionTween = nil
		self.scaleTween = nil
		Core:GetController("RestorationController"):ResumePendingEnter()
	end)
end

function DailyRewardController:OpenFromTutorial()
	self.topbarIcon:select()
end

function DailyRewardController:CloseForSwitch()
	self:Close(true)
	self.topbarIcon:deselect()
end

function DailyRewardController:Claim()
	if self.processing then
		return
	end
	self.processing = true
	local Success, Result = pcall(function()
		return RemoteManager:InvokeServer("DailyRewardService", "ClaimReward")
	end)
	self.processing = false
	if not Success then
		Core:GetController("MessageController"):Show("Unable to claim daily reward", ErrorColor)
		return
	end
	if Result and Result.State then
		self:ApplyState(Result.State)
	end
	if Result and Result.Success then
		local Card = self.days[Result.Day]
		local FeedbackController = Core:GetController("FeedbackController")
		FeedbackController:Success(Card.Claimed, Result.RewardType == "Item")
		FeedbackController:FloatingText(self.frame, "REWARD CLAIMED", ClaimColor)
		FeedbackController:PlaySound("DailyReward", 0.2)
		if Result.RewardType == "Item" then
			print("DailyRewardController: " .. Result.RewardText .. " received for day " .. Result.Day)
		end
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
	if not self.state or Day ~= self.state.CurrentDay then
		return
	end
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
	self.closeButton = self.frame:WaitForChild("CloseButton")
	self.timeText = self.frame:WaitForChild("TimeText")
	self.claimedFrame = self.frame:WaitForChild("ClaimedFrame")
	self.days = {}
	self.processing = false
	self.isOpen = false
	self.swinging = false
	self.framePosition = self.frame.Position
	self.frameScale = Shared.EnsureScale(self.frame)
	self.frame.Visible = false
	self.frame.Active = true
	self.timeText.Rotation = 0

	local Gamepad = Core:GetController("GamepadController")
	for Day in ipairs(Config.Rewards) do
		local Button = self.frame:WaitForChild("ClaimButton" .. Day)
		local Card = {
			Button = Button,
			Text = Button:WaitForChild("Text"),
			Claimed = self.claimedFrame:WaitForChild(tostring(Day)),
			Scale = Shared.EnsureScale(Button),
			Position = Button.Position,
			Hopping = false,
			Hovering = false,
			Pressing = false,
		}
		self.days[Day] = Card
		Button.MouseEnter:Connect(function()
			if not Button.Active then
				return
			end
			Card.Hovering = true
			self:ApplyCardMotion(Card)
		end)
		Button.MouseLeave:Connect(function()
			Card.Hovering = false
			Card.Pressing = false
			self:ApplyCardMotion(Card)
		end)
		Button.MouseButton1Down:Connect(function()
			if not Button.Active then
				return
			end
			Card.Pressing = true
			self:ApplyCardMotion(Card)
		end)
		Button.MouseButton1Up:Connect(function()
			Card.Pressing = false
			self:ApplyCardMotion(Card)
		end)
		Gamepad:OnActivated(Button, function()
			self:ActivateDay(Day)
		end)
	end

	self.topbarIcon = Icon.new()
		:setName("DailyRewards")
		:setImage("rbxassetid://72627984848404")
		:modifyTheme({ "IconImage", "ImageColor3", Color3.fromRGB(255, 255, 255) })
		:setCaption("Daily Rewards")
	self.topbarIcon.selected:Connect(function()
		self:Open()
	end)
	self.topbarIcon.deselected:Connect(function()
		self:Close()
	end)
	Shared.AnimateButton(self.closeButton, function()
		return false
	end)
	Gamepad:OnActivated(self.closeButton, function()
		self.topbarIcon:deselect()
	end)
	Gamepad:RegisterMenu({
		Priority = 25,
		IsOpen = function()
			return self:IsOpen()
		end,
		Close = function()
			self.topbarIcon:deselect()
		end,
	})
	Gamepad:BindShortcut(Enum.KeyCode.ButtonL1, function()
		self.topbarIcon:select()
	end)
	self:ApplyState(RemoteManager:InvokeServer("DailyRewardService", "GetState"))
end

function DailyRewardController:Start()
	RemoteManager:OnClientEvent("DailyRewardService", "StateUpdated", function(State)
		self:ApplyState(State)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			self:Refresh()
		end
	end)
end

return DailyRewardController
