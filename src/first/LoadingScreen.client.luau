local Players = game:GetService("Players")
local Replicatedfirst = game:GetService("ReplicatedFirst")
local Tweenservice = game:GetService("TweenService")

local Displayorder = 10000
local Fadeduration = 0.6
local Maximumwait = 25
local Dotinterval = 0.35
local Loadingframes = {
	'Loading.<font transparency="1">..</font>',
	'Loading..<font transparency="1">.</font>',
	"Loading...",
}
local Pulsescale = 1.06
local Pulseinfo = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local Textfont = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)

local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")

local Gui = Instance.new("ScreenGui")
Gui.Name = "LoadingUi"
Gui.DisplayOrder = Displayorder
Gui.IgnoreGuiInset = true
Gui.ClipToDeviceSafeArea = false
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Cover = Instance.new("Frame")
Cover.Name = "Cover"
Cover.AnchorPoint = Vector2.new(0.5, 0.5)
Cover.Position = UDim2.fromScale(0.5, 0.5)
Cover.Size = UDim2.fromScale(3, 3)
Cover.BackgroundColor3 = Color3.new(0, 0, 0)
Cover.BorderSizePixel = 0
Cover.Active = true
Cover.Parent = Gui

local Label = Instance.new("TextLabel")
Label.Name = "Text"
Label.AnchorPoint = Vector2.new(0.5, 0.5)
Label.Position = UDim2.fromScale(0.5, 0.5)
Label.Size = UDim2.fromOffset(360, 56)
Label.BackgroundTransparency = 1
Label.FontFace = Textfont
Label.RichText = true
Label.Text = Loadingframes[1]
Label.TextColor3 = Color3.new(1, 1, 1)
Label.TextScaled = true
Label.ZIndex = 2
Label.Parent = Gui
local Labelscale = Instance.new("UIScale")
Labelscale.Parent = Label

Gui.Parent = Playergui
Replicatedfirst:RemoveDefaultLoadingScreen()

local Pulse = Tweenservice:Create(Labelscale, Pulseinfo, { Scale = Pulsescale })
Pulse:Play()
task.spawn(function()
	local Frame = 1
	while Gui.Enabled do
		task.wait(Dotinterval)
		Frame = Frame % #Loadingframes + 1
		Label.Text = Loadingframes[Frame]
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
task.delay(Maximumwait, function()
	Gui:SetAttribute("Ready", true)
end)
if Gui:GetAttribute("Ready") ~= true then
	Gui:GetAttributeChangedSignal("Ready"):Wait()
end

local Fadeinfo = TweenInfo.new(Fadeduration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Tweenservice:Create(Cover, Fadeinfo, { BackgroundTransparency = 1 }):Play()
local Fade = Tweenservice:Create(Label, Fadeinfo, { TextTransparency = 1 })
Fade:Play()
Fade.Completed:Wait()
Gui.Enabled = false
Pulse:Cancel()
