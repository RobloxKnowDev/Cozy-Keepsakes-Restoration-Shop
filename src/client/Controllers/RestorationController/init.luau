local Guiservice = game:GetService("GuiService")
local Gamepadservice = game:GetService("GamepadService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Startergui = game:GetService("StarterGui")
local Userinputservice = game:GetService("UserInputService")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)
local Interfacemodule = require(script.Runtime.Interface)
local Toolruntime = require(script.Runtime.ToolRuntime)

local Tools = {}
for _, Module in ipairs(script:GetChildren()) do
	if Module:IsA("ModuleScript") then
		local Tool = require(Module)
		Tools[Tool.Name] = Tool
	end
end

local Controller = {
	Name = "RestorationController",
	Priority = 5,
	pendingEnter = false,
	entering = false,
}
local Interface = Interfacemodule.new(Tools)
local Runtime = Toolruntime.new(Tools, Interface)
local Activeobject: (Model | BasePart)? = nil
local Player = Players.LocalPlayer

local function Lockcharacter(Character: Model)
	local Humanoid = Character:WaitForChild("Humanoid", 10)
	if not Humanoid or not Humanoid:IsA("Humanoid") then return end
	Humanoid.WalkSpeed = 0
	Humanoid.JumpPower = 0
	Humanoid.JumpHeight = 0
	Humanoid.AutoRotate = false
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
end

local function Disableplayercontrols()
	local Playerscripts = Player:WaitForChild("PlayerScripts")
	local Playermodule = Playerscripts:WaitForChild("PlayerModule")
	local Controls = require(Playermodule):GetControls()
	Controls:Disable()

	if Userinputservice.TouchEnabled then
		Userinputservice.ModalEnabled = true
		local Playergui = Player:WaitForChild("PlayerGui")
		local Touchgui = Playergui:FindFirstChild("TouchGui")
		if Touchgui and Touchgui:IsA("ScreenGui") then Touchgui.Enabled = false end
		Playergui.ChildAdded:Connect(function(Child)
			if Child.Name == "TouchGui" and Child:IsA("ScreenGui") then Child.Enabled = false end
		end)
	end

	if Player.Character then
		task.spawn(Lockcharacter, Player.Character)
	end
	Player.CharacterAdded:Connect(Lockcharacter)

	task.spawn(function()
		for _ = 1, 20 do
			if pcall(function()
				Startergui:SetCore("ResetButtonCallback", false)
			end) then
				return
			end
			task.wait(0.25)
		end
		warn("RestorationController: could not disable the Reset button")
	end)
end

local function Showcompletion()
	local Completion = Core:GetController("CompletionController")
	if Completion:IsVisible() or not Activeobject then return end
	Runtime:Destroy()
	Core:GetController("InspectionCameraController"):PrepareCompletion()
	Interface:HideForCompletion()
	Completion:Show(Activeobject, function()
		Remotemanager:InvokeServer("RestorationService", "CompleteRestoration")
		Remotemanager:FireServer("RestorationService", "SessionEnded")
		local Cameracontroller = Core:GetController("InspectionCameraController")
		Cameracontroller:End()
		Cameracontroller:ShowIntroCamera()
		Activeobject = nil
		Runtime:SetObject(nil)
		Interface:ShowIntro()
		Completion:Hide()
		Core:GetController("ExpositionController"):CompleteRestoration()
	end)
end

local function Updateprogress(InteractionPosition: Vector2?)
	if Activeobject then
		Core:GetController("ProgressController"):Update(Activeobject, InteractionPosition)
	end
end

function Controller:GetInterface()
	return Interface
end

function Controller:GetActiveObject(): (Model | BasePart)?
	return Activeobject
end

function Controller:SelectTool(Name: string)
	Runtime:Select(Name)
end

function Controller:IsEditingObject(): boolean
	return Activeobject ~= nil or self.pendingEnter or self.entering
end

function Controller:CanEnter(): boolean
	return not Core:GetController("ComputerController"):IsOpen()
		and not Core:GetController("CustomerController"):IsVisible()
		and not Core:GetController("CompletionController"):IsVisible()
end

function Controller:Enter()
	if Activeobject or self.entering then
		self.pendingEnter = true
		return
	end
	Core:GetController("DailyRewardController"):CloseForSwitch()
	Core:GetController("SettingController"):CloseForSwitch()
	local Expositioncontroller = Core:GetController("ExpositionController")
	Expositioncontroller:PrepareForRestoration()
	if not self:CanEnter() then
		self.pendingEnter = true
		return
	end
	self.pendingEnter = false
	self.entering = true
	local Object = Remotemanager:InvokeServer("RestorationService", "BeginSession")
	self.entering = false
	if not Object or (not Object:IsA("BasePart") and not Object:IsA("Model")) then
		Expositioncontroller:CancelRestoration()
		return
	end
	Activeobject = Object
	Core:GetController("CleaningController"):PreloadOverlays(Object)
	Runtime:SetObject(Object)
	Core:GetController("CompletionController"):Hide()
	Core:GetController("InspectionCameraController"):Begin(Object)
	Interface.Gui.Enabled = true
	Interface:ShowForRestoration()
	Interface.ProgressText.Visible = true
	Userinputservice.MouseBehavior = Enum.MouseBehavior.Default
	Updateprogress()
	Runtime:Select("Transform")
end

function Controller:ResumePendingEnter()
	if self.pendingEnter then self:Enter() end
end

function Controller:Start()
	local Cameracontroller = Core:GetController("InspectionCameraController")
	Disableplayercontrols()
	Interface:Start(
		function(Name) Runtime:Select(Name) end,
		function(Mode) Cameracontroller:SetTransformMode(Mode) end,
		function() Cameracontroller:FlipObject() end,
		function() Showcompletion() end
	)
	Cameracontroller:SetTransformMode("Rotate")
	Cameracontroller:ShowIntroCamera()
	Interface:ShowIntro()
	Core:GetController("CompletionController"):Hide()
	Userinputservice.MouseIconEnabled = true
	Gamepadservice:DisableGamepadCursor()

	Userinputservice.InputBegan:Connect(function(Input, Processed)
		if Processed or not Activeobject or Core:GetController("CompletionController"):IsVisible() then return end
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			Runtime:InputBegan()
		elseif Input.UserInputType == Enum.UserInputType.Touch then
			Runtime:Update(0)
			Runtime:InputBegan()
		end
	end)
	Userinputservice.InputEnded:Connect(function(Input)
		if not Activeobject or Core:GetController("CompletionController"):IsVisible() then return end
		if
			Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.Touch
		then
			Runtime:InputEnded()
		end
	end)
	Runservice.RenderStepped:Connect(function(Deltatime)
		if self.pendingEnter then self:Enter() end
		local ScreenMouse = Userinputservice:GetMouseLocation()
		local Mouse = ScreenMouse
		if not Interface.Hud.IgnoreGuiInset then Mouse -= Guiservice:GetGuiInset() end
		Interface.Cursor.Position = UDim2.fromOffset(Mouse.X, Mouse.Y)
		local Isediting = Activeobject ~= nil and not Core:GetController("CompletionController"):IsVisible()
		local Showgamepadcursor = Isediting and Userinputservice:GetLastInputType() == Enum.UserInputType.Gamepad1
		if Showgamepadcursor and not Gamepadservice.GamepadCursorEnabled then
			Gamepadservice:EnableGamepadCursor(nil)
		elseif not Showgamepadcursor and Gamepadservice.GamepadCursorEnabled then
			Gamepadservice:DisableGamepadCursor()
		end
		Interface.Cursor.Visible = Isediting and Userinputservice:GetLastInputType() ~= Enum.UserInputType.Touch
		if not Isediting then return end
		Runtime:Update(Deltatime)
		Updateprogress(ScreenMouse)
	end)
end

return Controller
