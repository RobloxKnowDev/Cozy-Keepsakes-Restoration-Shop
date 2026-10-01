local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local UiFade = require(ReplicatedStorage.Shared.Utils.UiFade)
local DailyTasks = require(script.Apps.DailyTasks)
local Home = require(script.Apps.Home)
local Index = require(script.Apps.Index)
local Inventory = require(script.Apps.Inventory)
local Shared = require(script.Apps.Shared)
local Upgrades = require(script.Apps.Upgrades)

local ComputerController = {
	Name = "ComputerController",
	Priority = 3,
}

local Applications = { Home, DailyTasks, Index, Inventory, Upgrades }
local HighlightFillColor = Color3.fromRGB(255, 232, 163)
local HighlightOutlineColor = Color3.fromRGB(255, 255, 255)
local CountDuration = 0.65
local PulseInfo = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GainColor = Color3.fromRGB(126, 255, 145)
local LossColor = Color3.fromRGB(255, 138, 138)
local PointerRayOffsets = { Vector2.zero }
local TouchRayOffsets = {
	Vector2.zero,
	Vector2.new(-36, 0),
	Vector2.new(36, 0),
	Vector2.new(0, -36),
	Vector2.new(0, 36),
	Vector2.new(-30, -30),
	Vector2.new(30, -30),
	Vector2.new(-30, 30),
	Vector2.new(30, 30),
	Vector2.new(-52, 0),
	Vector2.new(52, 0),
	Vector2.new(0, -52),
	Vector2.new(0, 52),
}

local function IsGamepad(InputType: Enum.UserInputType): boolean
	return Core:GetController("GamepadController"):IsGamepad(InputType)
end

local PageOrder = { "Home", "Index", "Inventory", "Upgrades" }

function ComputerController:IsOpen(): boolean
	return self.isOpen == true
end

function ComputerController:CanOpen(): boolean
	local CameraController = Core:GetController("InspectionCameraController")
	local RestorationController = Core:GetController("RestorationController")
	return not self:IsOpen()
		and CameraController:IsIntroCameraReady()
		and not RestorationController:IsEditingObject()
end

function ComputerController:SetHoveredComputer(Computer: Instance?)
	if self.hoveredComputer == Computer then
		return
	end
	self.hoveredComputer = Computer
	self.hoverHighlight.Adornee = Computer
	self.hoverHighlight.Enabled = Computer ~= nil and not self:IsOpen()
end

function ComputerController:IsComputerAtPosition(ScreenPosition: Vector2?, ExpandTouch: boolean?): boolean
	local Camera = Workspace.CurrentCamera
	local Position = ScreenPosition or UserInputService:GetMouseLocation()
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { self.computer }
	for _, Offset in ipairs(if ExpandTouch then TouchRayOffsets else PointerRayOffsets) do
		local RayPosition = Position + Offset
		local Ray = Camera:ViewportPointToRay(RayPosition.X, RayPosition.Y)
		if Workspace:Raycast(Ray.Origin, Ray.Direction * 500, Params) then return true end
		if ExpandTouch then
			local InsetRay = Camera:ScreenPointToRay(RayPosition.X, RayPosition.Y)
			if Workspace:Raycast(InsetRay.Origin, InsetRay.Direction * 500, Params) then return true end
		end
	end
	return false
end

function ComputerController:UpdateHoveredComputer()
	if not self:CanOpen() then
		self:SetHoveredComputer(nil)
		return
	end
	local LastInputType = UserInputService:GetLastInputType()
	if LastInputType == Enum.UserInputType.Touch then
		self:SetHoveredComputer(nil)
		return
	end
	self:SetHoveredComputer(if self:IsComputerAtPosition(nil) then self.computer else nil)
end
function ComputerController:FocusCamera()
	Core:GetController("InspectionCameraController"):ShowComputerCamera()
end

function ComputerController:SetHudVisible(IsVisible: boolean)
	UiFade.SetVisible(self.hudCashFrame, IsVisible)
	UiFade.SetVisible(self.hudCashText, IsVisible)
	UiFade.SetVisible(self.hudDayFrame, IsVisible)
	UiFade.SetVisible(self.hudDayText, IsVisible)
	UiFade.SetVisible(self.hudHourText, IsVisible)
	self.hudCooldownFrame.Visible = IsVisible
end

function ComputerController:SetSellLocked(Locked: boolean)
	self.sellLocked = Locked
	Inventory.RefreshControls(self)
end

function ComputerController:SyncHeader()
	if self.cashText and self.hudCashText then
		self.cashText.Text = self.hudCashText.Text
	end
	if self.dayText and self.hudDayText then
		self.dayText.Text = self.hudDayText.Text
	end
	if self.timeText and self.hudHourText then
		self.timeText.Text = self.hudHourText.Text
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

function ComputerController:SetPage(PageName: string)
	self.activePage = PageName
	self.homePage.Visible = PageName == "Home"
	self.indexPage.Visible = PageName == "Index"
	self.inventoryPage.Visible = PageName == "Inventory"
	self.upgradesPage.Visible = PageName == "Upgrades"
	for _, Refresh in ipairs(self.navButtonRefreshes) do
		Refresh()
	end
end

function ComputerController:CyclePage(Direction: number)
	local Index = table.find(PageOrder, self.activePage) or 1
	self:SetPage(PageOrder[(Index - 1 + Direction) % #PageOrder + 1])
	Core:GetController("FeedbackController"):UiClick()
end

function ComputerController:Open()
	if not self:CanOpen() then
		return
	end
	Core:GetController("DailyRewardController"):CloseForSwitch()
	Core:GetController("SettingController"):CloseForSwitch()
	local CustomerController = Core:GetController("CustomerController")
	if CustomerController:IsVisible() then CustomerController:CloseOfferUi(true) end
	self.isOpen = true
	self:SetHoveredComputer(nil)
	self:SyncHeader()
	self:SetHudVisible(false)
	Core:GetController("ExpositionController"):SetBlocker("Computer", "Hidden")
	self.computerModel.CanQuery = true
	self.surfaceGui.Enabled = true
	self.surfaceGui.Active = true
	self.inputBlocker.Visible = false
	self.frame.Visible = true
	self:SetPage(self.activePage or "Home")
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
	self.inputBlocker.Visible = true
	self:SetHudVisible(true)
	Core:GetController("InspectionCameraController"):ShowIntroCamera()
	Core:GetController("ExpositionController"):SetBlocker("Computer", nil)
	self:UpdateHoveredComputer()
end

function ComputerController:Init()
	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
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
	self.surfaceGui.Adornee = self.computerModel
	self.surfaceGui.Parent = PlayerGui
	Core:GetController("FeedbackController"):BindClicksIn(self.surfaceGui)
	self.surfaceGui.Active = false
	self.inputBlocker = Instance.new("TextButton")
	self.inputBlocker.Name = "InputBlocker"
	self.inputBlocker.Text = ""
	self.inputBlocker.BackgroundTransparency = 1
	self.inputBlocker.AutoButtonColor = false
	self.inputBlocker.Size = UDim2.fromScale(1, 1)
	self.inputBlocker.ZIndex = 1000
	self.inputBlocker.Active = true
	self.inputBlocker:SetAttribute("SilentClick", true)
	self.inputBlocker.Parent = self.surfaceGui
	self.frame = self.surfaceGui:WaitForChild("Frame") :: Frame
	self.header = self.frame:WaitForChild("Header")
	self.pages = self.frame:WaitForChild("Pages")
	self.homePage = self.pages:WaitForChild("HomePage")
	self.indexPage = self.pages:WaitForChild("IndexPage")
	self.inventoryPage = self.pages:WaitForChild("InventoryPage")
	self.upgradesPage = self.pages:WaitForChild("UpgradePage")
	self.LeftFrame = self.frame:WaitForChild("Left")
	self.closeButton = self.header:WaitForChild("CloseButton")
	self.homeButton = self.LeftFrame:WaitForChild("HomeButton")
	self.indexButton = self.LeftFrame:WaitForChild("IndexButton")
	self.inventoryNavButton = self.LeftFrame:WaitForChild("InventoryButton")
	self.upgradesButton = self.LeftFrame:WaitForChild("UpgradeButton")
	self.shopButton = self.LeftFrame:WaitForChild("ShopButton")
	self.cashText = self.header:WaitForChild("CashFrame"):WaitForChild("CashText")
	self.dayText = self.header:WaitForChild("DayFrame"):WaitForChild("DayText")
	self.timeText = self.header:WaitForChild("DayFrame"):WaitForChild("TimeText")
	self.hud = PlayerGui:WaitForChild("HUD")
	self.hudCashFrame = self.hud:WaitForChild("CashFrame") :: GuiObject
	self.hudDayFrame = self.hud:WaitForChild("DayFrame") :: GuiObject
	self.hudCooldownFrame = self.hud:WaitForChild("CooldownFrame") :: GuiObject
	self.hudCashText = self.hudCashFrame:WaitForChild("Text")
	self.hudDayText = self.hudDayFrame:WaitForChild("DayText")
	self.hudHourText = self.hudDayFrame:WaitForChild("HourText")
	self.activePage = "Home"
	self.isOpen = false
	self.sellLocked = false

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
	self.homePage.Visible = false
	self.indexPage.Visible = false
	self.inventoryPage.Visible = false
	self.upgradesPage.Visible = false
	Shared.AnimateButton(self.closeButton, function()
		return false
	end)
	self.navButtonRefreshes = {
		Shared.AnimateNavButton(self.homeButton, function()
			return self.activePage == "Home"
		end),
		Shared.AnimateNavButton(self.indexButton, function()
			return self.activePage == "Index"
		end),
		Shared.AnimateNavButton(self.inventoryNavButton, function()
			return self.activePage == "Inventory"
		end),
		Shared.AnimateNavButton(self.upgradesButton, function()
			return self.activePage == "Upgrades"
		end),
		Shared.AnimateNavButton(self.shopButton, function()
			return self.activePage == "Shop"
		end),
	}
	for _, Application in ipairs(Applications) do
		Application.Init(self)
	end
	self:SetPage("Home")
	self:SyncHeader()
	self:SetDisplayedComputerCash(RemoteManager:InvokeServer("CashService", "GetCash"))
	self:SetHudVisible(true)
end

function ComputerController:Start()
	Core:GetController("GamepadController"):RegisterMenu({
		Priority = 10,
		IsOpen = function()
			return self:IsOpen()
		end,
		Close = function()
			self:Close()
		end,
	})
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
	local function TryOpen(ScreenPosition: Vector2?, ExpandTouch: boolean?): boolean
		if not self:CanOpen() or not self:IsComputerAtPosition(ScreenPosition, ExpandTouch) then return false end
		Core:GetController("FeedbackController"):UiClick()
		self:SetHoveredComputer(self.computer)
		self:Open()
		return true
	end
	local LastWorldInteraction = 0
	local function TryWorldInteraction(ScreenPosition: Vector2, ExpandTouch: boolean?)
		if os.clock() - LastWorldInteraction < 0.15 then return end
		LastWorldInteraction = os.clock()
		local CustomerController = Core:GetController("CustomerController")
		if ExpandTouch then
			if CustomerController:TryInteractAtPosition(ScreenPosition, true) then return end
			TryOpen(ScreenPosition, true)
			return
		end
		if CustomerController:TryInteractAtPosition(ScreenPosition, false) then return end
		TryOpen(ScreenPosition, false)
	end
	local Gamepad = Core:GetController("GamepadController")
	Gamepad:OnActivated(self.inputBlocker, function()
		TryWorldInteraction(UserInputService:GetMouseLocation())
	end)
	Gamepad:BindWorldPress(function()
		TryWorldInteraction(UserInputService:GetMouseLocation())
	end)
	UserInputService.InputBegan:Connect(function(Input, Processed)
		if Processed then return end
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			TryWorldInteraction(UserInputService:GetMouseLocation())
		elseif
			IsGamepad(Input.UserInputType)
			and self:IsOpen()
			and (Input.KeyCode == Enum.KeyCode.ButtonL1 or Input.KeyCode == Enum.KeyCode.ButtonR1)
		then
			self:CyclePage(if Input.KeyCode == Enum.KeyCode.ButtonL1 then -1 else 1)
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(Position, Processed)
		if Processed then return end
		TryWorldInteraction(Position, true)
	end)
	Core:GetController("GamepadController"):OnActivated(self.closeButton, function()
		self:Close()
	end)
	Core:GetController("GamepadController"):OnActivated(self.homeButton, function()
		self:SetPage("Home")
	end)
	Core:GetController("GamepadController"):OnActivated(self.indexButton, function()
		self:SetPage("Index")
	end)
	Core:GetController("GamepadController"):OnActivated(self.inventoryNavButton, function()
		self:SetPage("Inventory")
	end)
	Core:GetController("GamepadController"):OnActivated(self.upgradesButton, function()
		self:SetPage("Upgrades")
	end)
end

return ComputerController
