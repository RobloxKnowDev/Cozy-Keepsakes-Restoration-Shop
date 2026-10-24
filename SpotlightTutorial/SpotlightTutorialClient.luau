local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Tweenservice = game:GetService("TweenService")

local Steps = {
	{ Path = { "GameUi", "MenuTemplate", "PlayButton" }, Text = "Press Play to start!" },
	{ Path = { "GameUi", "CategoriesTemplate", "AppartmentsButton" }, Text = "Open the apartments!" },
	{
		Path = { "GameUi", "AppartmentsTemplates", "AppartmentsFrame", "ScrollingFrame", "BLittle Penthouse", "Button" },
		Text = "Pick the Little Penthouse!",
	},
	{ Path = { "GameUi", "AppartmentsTemplates", "LittlePenthouseVisual", "BuyButton" }, Text = "Buy it!" },
	{ Path = { "GameUi", "SlotsSaveFrame", "Save1Frame", "LoadButton" }, Text = "Load your apartment!" },
	{ Path = { "FurnituresGui", "ButtonsFrame", "FurnitureOpenButton" }, Text = "Open the furniture menu to decorate!" },
}

local Darkness = 0.35
local Padding = 8
local Textwidth = 420
local Textheight = 70
local Textgap = 14
local Edgemargin = 12
local Far = 10000
local Squarecolor = Color3.fromRGB(255, 214, 92)
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

local function Create(Class: string, Properties: { [string]: any }, Parent: Instance?): any
	local Object = Instance.new(Class)
	for Name, Value in pairs(Properties) do
		Object[Name] = Value
	end
	Object.Parent = Parent
	return Object
end

local Gui = Create("ScreenGui", {
	Name = "TutorialUi",
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
	Visible = false,
}, Gui)

local function Shade(): Frame
	return Create("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = Darkness,
		BorderSizePixel = 0,
		Active = true,
	}, Spotlight)
end

local Top, Bottom, Left, Right = Shade(), Shade(), Shade(), Shade()

local Square = Create("Frame", {
	BackgroundTransparency = 1,
	Active = false,
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
	ZIndex = 2,
}, Spotlight)
Create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2.5 }, Label)
Create("UITextSizeConstraint", { MaxTextSize = 32 }, Label)

local Skipbutton = Create("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -20, 1, -20),
	Size = UDim2.fromOffset(170, 44),
	BackgroundColor3 = Color3.fromRGB(30, 30, 30),
	BackgroundTransparency = 0.2,
	FontFace = Textfont,
	Text = "Skip tutorial",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 22,
	ZIndex = 3,
}, Gui)
Create("UICorner", { CornerRadius = UDim.new(0, 10) }, Skipbutton)

local Skipped = false
Skipbutton.Activated:Connect(function()
	Skipped = true
end)

local function Findtarget(Path: { string }): GuiButton
	local Current: Instance = Playergui
	for _, Name in ipairs(Path) do
		Current = Current:WaitForChild(Name)
	end
	return Current :: GuiButton
end

local function Isshown(Target: GuiObject): boolean
	local Current: Instance? = Target
	while Current ~= Playergui do
		if Current == nil then
			return false
		end
		if Current:IsA("GuiObject") and not Current.Visible then
			return false
		end
		if Current:IsA("LayerCollector") and not Current.Enabled then
			return false
		end
		Current = Current.Parent
	end
	return true
end

local function Place(Target: GuiObject)
	local Corner = Target.AbsolutePosition - Gui.AbsolutePosition - Vector2.new(Padding, Padding)
	local Size = Target.AbsoluteSize + Vector2.new(Padding * 2, Padding * 2)
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
	local X = math.clamp(Corner.X + Size.X / 2 - Textwidth / 2, Edgemargin, math.max(Screen.X - Textwidth - Edgemargin, Edgemargin))
	local Y = if Below then Corner.Y + Size.Y + Textgap else Corner.Y - Textgap - Textheight
	Label.Position = UDim2.fromOffset(X, Y)
end

local function Runstep(Step)
	Label.Text = Step.Text
	while true do
		local Target = Findtarget(Step.Path)
		local Clicked = false
		local Connection = Target.Activated:Connect(function()
			Clicked = true
		end)
		while not Clicked and not Skipped and Target:IsDescendantOf(Playergui) do
			local Shown = Isshown(Target)
			Spotlight.Visible = Shown
			if Shown then
				Place(Target)
			end
			Runservice.RenderStepped:Wait()
		end
		Connection:Disconnect()
		if Clicked or Skipped then
			return
		end
	end
end

for _, Step in ipairs(Steps) do
	Runstep(Step)
	if Skipped then
		break
	end
end

Completeevent:FireServer()
Gui:Destroy()
