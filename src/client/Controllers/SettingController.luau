local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local ControlTweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DefaultVolume = 0.5

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

function SettingController:BindToggle(Setting: Frame, Name: string)
	local FrameBar = Setting:WaitForChild("FrameBar")
	local Bar = FrameBar:WaitForChild("Bar")
	local Text1 = FrameBar:WaitForChild("Text1")
	local Text2 = FrameBar:WaitForChild("Text2")
	local Enabled = true
	local EnabledPosition = Bar.Position
	local EnabledColor = Bar.BackgroundColor3
	local EnabledRotation = Bar.Rotation
	local Padding = Bar.AbsolutePosition.X - FrameBar.AbsolutePosition.X
	Text1.Visible = true
	Text2.Visible = false
	Shared.AnimateButton(Bar, function() return false end)
	local Lasttoggle = 0
	local function Apply(Value: boolean, Animate: boolean)
		Enabled = Value
		local DisabledPosition = UDim2.new(
			1,
			-Padding - Bar.AbsoluteSize.X * (1 - Bar.AnchorPoint.X),
			EnabledPosition.Y.Scale,
			EnabledPosition.Y.Offset
		)
		Text1.Visible = Enabled
		Text2.Visible = not Enabled
		local Goal = {
			Position = if Enabled then EnabledPosition else DisabledPosition,
			BackgroundColor3 = if Enabled then EnabledColor else self.disabledColor,
			Rotation = if Enabled then EnabledRotation else EnabledRotation + 180,
		}
		if Animate then
			TweenService:Create(Bar, ControlTweenInfo, Goal):Play()
			return
		end
		Bar.Position = Goal.Position
		Bar.BackgroundColor3 = Goal.BackgroundColor3
		Bar.Rotation = Goal.Rotation
	end
	local function Toggle()
		local Now = os.clock()
		if Now - Lasttoggle < 0.1 then return end
		Lasttoggle = Now
		Apply(not Enabled, true)
		RemoteManager:FireServer("SettingsService", "SetSetting", Name, Enabled)
	end
	local function Ontogglepress(Input: InputObject)
		if
			Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.Touch
		then
			Toggle()
		end
	end
	FrameBar.Active = true
	FrameBar.InputBegan:Connect(Ontogglepress)
	Bar.InputBegan:Connect(Ontogglepress)
	self.applysetting[Name] = function(Value)
		Apply(Value == true, false)
	end
end

function SettingController:BindSlider(Setting: Frame, Name: string)
	local FrameBar = Setting:WaitForChild("FrameBar")
	local Bar = FrameBar:WaitForChild("Bar")
	local PourcentageText = Setting:WaitForChild("PourcentageText")
	local Dragging = false
	local Current = DefaultVolume
	FrameBar.Active = true
	local function Apply(Alpha: number)
		Current = Alpha
		Bar.Size = UDim2.new(Alpha, 0, Bar.Size.Y.Scale, Bar.Size.Y.Offset)
		PourcentageText.Text = string.format("%d%%", math.round(Alpha * 100))
	end
	local function Update(Position: Vector3)
		Apply(math.clamp((Position.X - FrameBar.AbsolutePosition.X) / FrameBar.AbsoluteSize.X, 0, 1))
	end
	Apply(DefaultVolume)
	FrameBar.InputBegan:Connect(function(Input)
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
		Dragging = true
		Update(Input.Position)
	end)
	UserInputService.InputChanged:Connect(function(Input)
		if not Dragging then return end
		if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
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
	self.applysetting[Name] = Apply
end

function SettingController:Init()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	self.ui = PlayerGui:WaitForChild("SettingUi")
	self.frame = self.ui:WaitForChild("Frame")
	local Settings = self.frame:WaitForChild("Frame")
	self.exitButton = self.frame:WaitForChild("ExitButton")
	self.disabledColor = self.exitButton.BackgroundColor3
	self.isOpen = false
	self.framePosition = self.frame.Position
	self.frameScale = Shared.EnsureScale(self.frame)
	self.frame.Visible = false
	self.frame.Active = true
	self.applysetting = {}

	self:BindToggle(Settings:WaitForChild("Graphism"), "Graphism")
	self:BindToggle(Settings:WaitForChild("Effect"), "Effect")
	self:BindSlider(Settings:WaitForChild("MusicVolume"), "MusicVolume")
	self:BindSlider(Settings:WaitForChild("SoundEffect"), "SoundEffect")

	self.topbarIcon = Icon.new()
		:setName("Settings")
		:setImage("rbxassetid://92246988918469")
		:modifyTheme({ "IconImage", "ImageColor3", Color3.fromRGB(255, 255, 255) })
		:setCaption("Settings")
	self.topbarIcon.selected:Connect(function() self:Open() end)
	self.topbarIcon.deselected:Connect(function() self:Close() end)
	Shared.AnimateButton(self.exitButton, function() return false end)
	self.exitButton.Activated:Connect(function() self.topbarIcon:deselect() end)
end

function SettingController:Start()
	task.spawn(function()
		local Saved = RemoteManager:InvokeServer("SettingsService", "GetSettings")
		for Name, Value in pairs(Saved) do
			local Apply = self.applysetting[Name]
			if Apply then
				Apply(Value)
			end
		end
	end)
end

return SettingController
