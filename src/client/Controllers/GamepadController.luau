local Gamepadservice = game:GetService("GamepadService")
local Guiservice = game:GetService("GuiService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Userinputservice = game:GetService("UserInputService")

local Core = require(Replicatedstorage.Shared.Packages.Core)

local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")

local Gamepadcontroller = {
	Name = "GamepadController",
	Priority = 1,
}

export type Menu = {
	Priority: number,
	IsOpen: () -> boolean,
	Close: () -> (),
}

local Menus: { Menu } = {}
local Shortcuts: { [Enum.KeyCode]: () -> () } = {}
local Handlers: { [GuiButton]: () -> () } = setmetatable({}, { __mode = "k" }) :: any
local Worldpress: (() -> ())? = nil
local Lastpress: { [GuiButton]: number } = setmetatable({}, { __mode = "k" }) :: any
local Pressdebounce = 0.15
local Activeinputtype = Userinputservice:GetLastInputType()
local Emulatedmousetypes = {
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseButton3] = true,
}

local function Isshown(Object: Instance): boolean
	local Current: Instance? = Object
	while Current do
		if Current:IsA("GuiObject") then
			if not Current.Visible then return false end
		elseif Current:IsA("LayerCollector") then
			return Current.Enabled
		end
		Current = Current.Parent
	end
	return false
end

function Gamepadcontroller:GetButtonUnderCursor(): GuiButton?
	local Position = Userinputservice:GetMouseLocation() - Guiservice:GetGuiInset()
	local Candidates = {}
	for _, Object in ipairs(Playergui:GetGuiObjectsAtPosition(Position.X, Position.Y)) do
		if Object:IsA("GuiButton") and Object.Interactable and Isshown(Object) then
			table.insert(Candidates, Object)
		end
	end
	for _, Candidate in ipairs(Candidates) do
		local Covered = false
		for _, Other in ipairs(Candidates) do
			if Other ~= Candidate and Other:IsDescendantOf(Candidate) then
				Covered = true
				break
			end
		end
		if not Covered then return Candidate end
	end
	return nil
end

function Gamepadcontroller:OnActivated(Button: GuiButton, Callback: () -> ())
	local function Fire()
		local Now = os.clock()
		if Lastpress[Button] and Now - Lastpress[Button] < Pressdebounce then return end
		Lastpress[Button] = Now
		Callback()
	end
	Handlers[Button] = Fire
	Button.Activated:Connect(Fire)
	Button.Destroying:Connect(function()
		Handlers[Button] = nil
		Lastpress[Button] = nil
	end)
end

function Gamepadcontroller:Press(Button: GuiButton): boolean
	local Fire = Handlers[Button]
	if not Fire then return false end
	if Button:GetAttribute("SilentClick") ~= true then Core:GetController("FeedbackController"):UiClick() end
	Fire()
	return true
end

function Gamepadcontroller:IsGamepad(Inputtype: Enum.UserInputType): boolean
	return string.sub(Inputtype.Name, 1, 7) == "Gamepad"
end

function Gamepadcontroller:IsActive(): boolean
	return self:IsGamepad(Activeinputtype)
end

function Gamepadcontroller:RegisterMenu(Menu: Menu)
	table.insert(Menus, Menu)
	table.sort(Menus, function(Left, Right)
		return Left.Priority > Right.Priority
	end)
end

function Gamepadcontroller:GetOpenMenu(): Menu?
	for _, Menu in ipairs(Menus) do
		if Menu.IsOpen() then return Menu end
	end
	return nil
end

function Gamepadcontroller:BindShortcut(Keycode: Enum.KeyCode, Handler: () -> ())
	Shortcuts[Keycode] = Handler
end

function Gamepadcontroller:BindWorldPress(Handler: () -> ())
	Worldpress = Handler
end

function Gamepadcontroller:IsIdle(): boolean
	return not Guiservice.MenuIsOpen
		and self:GetOpenMenu() == nil
		and not Core:GetController("RestorationController"):IsEditingObject()
		and not Core:GetController("CompletionController"):IsVisible()
end

function Gamepadcontroller:Start()
	Guiservice.AutoSelectGuiEnabled = false
	Userinputservice.InputBegan:Connect(function(Input, Processed)
		if not self:IsGamepad(Input.UserInputType) or Guiservice.MenuIsOpen then return end
		if Input.KeyCode == Enum.KeyCode.ButtonA then
			local Button = self:GetButtonUnderCursor()
			if Button then
				self:Press(Button)
			elseif Worldpress and self:IsIdle() then
				Worldpress()
			end
			return
		end
		if Input.KeyCode == Enum.KeyCode.ButtonB then
			local Menu = self:GetOpenMenu()
			if Menu then Menu.Close() end
			return
		end
		if Processed then return end
		local Shortcut = Shortcuts[Input.KeyCode]
		if Shortcut and self:IsIdle() then Shortcut() end
	end)
	Userinputservice.LastInputTypeChanged:Connect(function(Inputtype)
		if Emulatedmousetypes[Inputtype] and Gamepadservice.GamepadCursorEnabled then return end
		Activeinputtype = Inputtype
	end)
	Runservice.RenderStepped:Connect(function()
		local Wanted = self:IsActive()
		if Wanted and not Gamepadservice.GamepadCursorEnabled then
			Gamepadservice:EnableGamepadCursor(nil)
		elseif not Wanted and Gamepadservice.GamepadCursorEnabled then
			Gamepadservice:DisableGamepadCursor()
		end
	end)
end

return Gamepadcontroller
