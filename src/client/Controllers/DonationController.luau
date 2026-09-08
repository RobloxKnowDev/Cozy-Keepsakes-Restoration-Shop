local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Icon = require(ReplicatedStorage.Shared:WaitForChild("Utils"):WaitForChild("Icon"))
local Config = require(ReplicatedStorage.Shared.Config.Donation)
local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Separatenumber = require(ReplicatedStorage.Shared.Utils.NumberAbbreviator)
local Shared = require(script.Parent.ComputerController.Apps.Shared)

local DonationController = {
	Name = "DonationController",
	Priority = 8.6,
}

local Player = Players.LocalPlayer
local RobuxIcon = ""
local OpenTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local CloseTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local FastCloseTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

function DonationController:IsOpen(): boolean
	return self.isOpen == true
end

function DonationController:CanOpen(): boolean
	return not self:IsOpen()
end

function DonationController:DeselectOtherTopbarIcons()
	for _, OtherIcon in pairs(Icon.getIcons()) do
		if OtherIcon ~= self.topbarIcon then OtherIcon:deselect() end
	end
end

function DonationController:Open()
	if not self:CanOpen() then
		self.topbarIcon:deselect()
		return
	end
	Core:GetController("SettingController"):CloseForSwitch()
	Core:GetController("DailyRewardController"):CloseForSwitch()
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

function DonationController:Close(Fast: boolean?)
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

function DonationController:CloseForSwitch()
	self:Close(true)
	self.topbarIcon:deselect()
end

function DonationController:Init()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	self.ui = PlayerGui:WaitForChild("DonationUi")
	self.frame = self.ui:WaitForChild("Frame")
	self.scrollingFrame = self.frame:WaitForChild("ScrollingFrame")
	self.gridLayout = self.scrollingFrame:WaitForChild("UIGridLayout")
	self.exitButton = self.frame:WaitForChild("ExitButton")
	self.isOpen = false
	self.framePosition = self.frame.Position
	self.frameScale = Shared.EnsureScale(self.frame)
	self.frame.Visible = false
	self.frame.Active = true
	self.gridLayout.SortOrder = Enum.SortOrder.LayoutOrder

	for Order, Product in ipairs(Config.Products) do
		local Card = self.scrollingFrame:WaitForChild(tostring(Product.Amount))
		Card.LayoutOrder = Order
		local Button = Card:WaitForChild("Button")
		Button:WaitForChild("Text").Text = RobuxIcon .. Separatenumber(Product.Amount)
		Shared.AnimateButton(Button, function() return false end)
		Button.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(Player, Product.Id)
		end)
	end

	self.topbarIcon = Icon.new()
		:setName("Donations")
		:setLabel(RobuxIcon)
		:setOrder(-1)
		:setCaption("Donations")
	self.topbarIcon.selected:Connect(function() self:Open() end)
	self.topbarIcon.deselected:Connect(function() self:Close() end)
	Shared.AnimateButton(self.exitButton, function() return false end)
	self.exitButton.Activated:Connect(function() self.topbarIcon:deselect() end)
end

function DonationController:Start()
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(_UserId, ProductId, WasPurchased)
		if not WasPurchased then return end
		for _, Product in ipairs(Config.Products) do
			if Product.Id == ProductId then
				Core:GetController("FeedbackController"):DonationThanks(RobuxIcon .. Separatenumber(Product.Amount))
				return
			end
		end
	end)
	self.scrollingFrame.CanvasSize = UDim2.fromOffset(0, self.gridLayout.AbsoluteContentSize.Y)
	self.gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.scrollingFrame.CanvasSize = UDim2.fromOffset(0, self.gridLayout.AbsoluteContentSize.Y)
	end)
end

return DonationController
