local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Tweenservice = game:GetService("TweenService")

local Core = require(Replicatedstorage.Shared.Packages.Core)

local Controller = {
	Name = "ExpositionController",
	Priority = 6,
}

type BlockerMode = "Disabled" | "Hidden"

local Buttontweeninfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Buttonhidetweeninfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local Buttonshowtweeninfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function Controller:IsOpen(): boolean
	return self.isOpen
end

function Controller:TweenButton(Button: GuiButton, Info: TweenInfo, ScaleValue: number): Tween
	local Currenttween = self.buttonTweens[Button]
	if Currenttween then Currenttween:Cancel() end
	local Tween = Tweenservice:Create(self.buttonScales[Button], Info, { Scale = ScaleValue })
	self.buttonTweens[Button] = Tween
	Tween:Play()
	return Tween
end

function Controller:ResetButton(Button: GuiButton)
	local Currenttween = self.buttonTweens[Button]
	if Currenttween then Currenttween:Cancel() end
	self.buttonTweens[Button] = nil
	self.buttonScales[Button].Scale = 1
	self.hoveredButtons[Button] = false
end

function Controller:ResolveBlockerMode(): BlockerMode?
	local Mode: BlockerMode? = nil
	for _, Blocker in pairs(self.blockers) do
		if Blocker == "Hidden" then return "Hidden" end
		Mode = "Disabled"
	end
	return Mode
end

function Controller:CanUseButtons(): boolean
	if self.blockerMode ~= nil or self.isTransitioning then return false end
	return self.isOpen or self.cameraController:IsIntroCameraReady()
end

function Controller:UpdateButtonAvailability()
	if self.isTransitioning then return end
	local Currentbutton = if self.isOpen then self.reputationButtonL else self.reputationButtonR
	local Canuse = self:CanUseButtons()
	for _, Button in ipairs({ self.reputationButtonL, self.reputationButtonR }) do
		local Enabled = Canuse and Button == Currentbutton and Button.Visible
		Button.Active = Enabled
		Button.Interactable = Enabled
	end
	if not Canuse and self.hoveredButtons[Currentbutton] then
		self.hoveredButtons[Currentbutton] = false
		self:TweenButton(Currentbutton, Buttontweeninfo, 1)
	end
end

function Controller:RefreshButtons()
	local Mode = self:ResolveBlockerMode()
	if self.blockerMode == Mode then return end
	local Previousmode = self.blockerMode
	self.blockerMode = Mode
	self.transitionVersion += 1
	self.isTransitioning = false
	for _, Button in ipairs({ self.reputationButtonL, self.reputationButtonR }) do
		self:ResetButton(Button)
		Button.Visible = false
		Button.Active = false
		Button.Interactable = false
	end
	if Mode == "Hidden" then return end

	local Button = if self.isOpen then self.reputationButtonL else self.reputationButtonR
	Button.Visible = true
	if Previousmode == "Hidden" then
		self.buttonScales[Button].Scale = 0.82
		self:TweenButton(Button, Buttonshowtweeninfo, 1)
	end
	self:UpdateButtonAvailability()
end

function Controller:SetBlocker(Source: string, Mode: BlockerMode?)
	if self.blockers[Source] == Mode then return end
	self.blockers[Source] = Mode
	self:RefreshButtons()
end

function Controller:SyncFrameBlockers()
	self:SetBlocker("Computer", if self.computerController:IsOpen() then "Hidden" else nil)
	self:SetBlocker("Customer", if self.customerController:IsVisible() then "Disabled" else nil)
	self:SetBlocker("DailyReward", if self.dailyRewardController:IsOpen() then "Disabled" else nil)
	self:SetBlocker("Completion", if self.completionController:IsVisible() then "Disabled" else nil)
end

function Controller:BindButtonAnimation(Button: GuiButton)
	Button.MouseEnter:Connect(function()
		self.hoveredButtons[Button] = true
		if not self:CanUseButtons() or not Button.Active then return end
		self:TweenButton(Button, Buttontweeninfo, 1.06)
	end)
	Button.MouseLeave:Connect(function()
		self.hoveredButtons[Button] = false
		if self.isTransitioning or not Button.Active then return end
		self:TweenButton(Button, Buttontweeninfo, 1)
	end)
	Button.MouseButton1Down:Connect(function()
		if not self:CanUseButtons() or not Button.Active then return end
		self:TweenButton(Button, Buttontweeninfo, 0.96)
	end)
	Button.MouseButton1Up:Connect(function()
		if not self:CanUseButtons() or not Button.Active then return end
		self:TweenButton(Button, Buttontweeninfo, if self.hoveredButtons[Button] then 1.06 else 1)
	end)
end

function Controller:SwapButtons(ButtonToHide: GuiButton, ButtonToShow: GuiButton)
	self.transitionVersion += 1
	local Version = self.transitionVersion
	self.isTransitioning = true
	self.reputationButtonL.Active = false
	self.reputationButtonL.Interactable = false
	self.reputationButtonR.Active = false
	self.reputationButtonR.Interactable = false

	local Hidescale = self.buttonScales[ButtonToHide]
	local Showscale = self.buttonScales[ButtonToShow]
	local Hidetween = self:TweenButton(ButtonToHide, Buttonhidetweeninfo, 0.82)
	Hidetween.Completed:Once(function(State)
		if State ~= Enum.PlaybackState.Completed or self.transitionVersion ~= Version then return end
		ButtonToHide.Visible = false
		Hidescale.Scale = 1
		self.hoveredButtons[ButtonToHide] = false
		ButtonToShow.Visible = true
		Showscale.Scale = 0.82
		local Showtween = self:TweenButton(ButtonToShow, Buttonshowtweeninfo, 1)
		Showtween.Completed:Once(function(Showstate)
			if Showstate ~= Enum.PlaybackState.Completed or self.transitionVersion ~= Version then return end
			Showscale.Scale = 1
			self.isTransitioning = false
			self:UpdateButtonAvailability()
			if self:CanUseButtons() and self.hoveredButtons[ButtonToShow] then
				self:TweenButton(ButtonToShow, Buttontweeninfo, 1.06)
			end
		end)
	end)
end

function Controller:Open()
	self:SyncFrameBlockers()
	if self.isOpen or not self:CanUseButtons() then return end
	if not self.cameraController:ShowExpositionCamera() then return end
	self.isOpen = true
	self:SwapButtons(self.reputationButtonR, self.reputationButtonL)
end

function Controller:Close()
	self:SyncFrameBlockers()
	if not self.isOpen or not self:CanUseButtons() then return end
	if not self.cameraController:ShowIntroCamera() then return end
	self.isOpen = false
	self:SwapButtons(self.reputationButtonL, self.reputationButtonR)
end

function Controller:PrepareForRestoration()
	if self.restorationPrepared then return end
	self.restorationPrepared = true
	self.wasOpenBeforeRestoration = self.isOpen
	self.isOpen = false
	self:SetBlocker("Restoration", "Hidden")
end

function Controller:CancelRestoration()
	if not self.restorationPrepared then return end
	self.restorationPrepared = false
	self.isOpen = self.wasOpenBeforeRestoration == true
	self.wasOpenBeforeRestoration = nil
	self:SetBlocker("Restoration", nil)
end

function Controller:CompleteRestoration()
	self.restorationPrepared = false
	self.wasOpenBeforeRestoration = nil
	self.isOpen = false
	self:SetBlocker("Restoration", nil)
end

function Controller:Init()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local Hud = Playergui:WaitForChild("HUD")
	local Reputationfolder = Hud:WaitForChild("ReputationFolder")
	self.reputationButtonL = Reputationfolder:WaitForChild("ReputationButtonL") :: GuiButton
	self.reputationButtonR = Reputationfolder:WaitForChild("ReputationButtonR") :: GuiButton
	self.buttonScales = {}
	self.buttonTweens = {}
	self.hoveredButtons = {}
	self.blockers = {}
	self.blockerMode = nil
	self.isOpen = false
	self.isTransitioning = false
	self.restorationPrepared = false
	self.transitionVersion = 0

	for _, Button in ipairs({ self.reputationButtonL, self.reputationButtonR }) do
		local Scale = Instance.new("UIScale")
		Scale.Name = "ExpositionScale"
		Scale.Parent = Button
		self.buttonScales[Button] = Scale
		self.hoveredButtons[Button] = false
	end

	self.reputationButtonL.Visible = false
	self.reputationButtonL.Active = false
	self.reputationButtonL.Interactable = false
	self.reputationButtonR.Visible = true
	self.reputationButtonR.Active = false
	self.reputationButtonR.Interactable = false
end

function Controller:Start()
	self.cameraController = Core:GetController("InspectionCameraController")
	self.computerController = Core:GetController("ComputerController")
	self.customerController = Core:GetController("CustomerController")
	self.dailyRewardController = Core:GetController("DailyRewardController")
	self.completionController = Core:GetController("CompletionController")
	self:BindButtonAnimation(self.reputationButtonL)
	self:BindButtonAnimation(self.reputationButtonR)
	self.reputationButtonR.Activated:Connect(function() self:Open() end)
	self.reputationButtonL.Activated:Connect(function() self:Close() end)
	self:SyncFrameBlockers()
	self:UpdateButtonAvailability()
	Runservice.RenderStepped:Connect(function()
		self:SyncFrameBlockers()
		self:UpdateButtonAvailability()
	end)
end

return Controller
