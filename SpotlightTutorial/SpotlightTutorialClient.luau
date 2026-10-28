local Guiservice = game:GetService("GuiService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Tweenservice = game:GetService("TweenService")
local Userinputservice = game:GetService("UserInputService")

local Darkness = 0.35
local Padding = 8
local Widepadding = 28
local Textwidth = 420
local Textheight = 70
local Textgap = 14
local Edgemargin = 12
local Far = 10000
local Squarecolor = Color3.new(1, 1, 1)
local Textfont = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local Pulsetween = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local Player = Players.LocalPlayer
local Playergui = Player:WaitForChild("PlayerGui")
local Remotes = Replicatedstorage:WaitForChild("TutorialRemotes")
local Getcompleted = Remotes:WaitForChild("GetCompleted")
local Completeevent = Remotes:WaitForChild("Complete")

if Getcompleted:InvokeServer() then
	return
end

type Step = {
	GuiName: string,
	TargetProvider: () -> GuiButton,
	Target: GuiButton?,
	Resolution: thread?,
	Ancestryconnection: RBXScriptConnection?,
	Text: string,
	Padding: number?,
	AllowCamera: boolean?,
}

local Steps: { Step } = {
	{
		GuiName = "GameUi",
		TargetProvider = function()
			local Gameui = Playergui:WaitForChild("GameUi")
			local Menutemplate = Gameui:WaitForChild("MenuTemplate")
			return Menutemplate:WaitForChild("PlayButton") :: GuiButton
		end,
		Text = "Press Play to start!",
	},
	{
		GuiName = "GameUi",
		TargetProvider = function()
			local Gameui = Playergui:WaitForChild("GameUi")
			local Categoriestemplate = Gameui:WaitForChild("CategoriesTemplate")
			return Categoriestemplate:WaitForChild("AppartmentsButton") :: GuiButton
		end,
		Text = "Open the apartments!",
	},
	{
		GuiName = "GameUi",
		TargetProvider = function()
			local Gameui = Playergui:WaitForChild("GameUi")
			local Appartmentstemplates = Gameui:WaitForChild("AppartmentsTemplates")
			local Appartmentsframe = Appartmentstemplates:WaitForChild("AppartmentsFrame")
			local Scrollingframe = Appartmentsframe:WaitForChild("ScrollingFrame")
			local Littlepenthousecard = Scrollingframe:WaitForChild("BLittle Penthouse")
			return Littlepenthousecard:WaitForChild("Button") :: GuiButton
		end,
		Text = "Pick the Little Penthouse!",
		Padding = Widepadding,
	},
	{
		GuiName = "GameUi",
		TargetProvider = function()
			local Gameui = Playergui:WaitForChild("GameUi")
			local Appartmentstemplates = Gameui:WaitForChild("AppartmentsTemplates")
			local Littlepenthousevisual = Appartmentstemplates:WaitForChild("LittlePenthouseVisual")
			return Littlepenthousevisual:WaitForChild("BuyButton") :: GuiButton
		end,
		Text = "Buy the Little Penthouse!",
		Padding = Widepadding,
	},
	{
		GuiName = "GameUi",
		TargetProvider = function()
			local Gameui = Playergui:WaitForChild("GameUi")
			local Slotssaveframe = Gameui:WaitForChild("SlotsSaveFrame")
			local Save1frame = Slotssaveframe:WaitForChild("Save1Frame")
			return Save1frame:WaitForChild("LoadButton") :: GuiButton
		end,
		Text = "Load your apartment!",
		Padding = Widepadding,
	},
	{
		GuiName = "FurnituresGui",
		TargetProvider = function()
			local Furnituresgui = Playergui:WaitForChild("FurnituresGui")
			local Buttonsframe = Furnituresgui:WaitForChild("ButtonsFrame")
			return Buttonsframe:WaitForChild("FurnitureOpenButton") :: GuiButton
		end,
		Text = "Open the furniture menu to decorate!",
		AllowCamera = true,
	},
}

local function Resolvetarget(Step: Step)
	if Step.Resolution then
		task.cancel(Step.Resolution)
	end
	if Step.Ancestryconnection then
		Step.Ancestryconnection:Disconnect()
		Step.Ancestryconnection = nil
	end
	Step.Target = nil
	Step.Resolution = task.defer(function()
		local Target = Step.TargetProvider()
		Step.Target = Target
		Step.Resolution = nil
		Step.Ancestryconnection = Target.AncestryChanged:Connect(function()
			if not Target:IsDescendantOf(Playergui) then
				Resolvetarget(Step)
			end
		end)
	end)
end

local Removedconnection = Playergui.ChildRemoved:Connect(function(Child)
	for _, Step in ipairs(Steps) do
		if Child.Name == Step.GuiName then
			Resolvetarget(Step)
		end
	end
end)

for _, Step in ipairs(Steps) do
	Resolvetarget(Step)
end

local function Create(Class: string, Properties: { [string]: any }, Parent: Instance?): any
	local Object = Instance.new(Class)
	for Name, Value in pairs(Properties) do
		Object[Name] = Value
	end
	Object.Parent = Parent
	return Object
end

local Gui = Create("ScreenGui", {
	Name = "SpotlightTutorialUi",
	ResetOnSpawn = false,
	ScreenInsets = Enum.ScreenInsets.None,
	ClipToDeviceSafeArea = false,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, Playergui)

local Spotlight = Create("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Active = false,
	Selectable = false,
	Visible = false,
}, Gui)

local function Shade(): Frame
	return Create("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = Darkness,
		BorderSizePixel = 0,
		Active = true,
		Selectable = false,
	}, Spotlight)
end

local Top, Bottom, Left, Right = Shade(), Shade(), Shade(), Shade()

local Square = Create("Frame", {
	BackgroundTransparency = 1,
	Active = false,
	Selectable = false,
	ZIndex = 2,
}, Spotlight)
Create("UICorner", { CornerRadius = UDim.new(0, 6) }, Square)
local Squarestroke = Create("UIStroke", { Color = Squarecolor, Thickness = 3 }, Square)
Tweenservice:Create(Squarestroke, Pulsetween, { Thickness = 6 }):Play()

local Label = Create("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(Textwidth, Textheight),
	FontFace = Textfont,
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
	TextWrapped = true,
	Active = false,
	Selectable = false,
	ZIndex = 2,
}, Spotlight)
Create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2.5 }, Label)
Create("UITextSizeConstraint", { MaxTextSize = 32 }, Label)

local function Isshown(Target: GuiObject): boolean
	local Targetposition = Target.AbsolutePosition
	local Targetsize = Target.AbsoluteSize
	local Targetcenter = Targetposition + Targetsize / 2
	local Guiposition = Gui.AbsolutePosition
	local Guimaximum = Guiposition + Gui.AbsoluteSize
	if
		Targetsize.X <= 0
		or Targetsize.Y <= 0
		or Targetcenter.X < Guiposition.X
		or Targetcenter.Y < Guiposition.Y
		or Targetcenter.X > Guimaximum.X
		or Targetcenter.Y > Guimaximum.Y
	then
		return false
	end
	local Current: Instance? = Target
	while Current ~= Playergui do
		if Current == nil then
			return false
		end
		if Current:IsA("GuiObject") then
			if not Current.Visible then
				return false
			end
		end
		if Current:IsA("LayerCollector") and not Current.Enabled then
			return false
		end
		Current = Current.Parent
	end
	return true
end

local function Place(Target: GuiObject, Space: number)
	local Minimum = Target.AbsolutePosition - Gui.AbsolutePosition - Vector2.new(Space, Space)
	local Maximum = Minimum + Target.AbsoluteSize + Vector2.new(Space * 2, Space * 2)
	local Corner = Vector2.new(math.floor(Minimum.X), math.floor(Minimum.Y))
	local Size = Vector2.new(math.ceil(Maximum.X), math.ceil(Maximum.Y)) - Corner
	local Screen = Gui.AbsoluteSize
	Top.Position = UDim2.fromOffset(-Far, -Far)
	Top.Size = UDim2.fromOffset(Screen.X + Far * 2, Far + Corner.Y)
	Bottom.Position = UDim2.fromOffset(-Far, Corner.Y + Size.Y)
	Bottom.Size = UDim2.fromOffset(Screen.X + Far * 2, Far + Screen.Y)
	Left.Position = UDim2.fromOffset(-Far, Corner.Y)
	Left.Size = UDim2.fromOffset(Far + Corner.X, Size.Y)
	Right.Position = UDim2.fromOffset(Corner.X + Size.X, Corner.Y)
	Right.Size = UDim2.fromOffset(Far + Screen.X, Size.Y)
	Square.Position = UDim2.fromOffset(Corner.X, Corner.Y)
	Square.Size = UDim2.fromOffset(Size.X, Size.Y)
	local Below = Corner.Y + Size.Y + Textgap + Textheight <= Screen.Y - Edgemargin
	local Width = math.min(Textwidth, math.max(Screen.X - Edgemargin * 2, 0))
	local X = math.clamp(
		Corner.X + Size.X / 2 - Width / 2,
		Edgemargin,
		math.max(Screen.X - Width - Edgemargin, Edgemargin)
	)
	local Preferredy = if Below then Corner.Y + Size.Y + Textgap else Corner.Y - Textgap - Textheight
	local Y = math.clamp(Preferredy, Edgemargin, math.max(Screen.Y - Textheight - Edgemargin, Edgemargin))
	Label.Size = UDim2.fromOffset(Width, Textheight)
	Label.Position = UDim2.fromOffset(X, Y)
end

local function Enablecamera(Target: GuiButton)
	local Buttonstates: { [GuiButton]: { Interactable: boolean, Active: boolean } } = {}

	local function Disablebutton(Object: Instance)
		if Object:IsA("GuiButton") and Object ~= Target and not Object:IsDescendantOf(Target) and Buttonstates[Object] == nil then
			Buttonstates[Object] = {
				Interactable = Object.Interactable,
				Active = Object.Active,
			}
			Object.Interactable = false
			Object.Active = false
		end
	end

	Top.Active = false
	Bottom.Active = false
	Left.Active = false
	Right.Active = false

	for _, Object in ipairs(Playergui:GetDescendants()) do
		Disablebutton(Object)
	end

	local Addedconnection = Playergui.DescendantAdded:Connect(Disablebutton)

	local function Restore()
		Addedconnection:Disconnect()
		for Button, State in pairs(Buttonstates) do
			if Button.Parent then
				Button.Interactable = State.Interactable
				Button.Active = State.Active
			end
		end
		Top.Active = true
		Bottom.Active = true
		Left.Active = true
		Right.Active = true
	end

	return Restore
end

local function Enablegamepad(Target: GuiButton)
	local Active = Target.Active
	local Selectable = Target.Selectable
	local Navigationenabled = Guiservice.GuiNavigationEnabled
	local Usinggamepad = false

	local function Restoreinput()
		if not Usinggamepad then
			return
		end
		if Guiservice.SelectedObject == Target then
			Guiservice.SelectedObject = nil
		end
		Guiservice.GuiNavigationEnabled = Navigationenabled
		Target.Active = Active
		Target.Selectable = Selectable
		Usinggamepad = false
	end

	local function Update(Shown: boolean)
		if Userinputservice.PreferredInput ~= Enum.PreferredInput.Gamepad then
			Restoreinput()
			return
		end
		if Guiservice.MenuIsOpen or not Shown or not Target.Interactable then
			Restoreinput()
			return
		end
		if Usinggamepad then
			return
		end
		Active = Target.Active
		Selectable = Target.Selectable
		Navigationenabled = Guiservice.GuiNavigationEnabled
		Target.Active = true
		Target.Selectable = true
		Guiservice.GuiNavigationEnabled = true
		Guiservice.SelectedObject = Target
		Usinggamepad = true
	end

	return Update, Restoreinput
end

local function Runstep(Step: Step, Index: number)
	local Finished = false
	local Activated = false
	local Allowcamera = Step.AllowCamera == true
	local Currenttarget = nil
	local Lasttarget = nil
	local Activatedconnection = nil
	local Clickconnection = nil
	local Updategamepad = nil
	local Restoregamepad = nil
	local Restorecamera = nil

	local function Pressed()
		Activated = true
		if Index == #Steps then
			Finished = true
		end
	end

	local function Disconnectpress()
		if Activatedconnection then
			Activatedconnection:Disconnect()
			Clickconnection:Disconnect()
			Activatedconnection, Clickconnection = nil, nil
		end
	end

	local function Releaseinput()
		if Restoregamepad then
			Restoregamepad()
		end
		if Restorecamera then
			Restorecamera()
			Restorecamera = nil
		end
	end

	local Inputconnection = Userinputservice.InputBegan:Connect(function(Input)
		local Inputtype = Input.UserInputType
		if Inputtype ~= Enum.UserInputType.MouseButton1 and Inputtype ~= Enum.UserInputType.Touch then
			return
		end
		if Spotlight.Visible and table.find(Playergui:GetGuiObjectsAtPosition(Input.Position.X, Input.Position.Y), Currenttarget) then
			Pressed()
		end
	end)

	Spotlight.Visible = false
	Label.Text = Step.Text
	while not Finished do
		local Target = Step.Target
		if Target then
			Lasttarget = Target
		end
		if Target ~= Currenttarget then
			Releaseinput()
			Disconnectpress()
			Updategamepad, Restoregamepad = nil, nil
			Currenttarget = Target
			if Target then
				Updategamepad, Restoregamepad = Enablegamepad(Target)
				Activatedconnection = Target.Activated:Connect(Pressed)
				Clickconnection = Target.MouseButton1Click:Connect(Pressed)
			end
		end
		local Nextstep = Steps[Index + 1]
		local Nexttarget = if Nextstep then Nextstep.Target else nil
		if Nexttarget and Isshown(Nexttarget) and (Activated or (Lasttarget and not Isshown(Lasttarget))) then
			break
		end
		local Shown = Target ~= nil and Isshown(Target) and Target.Interactable
		if Shown and Target then
			if Allowcamera and not Restorecamera then
				Restorecamera = Enablecamera(Target)
			end
			Place(Target, Step.Padding or Padding)
		else
			Releaseinput()
		end
		Spotlight.Visible = Shown
		if Updategamepad then
			Updategamepad(Shown)
		end
		Runservice.RenderStepped:Wait()
	end
	Inputconnection:Disconnect()
	Releaseinput()
	Disconnectpress()
	Spotlight.Visible = false
end

for Index, Step in ipairs(Steps) do
	Runstep(Step, Index)
end

Removedconnection:Disconnect()
for _, Step in ipairs(Steps) do
	if Step.Resolution then
		task.cancel(Step.Resolution)
	end
	if Step.Ancestryconnection then
		Step.Ancestryconnection:Disconnect()
	end
end

Completeevent:FireServer()
Gui:Destroy()
