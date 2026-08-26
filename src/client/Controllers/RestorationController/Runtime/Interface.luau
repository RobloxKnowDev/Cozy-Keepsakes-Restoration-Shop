local Players = game:GetService("Players")
local Tweenservice = game:GetService("TweenService")

local Interface = {}
Interface.__index = Interface

local Paneltween = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local Buttontween = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function Animate(Button: GuiButton)
	local Scale = Button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", Button)
	Button.MouseEnter:Connect(function() Tweenservice:Create(Scale, Buttontween, { Scale = 1.08 }):Play() end)
	Button.MouseLeave:Connect(function() Tweenservice:Create(Scale, Buttontween, { Scale = 1 }):Play() end)
	Button.MouseButton1Down:Connect(function() Tweenservice:Create(Scale, Buttontween, { Scale = 0.92 }):Play() end)
	Button.MouseButton1Up:Connect(function() Tweenservice:Create(Scale, Buttontween, { Scale = 1.08 }):Play() end)
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
	Self.Cursor = Hud:WaitForChild("CurseurFrame")
	Self.ProgressText = Gui:WaitForChild("Progress")
	Self.ReturnButton = Gui:WaitForChild("ReturnButton")
	Self.ContinueButton = Gui:WaitForChild("ContinueButton")
	Self.TurnButton = Self.TransformFrame:WaitForChild("TurnButton")
	Self.LockButton = Self.TransformFrame:WaitForChild("PadlockButton")
	Self.LockImage = Self.LockButton:WaitForChild("LockImage")
	Self.UnlockImage = Self.LockButton:WaitForChild("UnlockImage")
	for Name in pairs(Tools) do Self.Buttons[Name] = Self.FrameTool:WaitForChild(Name) end
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
		Tween.Completed:Once(function() Panel.Visible, Panel.Position = false, Shown end)
	end
end

function Interface:Select(Name: string, Definition)
	for Toolname, Button in pairs(self.Buttons) do
		local Selected = Toolname == Name
		Button:SetAttribute("Selected", Selected)
		for _, Labelname in ipairs({ "Name", "Bio" }) do
			local Label = Button:FindFirstChild(Labelname)
			if Label and Label:IsA("GuiObject") then Label.Visible = Selected end
		end
		local Scale = Button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", Button)
		Tweenservice:Create(Scale, Buttontween, { Scale = Selected and 1.12 or 1 }):Play()
	end
	self:SetPanel(self.TransformFrame, Definition.EnablesInspection == true, Vector2.new(0, 20))
	self:SetPanel(self.ProgressFrame, Definition.ShowsProgress == true, Vector2.new(28, 0))
end

function Interface:Start(Selecttool, Setmode, Flipobject, Continue)
	for Name, Button in pairs(self.Buttons) do
		Button.BackgroundTransparency = 0.7
		Button.Activated:Connect(function() Selecttool(Name) end)
	end
	for _, Button in ipairs({ self.TurnButton, self.LockButton, self.ReturnButton, self.ContinueButton }) do
		Animate(Button)
	end
	self.TurnButton.BackgroundTransparency = 0
	local Locked = false
	local function Refreshlock()
		self.LockImage.Visible, self.UnlockImage.Visible = Locked, not Locked
		self.LockButton.BackgroundTransparency = 0
	end
	self.TurnButton.Activated:Connect(function() Locked = false Setmode("Rotate") Refreshlock() end)
	self.LockButton.Activated:Connect(function() Locked = not Locked Setmode(Locked and "Locked" or "Rotate") Refreshlock() end)
	self.ReturnButton.Activated:Connect(Flipobject)
	self.ContinueButton.Activated:Connect(Continue)
	self.Gui.Enabled = true
	self.TransformFrame.Visible, self.ProgressFrame.Visible = false, false
	self.Cursor.Visible, self.Cursor.AnchorPoint = true, Vector2.new(0.5, 0.5)
	Refreshlock()
end

function Interface:ShowForRestoration()
	for _, Item in ipairs({
		self.FrameTool,
		self.PercentFrame,
		self.Cursor,
		self.ReturnButton,
		self.ProgressText,
		self.ContinueButton,
	}) do
		Item.Visible = true
	end
end

function Interface:ShowIntro()
	self.Gui.Enabled = true
	self:HideForCompletion()
	self.Cursor.Visible = true
end

function Interface:IsPointerOverUi(Position: Vector2): boolean
	for _, Item in ipairs({
		self.FrameTool,
		self.TransformFrame,
		self.ProgressFrame,
		self.PercentFrame,
		self.ReturnButton,
		self.ProgressText,
		self.ContinueButton,
	}) do
		if Item.Visible then
			local Minimum = Item.AbsolutePosition
			local Maximum = Minimum + Item.AbsoluteSize
			if Position.X >= Minimum.X and Position.Y >= Minimum.Y and Position.X <= Maximum.X and Position.Y <= Maximum.Y then
				return true
			end
		end
	end
	return false
end

function Interface:HideForCompletion()
	for _, Item in ipairs({
		self.FrameTool,
		self.TransformFrame,
		self.ProgressFrame,
		self.PercentFrame,
		self.Cursor,
		self.ReturnButton,
		self.ProgressText,
		self.ContinueButton,
	}) do
		Item.Visible = false
	end
end

return Interface
