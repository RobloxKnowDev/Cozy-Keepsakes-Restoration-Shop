local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Home = require(script.Apps.Home)
local Index = require(script.Apps.Index)
local Sell = require(script.Apps.Sell)
local Shop = require(script.Apps.Shop)
local Shared = require(script.Apps.Shared)
local Upgrades = require(script.Apps.Upgrades)

local ComputerController = {
	Name = "ComputerController",
	Priority = 3,
}

local Applications = { Home, Index, Sell, Upgrades, Shop }
local HighlightFillColor = Color3.fromRGB(255, 232, 163)
local HighlightOutlineColor = Color3.fromRGB(255, 255, 255)
local ButtonTweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ActiveButtonColor = Color3.fromRGB(231, 248, 222)
local ActiveContentColor = Color3.fromRGB(0, 0, 0)
local ActiveButtonScale = 1.03
local CountDuration = 0.65
local PulseInfo = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GainColor = Color3.fromRGB(126, 255, 145)
local LossColor = Color3.fromRGB(255, 138, 138)

function ComputerController:IsOpen(): boolean
	return self.isOpen == true
end

function ComputerController:CanOpen(): boolean
	local CameraController = Core:GetController("InspectionCameraController")
	local RestorationController = Core:GetController("RestorationController")
	local CustomerController = Core:GetController("CustomerController")
	local DailyRewardController = Core:GetController("DailyRewardController")
	return not self:IsOpen()
		and CameraController:IsIntroCameraReady()
		and not RestorationController:IsEditingObject()
		and not CustomerController:IsVisible()
		and not DailyRewardController:IsOpen()
end

function ComputerController:SetHoveredComputer(Computer: Instance?)
	if self.hoveredComputer == Computer then
		return
	end
	self.hoveredComputer = Computer
	self.hoverHighlight.Adornee = Computer
	self.hoverHighlight.Enabled = Computer ~= nil and not self:IsOpen()
end

function ComputerController:UpdateHoveredComputer()
	if not self:CanOpen() then
		self:SetHoveredComputer(nil)
		return
	end
	local Ray = self.mouse.UnitRay
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { self.coreModel, self.screenModel, self.buttonModel, self.postitModel }
	local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 500, Params)
	self:SetHoveredComputer(if Result then self.computer else nil)
end

function ComputerController:FocusCamera()
	Core:GetController("InspectionCameraController"):ShowComputerCamera()
end

function ComputerController:SetHudVisible(IsVisible: boolean)
	if self.hudCashFrame then
		self.hudCashFrame.Visible = IsVisible
	end
	if self.hudDayFrame then
		self.hudDayFrame.Visible = IsVisible
	end
end

function ComputerController:SyncHeader()
	if self.cashText and self.hudCashText then
		self.cashText.Text = self.hudCashText.Text
	end
	if self.dayText and self.hudDayText then
		self.dayText.Text = self.hudDayText.Text
	end
	if self.timeText and self.hudTimeText then
		self.timeText.Text = self.hudTimeText.Text
	end
end

function ComputerController:SetDisplayedComputerCash(Value: number)
	self.displayedComputerCash = Value
	if self.cashText then
		self.cashText.Text = Shared.FormatCurrency(Value)
	end
end

function ComputerController:AnimateComputerCashTo(TargetValue: number)
	local StartValue = self.displayedComputerCash or TargetValue
	local Delta = TargetValue - StartValue
	if math.abs(Delta) < 0.005 then
		self:SetDisplayedComputerCash(TargetValue)
		return
	end
	self.computerCashAnimationId += 1
	local AnimationId = self.computerCashAnimationId
	local StartTime = os.clock()
	if self.cashTextScale then
		TweenService:Create(self.cashTextScale, PulseInfo, { Scale = 1.08 }):Play()
	end
	if self.cashText then
		TweenService:Create(self.cashText, PulseInfo, { TextColor3 = if Delta > 0 then GainColor else LossColor })
			:Play()
	end
	local Connection
	Connection = RunService.RenderStepped:Connect(function()
		if self.computerCashAnimationId ~= AnimationId then
			Connection:Disconnect()
			return
		end
		local Alpha = math.clamp((os.clock() - StartTime) / CountDuration, 0, 1)
		self:SetDisplayedComputerCash(
			StartValue + Delta * TweenService:GetValue(Alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		)
		if Alpha >= 1 then
			Connection:Disconnect()
			self:SetDisplayedComputerCash(TargetValue)
			if self.cashTextScale then
				TweenService:Create(self.cashTextScale, PulseInfo, { Scale = 1 }):Play()
			end
			if self.cashText then
				TweenService
					:Create(self.cashText, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						TextColor3 = self.baseComputerCashTextColor,
					})
					:Play()
			end
		end
	end)
end

function ComputerController:ApplyNavButtonStyle(Button: GuiButton, IsActive: boolean)
	local Defaults = self.navButtonDefaults[Button]
	local Scale = Shared.EnsureScale(Button)
	TweenService:Create(Scale, ButtonTweenInfo, { Scale = if IsActive then ActiveButtonScale else 1 }):Play()
	TweenService:Create(
		Button,
		ButtonTweenInfo,
		{ BackgroundColor3 = if IsActive then ActiveButtonColor else Defaults.BackgroundColor3 }
	):Play()
	if Defaults.Stroke then
		TweenService:Create(
			Defaults.Stroke,
			ButtonTweenInfo,
			{ Transparency = if IsActive then 1 else Defaults.StrokeTransparency }
		):Play()
	end
	for _, Object in ipairs(Defaults.Texts) do
		TweenService:Create(
			Object,
			ButtonTweenInfo,
			{ TextColor3 = if IsActive then ActiveContentColor else Defaults.TextColors[Object] }
		):Play()
	end
	for _, Object in ipairs(Defaults.Images) do
		TweenService:Create(
			Object,
			ButtonTweenInfo,
			{ ImageColor3 = if IsActive then ActiveContentColor else Defaults.ImageColors[Object] }
		):Play()
	end
end

function ComputerController:SetPage(PageName: string)
	self.activePage = PageName
	self.homeFrame.Visible = PageName == "Home"
	self.indexFrame.Visible = PageName == "Index"
	self.sellFrame.Visible = PageName == "Sell"
	self.upgradesFrame.Visible = PageName == "Upgrades"
	self.shopFrame.Visible = PageName == "Shop"
	self:ApplyNavButtonStyle(self.homeButton, PageName == "Home")
	self:ApplyNavButtonStyle(self.indexButton, PageName == "Index")
	self:ApplyNavButtonStyle(self.sellNavButton, PageName == "Sell")
	self:ApplyNavButtonStyle(self.upgradesButton, PageName == "Upgrades")
	self:ApplyNavButtonStyle(self.shopButton, PageName == "Shop")
end

function ComputerController:Open()
	if not self:CanOpen() then
		return
	end
	self.isOpen = true
	self:SetHoveredComputer(nil)
	self:SyncHeader()
	self:SetHudVisible(false)
	Core:GetController("ExpositionController"):SetBlocker("Computer", "Hidden")
	self.computerModel.CanQuery = true
	self.surfaceGui.Enabled = true
	self.surfaceGui.Active = true
	self.frame.Visible = true
	self:SetPage("Home")
	UserInputService.MouseIconEnabled = true
	self:FocusCamera()
end

function ComputerController:Close()
	if not self:IsOpen() then
		return
	end
	self.isOpen = false
	self.computerModel.CanQuery = false
	self.surfaceGui.Active = false
	self.frame.Visible = true
	self:SetHudVisible(true)
	Core:GetController("InspectionCameraController"):ShowIntroCamera()
	Core:GetController("ExpositionController"):SetBlocker("Computer", nil)
	self:UpdateHoveredComputer()
end

local function CaptureNavigationDefaults(Controller, Button: GuiButton)
	local Texts, TextColors, Images, ImageColors = {}, {}, {}, {}
	for _, Descendant in ipairs(Button:GetDescendants()) do
		if Descendant:IsA("TextLabel") or Descendant:IsA("TextButton") or Descendant:IsA("TextBox") then
			table.insert(Texts, Descendant)
			TextColors[Descendant] = Descendant.TextColor3
		elseif Descendant:IsA("ImageLabel") or Descendant:IsA("ImageButton") then
			table.insert(Images, Descendant)
			ImageColors[Descendant] = Descendant.ImageColor3
		end
	end
	local Stroke = Button:FindFirstChildOfClass("UIStroke")
	Controller.navButtonDefaults[Button] = {
		BackgroundColor3 = Button.BackgroundColor3,
		Stroke = Stroke,
		StrokeTransparency = if Stroke then Stroke.Transparency else 0,
		Texts = Texts,
		TextColors = TextColors,
		Images = Images,
		ImageColors = ImageColors,
	}
end

function ComputerController:Init()
	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.mouse = Players.LocalPlayer:GetMouse()
	self.computer = Workspace:WaitForChild("Map")
		:WaitForChild("Slot1")
		:WaitForChild("Work")
		:WaitForChild("Utilities")
		:WaitForChild("Ordi")
	self.buttonModel = self.computer:WaitForChild("Button")
	self.coreModel = self.computer:WaitForChild("Core"):WaitForChild("Model") :: BasePart
	self.postitModel = self.computer:WaitForChild("Postit")
	self.computerGui = self.computer:WaitForChild("Gui")
	self.computerModel = self.computerGui:WaitForChild("Computer") :: BasePart
	self.computerModel.CanQuery = false
	self.screenModel = self.computer:WaitForChild("Ecran"):WaitForChild("Model") :: BasePart
	self.screenModel.CanQuery = true
	self.surfaceGui = self.computerModel:WaitForChild("SurfaceGui") :: SurfaceGui
	self.surfaceGui.Active = false
	self.frame = self.surfaceGui:WaitForChild("Frame") :: Frame
	self.header = self.frame:WaitForChild("Header") :: Frame
	self.pageFrame = self.frame:WaitForChild("PageFrame")
	self.homeFrame = self.pageFrame:WaitForChild("HomeFrame")
	self.indexFrame = self.pageFrame:WaitForChild("IndexFrame")
	self.sellFrame = self.pageFrame:WaitForChild("SellFrame")
	self.upgradesFrame = self.pageFrame:WaitForChild("UpgradeFrame")
	self.shopFrame = self.pageFrame:WaitForChild("ShopFrame")
	self.LeftFrame = self.frame:WaitForChild("Left")
	self.exitButton = self.header:WaitForChild("ExitButton")
	self.homeButton = self.LeftFrame:WaitForChild("HomeButton")
	self.indexButton = self.LeftFrame:WaitForChild("IndexButton")
	self.sellNavButton = self.LeftFrame:WaitForChild("SellButton")
	self.upgradesButton = self.LeftFrame:WaitForChild("UpgradeButton")
	self.shopButton = self.LeftFrame:WaitForChild("ShopButton")
	self.cashText = self.header:WaitForChild("CashFrame").CashText
	self.dayText = self.header:WaitForChild("DayFrame").DayText
	self.timeText = self.header:WaitForChild("DayFrame").TimeText
	self.hud = PlayerGui:WaitForChild("HUD")
	self.hudCashFrame = self.hud:WaitForChild("CashFrame") :: GuiObject
	self.hudDayFrame = self.hud:WaitForChild("DayFrame") :: GuiObject
	self.hudCashText = self.hudCashFrame:WaitForChild("CashText")
	self.hudDayText = self.hudDayFrame:WaitForChild("DayText")
	self.hudTimeText = self.hudDayFrame:WaitForChild("TimeText")
	self.activePage = "Home"
	self.isOpen = false
	self.navButtonDefaults = {}
	self.computerCashAnimationId = 0
	self.hoverHighlight = Instance.new("Highlight")
	self.hoverHighlight.Name = "ComputerHoverHighlight"
	self.hoverHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	self.hoverHighlight.FillColor = HighlightFillColor
	self.hoverHighlight.FillTransparency = 1
	self.hoverHighlight.OutlineColor = HighlightOutlineColor
	self.hoverHighlight.OutlineTransparency = 0
	self.hoverHighlight.Enabled = false
	self.hoverHighlight.Parent = Workspace
	self.cashTextScale = Shared.EnsureScale(self.cashText)
	self.baseComputerCashTextColor = self.cashText.TextColor3

	self.surfaceGui.Enabled = true
	self.frame.Visible = true
	self.homeFrame.Visible = false
	self.indexFrame.Visible = false
	self.sellFrame.Visible = false
	self.upgradesFrame.Visible = false
	self.shopFrame.Visible = false
	for _, Button in ipairs({
		self.homeButton,
		self.indexButton,
		self.sellNavButton,
		self.upgradesButton,
		self.shopButton,
	}) do
		CaptureNavigationDefaults(self, Button)
	end
	Shared.AnimateButton(self.exitButton, function()
		return false
	end)
	Shared.AnimateButton(self.homeButton, function()
		return self.activePage == "Home"
	end)
	Shared.AnimateButton(self.indexButton, function()
		return self.activePage == "Index"
	end)
	Shared.AnimateButton(self.sellNavButton, function()
		return self.activePage == "Sell"
	end)
	Shared.AnimateButton(self.upgradesButton, function()
		return self.activePage == "Upgrades"
	end)
	Shared.AnimateButton(self.shopButton, function()
		return self.activePage == "Shop"
	end)
	for _, Application in ipairs(Applications) do
		Application.Init(self)
	end
	self:SetPage("Home")
	self:SyncHeader()
	self:SetDisplayedComputerCash(RemoteManager:InvokeServer("CashService", "GetCash"))
	self:SetHudVisible(true)
end

function ComputerController:Start()
	for _, Application in ipairs(Applications) do
		Application.Start(self)
	end
	RunService.RenderStepped:Connect(function()
		if self:IsOpen() then
			self:SyncHeader()
		end
		self:UpdateHoveredComputer()
	end)
	RemoteManager:OnClientEvent("CashService", "CashUpdated", function(Value)
		self:AnimateComputerCashTo(Value)
	end)
	UserInputService.InputBegan:Connect(function(Input, Processed)
		if
			Processed
			or not self:CanOpen()
			or Input.UserInputType ~= Enum.UserInputType.MouseButton1
			or not self.hoveredComputer
		then
			return
		end
		self:Open()
	end)
	self.exitButton.Activated:Connect(function()
		self:Close()
	end)
	self.homeButton.Activated:Connect(function()
		self:SetPage("Home")
	end)
	self.indexButton.Activated:Connect(function()
		self:SetPage("Index")
	end)
	self.sellNavButton.Activated:Connect(function()
		self:SetPage("Sell")
	end)
	self.upgradesButton.Activated:Connect(function()
		self:SetPage("Upgrades")
	end)
	self.shopButton.Activated:Connect(function()
		self:SetPage("Shop")
	end)
end

return ComputerController
