local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Icon = require(ReplicatedStorage.Shared:WaitForChild("Utils"):WaitForChild("Icon"))
local Core = require(ReplicatedStorage.Shared.Packages.Core)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.ComputerController.Apps.Shared)

local SettingController = {
	Name = "SettingController",
	Priority = 9,
}

local Player = Players.LocalPlayer
local OpenTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local CloseTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local FastCloseTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
local DefaultVolume = 0.75
local SliderStickSpeed = 0.6
local SliderStickDeadzone = 0.2
local OnGradientColor = Color3.fromRGB(21, 255, 0)
local OffGradientColor = Color3.fromRGB(255, 0, 4)
local ErrorColor = Color3.fromRGB(255, 0, 4)
local SuccessColor = Color3.fromRGB(21, 255, 0)
local HeavyEffects = {
	BlurEffect = true,
	BloomEffect = true,
	SunRaysEffect = true,
	DepthOfFieldEffect = true,
}

local MutedEmitters: { [ParticleEmitter]: boolean } = {}
local EffectsOn = true

local function MuteEmitter(Emitter: ParticleEmitter)
	if MutedEmitters[Emitter] ~= nil then
		return
	end
	MutedEmitters[Emitter] = Emitter.Enabled
	Emitter.Enabled = false
end

local function SetParticles(On: boolean)
	EffectsOn = On
	if not On then
		for _, Descendant in ipairs(Workspace:GetDescendants()) do
			if Descendant:IsA("ParticleEmitter") then
				MuteEmitter(Descendant)
			end
		end
		return
	end
	for Emitter, WasEnabled in pairs(MutedEmitters) do
		if Emitter.Parent then
			Emitter.Enabled = WasEnabled
		end
	end
	table.clear(MutedEmitters)
end

local function SetGraphics(High: boolean)
	Lighting.GlobalShadows = High
	for _, Effect in ipairs(Lighting:GetChildren()) do
		if HeavyEffects[Effect.ClassName] then
			(Effect :: PostEffect).Enabled = High
		end
	end
end

local function BuildColorSequence(Keypoints: { ColorSequenceKeypoint }, Color: Color3): ColorSequence
	local Updated = table.create(#Keypoints)
	for Index, Keypoint in ipairs(Keypoints) do
		local Value = if Index == #Keypoints then Color else Keypoint.Value
		table.insert(Updated, ColorSequenceKeypoint.new(Keypoint.Time, Value))
	end
	return ColorSequence.new(Updated)
end

function SettingController:IsOpen(): boolean
	return self.isOpen == true
end

function SettingController:CanOpen(): boolean
	return not self:IsOpen()
end

function SettingController:DeselectOtherTopbarIcons()
	for _, OtherIcon in pairs(Icon.getIcons()) do
		if OtherIcon ~= self.topbarIcon then OtherIcon:deselect() end
	end
end

function SettingController:Open()
	if not self:CanOpen() then
		self.topbarIcon:deselect()
		return
	end
	Core:GetController("DailyRewardController"):CloseForSwitch()
	Core:GetController("DonationController"):CloseForSwitch()
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

function SettingController:Close(Fast: boolean?)
	if not self:IsOpen() then return end
	self.isOpen = false
	self.codesBox:ReleaseFocus()
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

function SettingController:CloseForSwitch()
	self:Close(true)
	self.topbarIcon:deselect()
end

function SettingController:Applyeffect(Name: string, Value: any)
	if Name == "Graphism" then
		SetGraphics(Value == true)
	elseif Name == "Effect" then
		Player:SetAttribute("EffectsIntensity", if Value == true then "Full" else "Off")
		SetParticles(Value == true)
	elseif Name == "MusicVolume" then
		Core:GetController("FeedbackController"):SetMusicVolume(Value)
	elseif Name == "SoundEffect" then
		Core:GetController("FeedbackController"):SetSoundVolume(Value)
	end
end

function SettingController:BindToggle(Button: GuiButton, Name: string, OnText: string, OffText: string)
	local Text = Button:WaitForChild("Text") :: TextLabel
	local Gradient = Button:WaitForChild("UIGradient") :: UIGradient
	local Keypoints = Gradient.Color.Keypoints
	local Enabled = true

	local function Apply(Value: boolean)
		Enabled = Value
		Text.Text = if Enabled then OnText else OffText
		Gradient.Color = BuildColorSequence(Keypoints, if Enabled then OnGradientColor else OffGradientColor)
	end

	Apply(true)
	Shared.AnimateButton(Button, function() return false end)
	Core:GetController("GamepadController"):OnActivated(Button, function()
		Apply(not Enabled)
		self:Applyeffect(Name, Enabled)
		RemoteManager:FireServer("SettingsService", "SetSetting", Name, Enabled)
	end)

	self.applysetting[Name] = function(Value)
		Apply(Value == true)
	end
end

function SettingController:BindSlider(Bar: GuiObject, PourcentageText: TextLabel, Name: string)
	local BarSize = Bar.Size
	local Arrow = Bar:WaitForChild("Frame") :: GuiObject
	local ArrowPosition = Arrow.Position
	local Current = DefaultVolume
	local Dragging = false

	local Track = Instance.new("Frame")
	Track.Name = Bar.Name .. "Track"
	Track.BackgroundTransparency = 1
	Track.AnchorPoint = Bar.AnchorPoint
	Track.Position = Bar.Position
	Track.Size = BarSize
	Track.ZIndex = Bar.ZIndex + 1
	Track.Active = true
	Track.Parent = Bar.Parent

	Arrow.ZIndex = Bar.ZIndex + 2
	Arrow.Parent = Track

	local function Apply(Alpha: number)
		Current = Alpha
		Bar.Size = UDim2.new(BarSize.X.Scale * Alpha, BarSize.X.Offset * Alpha, BarSize.Y.Scale, BarSize.Y.Offset)
		Arrow.Position = UDim2.new(
			ArrowPosition.X.Scale * Alpha,
			ArrowPosition.X.Offset,
			ArrowPosition.Y.Scale,
			ArrowPosition.Y.Offset
		)
		PourcentageText.Text = string.format("%d%%", math.round(Alpha * 100))
	end

	local function Update(Position: Vector3)
		Apply(math.clamp((Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1))
		self:Applyeffect(Name, Current)
	end

	Apply(DefaultVolume)
	Track.InputBegan:Connect(function(Input)
		if
			Input.UserInputType ~= Enum.UserInputType.MouseButton1
			and Input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		Dragging = true
		Update(Input.Position)
	end)
	UserInputService.InputChanged:Connect(function(Input)
		if not Dragging then return end
		if
			Input.UserInputType == Enum.UserInputType.MouseMovement
			or Input.UserInputType == Enum.UserInputType.Touch
		then
			Update(Input.Position)
		end
	end)
	UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			if Dragging then
				RemoteManager:FireServer("SettingsService", "SetSetting", Name, Current)
			end
			Dragging = false
		end
	end)

	local Hovered = false
	local Stickx = 0
	local Stickdirty = false
	local function Savestick()
		if not Stickdirty then return end
		Stickdirty = false
		RemoteManager:FireServer("SettingsService", "SetSetting", Name, Current)
	end
	Track.MouseEnter:Connect(function() Hovered = true end)
	Track.MouseLeave:Connect(function()
		Hovered = false
		Savestick()
	end)
	local Heldgamepad = false
	local function Updatefromcursor()
		local Cursor = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
		Update(Vector3.new(Cursor.X, Cursor.Y, 0))
	end
	UserInputService.InputChanged:Connect(function(Input)
		if Input.KeyCode == Enum.KeyCode.Thumbstick2 then Stickx = Input.Position.X end
	end)
	UserInputService.InputBegan:Connect(function(Input)
		if Hovered and self:IsOpen() and Input.KeyCode == Enum.KeyCode.ButtonA then
			Heldgamepad = true
			Updatefromcursor()
		end
	end)
	UserInputService.InputEnded:Connect(function(Input)
		if Input.KeyCode ~= Enum.KeyCode.ButtonA or not Heldgamepad then return end
		Heldgamepad = false
		RemoteManager:FireServer("SettingsService", "SetSetting", Name, Current)
	end)
	RunService.RenderStepped:Connect(function(Deltatime)
		if Heldgamepad then
			Updatefromcursor()
			return
		end
		if not Hovered or not self:IsOpen() or math.abs(Stickx) < SliderStickDeadzone then
			Savestick()
			return
		end
		Apply(math.clamp(Current + Stickx * SliderStickSpeed * Deltatime, 0, 1))
		self:Applyeffect(Name, Current)
		Stickdirty = true
	end)
	self.applysetting[Name] = Apply
end

function SettingController:RedeemCode()
	if self.redeeming then return end
	local Code = self.codesBox.Text
	if string.gsub(Code, "%s", "") == "" then return end

	self.redeeming = true
	local Result = RemoteManager:InvokeServer("CodeService", "RedeemCode", Code)
	self.redeeming = false

	local Message = Core:GetController("MessageController")
	if Result.Success then
		self.codesBox.Text = ""
		Message:Show("Code redeemed: " .. tostring(Result.ValueText), SuccessColor)
	elseif Result.Reason == "AlreadyClaimed" then
		Message:Show("You already claimed this code", ErrorColor)
	elseif Result.Reason == "RewardFailed" then
		Message:Show("This code reward could not be granted", ErrorColor)
	else
		Message:Show("This code does not exist", ErrorColor)
	end
end

function SettingController:BindCodes()
	Shared.AnimateButton(self.claimButton, function() return false end)
	Core:GetController("GamepadController"):OnActivated(self.claimButton, function()
		self:RedeemCode()
	end)
	self.codesBox.FocusLost:Connect(function(EnterPressed)
		if EnterPressed then
			self:RedeemCode()
		end
	end)
end

function SettingController:Init()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	self.ui = PlayerGui:WaitForChild("SettingUi")
	self.frame = self.ui:WaitForChild("Frame")
	self.closeButton = self.frame:WaitForChild("CloseButton") :: GuiButton
	self.claimButton = self.frame:WaitForChild("ClaimButton") :: GuiButton
	self.codesBox = self.frame:WaitForChild("TextBoxCodes") :: TextBox
	self.isOpen = false
	self.redeeming = false
	self.framePosition = self.frame.Position
	self.frameScale = Shared.EnsureScale(self.frame)
	self.frame.Visible = false
	self.frame.Active = true
	self.applysetting = {}
	Workspace.DescendantAdded:Connect(function(Descendant)
		if not EffectsOn and Descendant:IsA("ParticleEmitter") then
			MuteEmitter(Descendant)
		end
	end)

	self:BindToggle(self.frame:WaitForChild("GraphismButton") :: GuiButton, "Graphism", "High", "Low")
	self:BindToggle(self.frame:WaitForChild("EffectButton") :: GuiButton, "Effect", "On", "Off")
	self:BindSlider(
		self.frame:WaitForChild("BarMusicVolume") :: GuiObject,
		self.frame:WaitForChild("MusicVolumeText") :: TextLabel,
		"MusicVolume"
	)
	self:BindSlider(
		self.frame:WaitForChild("BarSoundEffect") :: GuiObject,
		self.frame:WaitForChild("SoundEffectText") :: TextLabel,
		"SoundEffect"
	)
	self:BindCodes()

	self.topbarIcon = Icon.new()
		:setName("Settings")
		:setImage("rbxassetid://92246988918469")
		:modifyTheme({ "IconImage", "ImageColor3", Color3.fromRGB(255, 255, 255) })
		:setCaption("Settings")
	self.topbarIcon.selected:Connect(function() self:Open() end)
	self.topbarIcon.deselected:Connect(function() self:Close() end)
	Shared.AnimateButton(self.closeButton, function() return false end)
	Core:GetController("GamepadController"):OnActivated(self.closeButton, function() self.topbarIcon:deselect() end)
	local Gamepad = Core:GetController("GamepadController")
	Gamepad:RegisterMenu({
		Priority = 25,
		IsOpen = function()
			return self:IsOpen()
		end,
		Close = function()
			self.topbarIcon:deselect()
		end,
	})
	Gamepad:BindShortcut(Enum.KeyCode.ButtonY, function()
		self.topbarIcon:select()
	end)
end

function SettingController:Start()
	task.spawn(function()
		local Saved = RemoteManager:InvokeServer("SettingsService", "GetSettings")
		for Name, Value in pairs(Saved) do
			local Apply = self.applysetting[Name]
			if Apply then
				Apply(Value)
				self:Applyeffect(Name, Value)
			end
		end
	end)
end

return SettingController
