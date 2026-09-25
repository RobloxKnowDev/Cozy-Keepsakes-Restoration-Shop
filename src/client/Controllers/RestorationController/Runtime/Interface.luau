local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Tweenservice = game:GetService("TweenService")
local Userinputservice = game:GetService("UserInputService")

local Core = require(Replicatedstorage.Shared.Packages.Core)

local Interface = {}
Interface.__index = Interface

local Gamepadhintimage = "rbxassetid://126117246223823"
local Paneltween = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local Buttontween = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function Hinticon(Frame: GuiObject): ImageLabel
	if Frame:IsA("ImageLabel") then return Frame end
	return Frame:FindFirstChildWhichIsA("ImageLabel", true) :: ImageLabel
end

local function Animate(Button: GuiButton)
	local Scale = Button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", Button)
	Button.MouseEnter:Connect(function()
		Tweenservice:Create(Scale, Buttontween, { Scale = 1.08 }):Play()
	end)
	Button.MouseLeave:Connect(function()
		Tweenservice:Create(Scale, Buttontween, { Scale = 1 }):Play()
	end)
	Button.MouseButton1Down:Connect(function()
		Tweenservice:Create(Scale, Buttontween, { Scale = 0.92 }):Play()
	end)
	Button.MouseButton1Up:Connect(function()
		Tweenservice:Create(Scale, Buttontween, { Scale = 1.08 }):Play()
	end)
end

function Interface.new(Tools)
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local Gui = Playergui:WaitForChild("PackageUi")
	local Hud = Playergui:WaitForChild("HUD")
	local Self = setmetatable({ Gui = Gui, VisiblePositions = {}, Buttons = {} }, Interface)
	Self.Hud = Hud
	Self.FrameTool = Gui:WaitForChild("FrameTool")
	Self.TransformFrame = Gui:WaitForChild("TransformFrame")
	Self.ProgressFrame = Gui:WaitForChild("ProgressFrame")
	Self.PercentFrame = Gui:WaitForChild("PercentFrame")
	Self.Utilities = Gui:WaitForChild("Utilities")
	Self.Hintframes = {}
	for _, Hintname in ipairs({ "Put", "Use", "Pull" }) do
		local Frame = Self.Utilities:WaitForChild("Mouse" .. Hintname) :: GuiObject
		local Icon = Hinticon(Frame)
		Self.Hintframes[Hintname] = { Frame = Frame, Icon = Icon, MouseImage = Icon.Image }
	end
	Self.CurrentHint = nil
	Self.Cursor = Hud:WaitForChild("CurseurFrame")
	Self.Cursor.Visible = false
	Self.Cursor.Active = false
	Self.ReturnButton = Gui:WaitForChild("ReturnButton")
	Self.ContinueButton = Gui:WaitForChild("ContinueButton")
	Self.TurnButton = Self.TransformFrame:WaitForChild("TurnButton")
	Self.LockButton = Self.TransformFrame:WaitForChild("PadlockButton")
	Self.LockImage = Self.LockButton:WaitForChild("LockImage")
	Self.UnlockImage = Self.LockButton:WaitForChild("UnlockImage")
	for Name in pairs(Tools) do
		Self.Buttons[Name] = Self.FrameTool:WaitForChild(Name)
	end
	return Self
end

function Interface:SetPanel(Panel: GuiObject, Visible: boolean, Offset: Vector2)
	local Shown = self.VisiblePositions[Panel] or Panel.Position
	self.VisiblePositions[Panel] = Shown
	local Hidden = Shown + UDim2.fromOffset(Offset.X, Offset.Y)
	if Visible then
		Panel.Visible, Panel.Position = true, Hidden
		local Scale = Panel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", Panel)
		Scale.Scale = 0.94
		Tweenservice:Create(Panel, Paneltween, { Position = Shown }):Play()
		Tweenservice:Create(Scale, Paneltween, { Scale = 1 }):Play()
	else
		local Tween = Tweenservice:Create(Panel, Paneltween, { Position = Hidden })
		Tween:Play()
		Tween.Completed:Once(function()
			Panel.Visible, Panel.Position = false, Shown
		end)
	end
end

function Interface:Select(Name: string, Definition)
	for Toolname, Button in pairs(self.Buttons) do
		local Selected = Toolname == Name
		Button:SetAttribute("Selected", Selected)
		for _, Labelname in ipairs({ "Name", "Bio" }) do
			local Label = Button:FindFirstChild(Labelname)
			if Label and Label:IsA("GuiObject") then
				Label.Visible = Selected
			end
		end
		local Scale = Button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", Button)
		Tweenservice:Create(Scale, Buttontween, { Scale = Selected and 1.12 or 1 }):Play()
	end
	self:SetPanel(self.TransformFrame, Definition.EnablesInspection == true, Vector2.new(0, 20))
	self:SetPanel(self.ProgressFrame, Definition.ShowsProgress == true, Vector2.new(28, 0))
	self.CurrentHint = Definition.Hint
	self:RefreshHints()
end

function Interface:RefreshHints()
	local Gamepad = Core:GetController("GamepadController"):IsActive()
	for Hintname, Hint in pairs(self.Hintframes) do
		Hint.Frame.Visible = self.CurrentHint == Hintname
		Hint.Icon.Image = if Gamepad then Gamepadhintimage else Hint.MouseImage
	end
end

function Interface:Trigger(Button: GuiButton)
	self.Activate(Button)
end

function Interface:GetToolOrder(): { string }
	local Names = {}
	for Name in pairs(self.Buttons) do
		table.insert(Names, Name)
	end
	table.sort(Names, function(Left, Right)
		local Leftbutton, Rightbutton = self.Buttons[Left], self.Buttons[Right]
		if Leftbutton.LayoutOrder ~= Rightbutton.LayoutOrder then return Leftbutton.LayoutOrder < Rightbutton.LayoutOrder end
		if Leftbutton.AbsolutePosition.Y ~= Rightbutton.AbsolutePosition.Y then
			return Leftbutton.AbsolutePosition.Y < Rightbutton.AbsolutePosition.Y
		end
		if Leftbutton.AbsolutePosition.X ~= Rightbutton.AbsolutePosition.X then
			return Leftbutton.AbsolutePosition.X < Rightbutton.AbsolutePosition.X
		end
		return Left < Right
	end)
	return Names
end

function Interface:Start(Selecttool, Setmode, Flipobject, Continue)
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.Actions = {}
	local Lastactivations: { [GuiButton]: number } = {}
	local function Activate(Button: GuiButton)
		if Button == self.ContinueButton and self.ContinueLocked then
			return
		end
		local Callback = self.Actions[Button]
		if not Callback then
			return
		end
		local Now = os.clock()
		if Lastactivations[Button] and Now - Lastactivations[Button] < 0.25 then
			return
		end
		Lastactivations[Button] = Now
		Core:GetController("FeedbackController"):UiClick()
		Callback()
	end
	self.Activate = Activate
	Userinputservice.LastInputTypeChanged:Connect(function()
		task.defer(function()
			self:RefreshHints()
		end)
	end)
	for Name, Button in pairs(self.Buttons) do
		self.Actions[Button] = function()
			Selecttool(Name)
		end
	end
	for _, Button in ipairs({ self.TurnButton, self.LockButton, self.ReturnButton, self.ContinueButton }) do
		Animate(Button)
	end
	local Locked = false
	local function Refreshlock()
		self.LockImage.Visible, self.UnlockImage.Visible = Locked, not Locked
	end
	local function Setlocked(Value: boolean)
		Locked = Value
		Setmode(if Locked then "Rotate" else "Orbit")
		Refreshlock()
	end
	self.Resetlock = function()
		Setlocked(false)
	end
	self.Actions[self.TurnButton] = function()
		Setlocked(true)
	end
	self.Actions[self.LockButton] = function()
		Setlocked(not Locked)
	end
	self.Actions[self.ReturnButton] = Flipobject
	self.Actions[self.ContinueButton] = Continue
	for Button in pairs(self.Actions) do
		Core:GetController("GamepadController"):OnActivated(Button, function()
			Activate(Button)
		end)
	end
	local function Findbutton(Position: Vector2): GuiButton?
		for _, Object in ipairs(Playergui:GetGuiObjectsAtPosition(Position.X, Position.Y)) do
			local Current: Instance? = Object
			while Current and Current ~= Playergui do
				if self.Actions[Current] then
					return Current :: GuiButton
				end
				Current = Current.Parent
			end
		end
		return nil
	end
	local Pendingtouches: { [InputObject]: { Button: GuiButton, Position: Vector2 } } = {}
	Userinputservice.InputBegan:Connect(function(Input)
		if Input.UserInputType ~= Enum.UserInputType.Touch or not self.Gui.Enabled then
			return
		end
		local Position = Vector2.new(Input.Position.X, Input.Position.Y)
		local Button = Findbutton(Position)
		if Button then
			Pendingtouches[Input] = { Button = Button, Position = Position }
		end
	end)
	Userinputservice.InputEnded:Connect(function(Input)
		local Pending = Pendingtouches[Input]
		if not Pending then
			return
		end
		Pendingtouches[Input] = nil
		local Position = Vector2.new(Input.Position.X, Input.Position.Y)
		if (Position - Pending.Position).Magnitude <= 24 then
			Activate(Pending.Button)
		end
	end)
	self.Gui.Enabled = true
	self.TransformFrame.Visible, self.ProgressFrame.Visible = false, false
	self.Cursor.Visible, self.Cursor.AnchorPoint = false, Vector2.new(0.5, 0.5)
	Refreshlock()
end

function Interface:SetContinueLocked(Locked: boolean)
	self.ContinueLocked = Locked == true
end

function Interface:ShowForRestoration()
	self.Resetlock()
	for _, Item in ipairs({
		self.FrameTool,
		self.Utilities,
		self.PercentFrame,
		self.Cursor,
		self.ReturnButton,
		self.ContinueButton,
	}) do
		Item.Visible = true
	end
end

function Interface:ShowIntro()
	self.Gui.Enabled = true
	self:HideForCompletion()
	self.Cursor.Visible = false
end

function Interface:IsPointerOverUi(Position: Vector2): boolean
	for _, Item in ipairs({
		self.FrameTool,
		self.TransformFrame,
		self.ProgressFrame,
		self.PercentFrame,
		self.ReturnButton,
		self.ContinueButton,
	}) do
		if Item.Visible then
			local Minimum = Item.AbsolutePosition
			local Maximum = Minimum + Item.AbsoluteSize
			if
				Position.X >= Minimum.X
				and Position.Y >= Minimum.Y
				and Position.X <= Maximum.X
				and Position.Y <= Maximum.Y
			then
				return true
			end
		end
	end
	return false
end

function Interface:HideForCompletion()
	for _, Item in ipairs({
		self.FrameTool,
		self.Utilities,
		self.TransformFrame,
		self.ProgressFrame,
		self.PercentFrame,
		self.Cursor,
		self.ReturnButton,
		self.ContinueButton,
	}) do
		Item.Visible = false
	end
end

return Interface
