local Guiservice = game:GetService("GuiService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Userinputservice = game:GetService("UserInputService")
local Tweenservice = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)
local Cleaningconfig = require(Replicatedstorage.Shared.Config.Cleaning)
local Upgradesconfig = require(Replicatedstorage.Shared.Config.Upgrades)
local Facemapping = require(Replicatedstorage.Shared.Utils.FaceMapping)
local Stainlayout = require(Replicatedstorage.Shared.Utils.StainLayout)
local Uvtorch = require(script.Parent.RestorationController.UvTorch)

local Tutorialcontroller = {
	Name = "TutorialController",
	Priority = 25,
}

local Servicename = "TutorialService"
local Stepversion = 2
local Shadecolor = Color3.new(0, 0, 0)
local Shadetransparency = 0.25
local Ringcolor = Color3.new(1, 1, 1)
local Categorytolerance = 0.97
local Framenamebykind = { Ink = "Ink", Scratch = "ScratchesFrame" }
local Holepadding = 14
local Textwidth = 320
local Textheight = 96
local Largetextscale = 1.6
local Textsizemax = 30
local Largetextsizemax = 42
local Textgap = 18
local Textfont = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local Behindtext = {
	Touch = "It's on the other side!",
	Mouse = "It's on the other side!",
	Gamepad = "It's on the other side! Use the right stick!",
}
local Behindhandtext = "Tap the hand to turn it!"
local Handimage = "rbxassetid://116068912861302"
local Mouseimage = "rbxassetid://123373213717142"
local Gamepadimage = ""
local Turnimages = { Touch = Handimage, Mouse = Mouseimage, Gamepad = Gamepadimage }
local Toolnames = {
	ToothBrush = "brush",
	CottonTip = "cotton",
	UvTorch = "UV torch",
	Transform = "hand",
	Tweezers = "tweezers",
	Solvent = "solvent",
	Polish = "polish",
	HeatGun = "heat gun",
}
local Brushtools = { "ToothBrush", "CottonTip" }
local Handtaketext = "Tap the hand."
local Spintext = { Touch = "Tap here to spin it!", Mouse = "Tap here to spin it!", Gamepad = "Press X to spin it!" }
local Legacycheckpoints = { [1] = "Welcome", [3] = "Computer", [26] = "Computerintro", [30] = "Shelf", [34] = "Desk" }
local Turntravel = 2
local Spintravel = 0.8
local Handsize = 96
local Toolsize = 84
local Handswipe = 72
local Handheightscale = 0.45
local Scrubreach = 46
local Pourlift = 54
local Pullreach = 62

local Gestures = {
	Rotate = {
		Motion = function(Time: number): Vector2
			return Vector2.new(math.sin(Time * 1.6) * Handswipe, 0)
		end,
	},
	HeatGun = {
		Image = "rbxassetid://134645704439266",
		Motion = function(Time: number): Vector2
			return Vector2.new(math.sin(Time * 2.2) * Scrubreach, math.sin(Time * 4.4) * 8)
		end,
	},
	ToothBrush = {
		Image = "rbxassetid://75967295875128",
		Motion = function(Time: number): Vector2
			return Vector2.new(math.sin(Time * 7) * Scrubreach, math.sin(Time * 14) * 6)
		end,
	},
	CottonTip = {
		Image = "rbxassetid://112791892525390",
		Motion = function(Time: number): Vector2
			return Vector2.new(math.sin(Time * 7) * Scrubreach, math.sin(Time * 14) * 6)
		end,
	},
	Solvent = {
		Image = "rbxassetid://110004822063041",
		Motion = function(Time: number): Vector2
			return Vector2.new(0, -Pourlift * (0.5 + 0.5 * math.cos(Time * 3.2)))
		end,
	},
	Polish = {
		Image = "rbxassetid://123572804715301",
		Motion = function(Time: number): Vector2
			return Vector2.new(0, -Pourlift * (0.5 + 0.5 * math.cos(Time * 3.2)))
		end,
	},
	Tweezers = {
		Image = "rbxassetid://105078249168346",
		Motion = function(Time: number): Vector2
			return Vector2.new(0, -Pullreach * (Time * 0.8 % 1))
		end,
	},
}
local Steptweeninfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Pulsetweeninfo = TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local Staincorners = { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }
local Stainlayouts = setmetatable({} :: { [ImageLabel]: Stainlayout.Layout }, { __mode = "k" })

local function Makeshade(Parent: ScreenGui, Name: string): Frame
	local Shade = Instance.new("Frame")
	Shade.Name = Name
	Shade.BackgroundColor3 = Shadecolor
	Shade.BackgroundTransparency = Shadetransparency
	Shade.BorderSizePixel = 0
	Shade.Size = UDim2.fromOffset(0, 0)
	Shade.Parent = Parent
	return Shade
end

function Tutorialcontroller:Buildgui()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "TutorialUi"
	self.gui.DisplayOrder = 5000
	self.gui.IgnoreGuiInset = true
	self.gui.ClipToDeviceSafeArea = false
	self.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.gui.ResetOnSpawn = false
	self.gui.Enabled = false
	self.gui.Parent = Playergui

	self.shades = {
		Makeshade(self.gui, "ShadeTop"),
		Makeshade(self.gui, "ShadeBottom"),
		Makeshade(self.gui, "ShadeLeft"),
		Makeshade(self.gui, "ShadeRight"),
	}

	self.ring = Instance.new("Frame")
	self.ring.Name = "Ring"
	self.ring.BackgroundTransparency = 1
	self.ring.BorderSizePixel = 0
	self.ring.Parent = self.gui
	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 16)
	Corner.Parent = self.ring
	self.ringStroke = Instance.new("UIStroke")
	self.ringStroke.Color = Ringcolor
	self.ringStroke.Thickness = 4
	self.ringStroke.Transparency = 0.15
	self.ringStroke.Parent = self.ring

	self.hand = Instance.new("ImageLabel")
	self.hand.Name = "Hand"
	self.hand.AnchorPoint = Vector2.new(0.5, 0.5)
	self.hand.BackgroundTransparency = 1
	self.hand.ScaleType = Enum.ScaleType.Fit
	self.hand.Image = Handimage
	self.hand.Size = UDim2.fromOffset(Handsize, Handsize)
	self.hand.Visible = false
	self.hand.Parent = self.gui

	self.bubble = Instance.new("Frame")
	self.bubble.Name = "Bubble"
	self.bubble.AnchorPoint = Vector2.new(0.5, 0)
	self.bubble.BackgroundColor3 = Color3.new(0, 0, 0)
	self.bubble.BackgroundTransparency = 0.25
	self.bubble.BorderSizePixel = 0
	self.bubble.Size = UDim2.fromOffset(Textwidth, Textheight)
	self.bubble.Parent = self.gui
	local Bubblecorner = Instance.new("UICorner")
	Bubblecorner.CornerRadius = UDim.new(0, 14)
	Bubblecorner.Parent = self.bubble
	self.bubbleScale = Instance.new("UIScale")
	self.bubbleScale.Parent = self.bubble

	self.text = Instance.new("TextLabel")
	self.text.Name = "Text"
	self.text.BackgroundTransparency = 1
	self.text.Size = UDim2.fromScale(1, 1)
	self.text.FontFace = Textfont
	self.text.TextColor3 = Color3.new(1, 1, 1)
	self.text.TextScaled = true
	self.text.TextWrapped = true
	self.text.TextXAlignment = Enum.TextXAlignment.Center
	self.text.TextYAlignment = Enum.TextYAlignment.Center
	self.text.Text = ""
	self.text.Parent = self.bubble
	local Textpadding = Instance.new("UIPadding")
	Textpadding.PaddingLeft = UDim.new(0, 14)
	Textpadding.PaddingRight = UDim.new(0, 14)
	Textpadding.PaddingTop = UDim.new(0, 10)
	Textpadding.PaddingBottom = UDim.new(0, 10)
	Textpadding.Parent = self.text
	self.textSizeConstraint = Instance.new("UITextSizeConstraint")
	self.textSizeConstraint.MaxTextSize = Textsizemax
	self.textSizeConstraint.Parent = self.text
end

function Tutorialcontroller:Getguirect(Target: GuiObject): (Vector2, Vector2)
	return Target.AbsolutePosition + Guiservice:GetGuiInset(), Target.AbsoluteSize
end

local function Facelocalpoint(Size: Vector3, Facename: string, U: number, V: number): Vector3
	local Half = Size * 0.5
	if Facename == "Front" then
		return Vector3.new((0.5 - U) * Size.X, (0.5 - V) * Size.Y, -Half.Z)
	end
	if Facename == "Back" then
		return Vector3.new((U - 0.5) * Size.X, (0.5 - V) * Size.Y, Half.Z)
	end
	if Facename == "Left" then
		return Vector3.new(-Half.X, (0.5 - V) * Size.Y, (U - 0.5) * Size.Z)
	end
	if Facename == "Right" then
		return Vector3.new(Half.X, (0.5 - V) * Size.Y, (0.5 - U) * Size.Z)
	end
	if Facename == "Top" then
		return Vector3.new((V - 0.5) * Size.X, Half.Y, (0.5 - U) * Size.Z)
	end
	return Vector3.new((0.5 - V) * Size.X, -Half.Y, (0.5 - U) * Size.Z)
end

local function Facenormal(Facename: string): Vector3
	if Facename == "Front" then
		return Vector3.new(0, 0, -1)
	end
	if Facename == "Back" then
		return Vector3.new(0, 0, 1)
	end
	if Facename == "Left" then
		return Vector3.new(-1, 0, 0)
	end
	if Facename == "Right" then
		return Vector3.new(1, 0, 0)
	end
	if Facename == "Top" then
		return Vector3.new(0, 1, 0)
	end
	return Vector3.new(0, -1, 0)
end

function Tutorialcontroller:Projectrect(Points: { Vector3 }): (Vector2?, Vector2?)
	local Camera = Workspace.CurrentCamera
	local Minimum = Vector2.new(math.huge, math.huge)
	local Maximum = Vector2.new(-math.huge, -math.huge)
	local Visible = false
	for _, World in ipairs(Points) do
		local Point, Onscreen = Camera:WorldToViewportPoint(World)
		if Point.Z > 0 then
			Visible = Visible or Onscreen
			Minimum = Vector2.new(math.min(Minimum.X, Point.X), math.min(Minimum.Y, Point.Y))
			Maximum = Vector2.new(math.max(Maximum.X, Point.X), math.max(Maximum.Y, Point.Y))
		end
	end
	if not Visible then
		return nil, nil
	end
	return Minimum, Maximum - Minimum
end

function Tutorialcontroller:Getstainrect(Texture: ImageLabel): (Vector2?, Vector2?, boolean?)
	local Layout = Stainlayouts[Texture]
	if not Layout then
		Layout = Stainlayout.GetLayout(Texture)
		Stainlayouts[Texture] = Layout
	end
	local Part = Layout.Part
	local Points = {}
	for _, Corner in ipairs(Staincorners) do
		local Facepoint = Stainlayout.GetFacePoint(Layout, Corner)
		local Localpoint = Facemapping.GetDecalLocalPoint(Part.Size, Layout.Facename, Facepoint.X, Facepoint.Y)
		table.insert(Points, Part.CFrame:PointToWorldSpace(Localpoint))
	end
	local Center = (Points[1] + Points[4]) * 0.5
	local Worldnormal = Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Layout.Face))
	local Toviewer = Workspace.CurrentCamera.CFrame.Position - Center
	local Position, Size = self:Projectrect(Points)
	return Position, Size, Toviewer.Unit:Dot(Worldnormal) <= 0
end

function Tutorialcontroller:Getsurfacerect(Target: GuiObject): (Vector2?, Vector2?)
	local Surface = Target:FindFirstAncestorWhichIsA("SurfaceGui") :: SurfaceGui
	local Part = Surface.Adornee or Surface.Parent
	if not Part or not Part:IsA("BasePart") then
		return nil, nil
	end
	local Canvas = Surface.AbsoluteSize
	if Canvas.X <= 0 or Canvas.Y <= 0 then
		return nil, nil
	end
	return self:Getfacerect(Part, Surface.Face.Name, Target.AbsolutePosition / Canvas, Target.AbsoluteSize / Canvas)
end

local function Isstaintexture(Target: GuiObject): boolean
	local Frame = Target.Parent
	return Target:IsA("ImageLabel")
		and Target.Name == "Texture"
		and Frame ~= nil
		and (Frame.Name == Framenamebykind.Ink or Frame.Name == Framenamebykind.Scratch)
end

function Tutorialcontroller:Getdecalrect(Target: Decal): (Vector2?, Vector2?)
	return self:Getfacerect(Target.Parent :: BasePart, Target.Face.Name, Vector2.zero, Vector2.one)
end

function Tutorialcontroller:Getfacerect(Part: BasePart, Facename: string, Origin: Vector2, Extent: Vector2): (Vector2?, Vector2?)
	local Points = {}
	for X = 0, 1 do
		for Y = 0, 1 do
			local Localpoint = Facelocalpoint(Part.Size, Facename, Origin.X + Extent.X * X, Origin.Y + Extent.Y * Y)
			table.insert(Points, Part.CFrame:PointToWorldSpace(Localpoint))
		end
	end
	local Center = (Points[1] + Points[4]) * 0.5
	local Worldnormal = Part.CFrame:VectorToWorldSpace(Facenormal(Facename))
	local Toviewer = Workspace.CurrentCamera.CFrame.Position - Center
	local Position, Size = self:Projectrect(Points)
	return Position, Size, Toviewer.Unit:Dot(Worldnormal) <= 0
end

local function Thinaxis(Target: BasePart): Vector3
	local Size = Target.Size
	if Size.X <= Size.Y and Size.X <= Size.Z then
		return Target.CFrame.RightVector
	end
	if Size.Y <= Size.Z then
		return Target.CFrame.UpVector
	end
	return Target.CFrame.LookVector
end

local function Isbehindobject(Target: BasePart): boolean
	local Image = Target:FindFirstChildWhichIsA("Decal") or Target:FindFirstChildWhichIsA("SurfaceGui")
	local Visibleside = if Image then Target.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Image.Face)) else Thinaxis(Target)
	return Visibleside:Dot(Workspace.CurrentCamera.CFrame.Position - Target.Position) <= 0
end

function Tutorialcontroller:Getworldrect(Target: Model | BasePart): (Vector2?, Vector2?)
	local Center, Size
	if Target:IsA("Model") then
		Center, Size = Target:GetBoundingBox()
	else
		Center, Size = Target.CFrame, Target.Size
	end
	local Half = Size * 0.5
	local Points = {}
	for X = -1, 1, 2 do
		for Y = -1, 1, 2 do
			for Z = -1, 1, 2 do
				table.insert(Points, (Center * CFrame.new(Half.X * X, Half.Y * Y, Half.Z * Z)).Position)
			end
		end
	end
	return self:Projectrect(Points)
end

function Tutorialcontroller:Resolve(Target: Instance?): (Vector2?, Vector2?, boolean?)
	if typeof(Target) ~= "Instance" then
		return nil, nil
	end
	if Target:IsA("GuiObject") then
		if not Target.Visible then
			return nil, nil
		end
		if Target:FindFirstAncestorWhichIsA("SurfaceGui") then
			if Isstaintexture(Target) then
				return self:Getstainrect(Target :: ImageLabel)
			end
			return self:Getsurfacerect(Target)
		end
		return self:Getguirect(Target)
	end
	if Target:IsA("Decal") then
		return self:Getdecalrect(Target)
	end
	if Target:IsA("BasePart") then
		local Position, Size = self:Getworldrect(Target)
		return Position, Size, Isbehindobject(Target)
	end
	if Target:IsA("Model") then
		return self:Getworldrect(Target)
	end
	return nil, nil
end

function Tutorialcontroller:Isbehind(Target: Instance): boolean
	local _, _, Behind = self:Resolve(Target)
	return Behind == true
end

function Tutorialcontroller:Clearshades()
	for _, Shade in ipairs(self.shades) do
		Shade.Size = UDim2.fromOffset(0, 0)
	end
	self.ring.Size = UDim2.fromOffset(0, 0)
	self.ring.Visible = false
end

function Tutorialcontroller:Applyspotlight(Position: Vector2?, Size: Vector2?)
	local Viewport = self.gui.AbsoluteSize
	local Bleed = math.max(Viewport.X, Viewport.Y)
	if not Position or not Size then
		self.shades[1].Position = UDim2.fromOffset(-Bleed, -Bleed)
		self.shades[1].Size = UDim2.fromOffset(Viewport.X + Bleed * 2, Viewport.Y + Bleed * 2)
		for Index = 2, 4 do
			self.shades[Index].Size = UDim2.fromOffset(0, 0)
		end
		self.ring.Size = UDim2.fromOffset(0, 0)
		self.ring.Visible = false
		return
	end

	local Left = math.floor(math.max(Position.X - Holepadding, 0))
	local Top = math.floor(math.max(Position.Y - Holepadding, 0))
	local Right = math.ceil(math.min(Position.X + Size.X + Holepadding, Viewport.X))
	local Bottom = math.ceil(math.min(Position.Y + Size.Y + Holepadding, Viewport.Y))

	self.shades[1].Position = UDim2.fromOffset(-Bleed, -Bleed)
	self.shades[1].Size = UDim2.fromOffset(Viewport.X + Bleed * 2, Top + Bleed)
	self.shades[2].Position = UDim2.fromOffset(-Bleed, Bottom)
	self.shades[2].Size = UDim2.fromOffset(Viewport.X + Bleed * 2, Viewport.Y - Bottom + Bleed * 2)
	self.shades[3].Position = UDim2.fromOffset(-Bleed, Top)
	self.shades[3].Size = UDim2.fromOffset(Left + Bleed, Bottom - Top)
	self.shades[4].Position = UDim2.fromOffset(Right, Top)
	self.shades[4].Size = UDim2.fromOffset(Viewport.X - Right + Bleed * 2, Bottom - Top)

	self.ring.Position = UDim2.fromOffset(Left, Top)
	self.ring.Size = UDim2.fromOffset(Right - Left, Bottom - Top)
	self.ring.Visible = true
end

function Tutorialcontroller:Placebubble(Position: Vector2?, Size: Vector2?)
	local Viewport = self.gui.AbsoluteSize
	local Scale = if self.bubbleLarge then Largetextscale else 1
	local Width = math.min(Textwidth * Scale, Viewport.X - 24)
	local Height = math.min(Textheight * Scale, Viewport.Y - 24)
	self.bubble.Size = UDim2.fromOffset(Width, Height)

	local Centerx, Bubbley
	if Position and Size then
		Centerx = Position.X + Size.X * 0.5
		local Above = Position.Y - Holepadding - Textgap - Height
		if Above < 12 then
			Bubbley = Position.Y + Size.Y + Holepadding + Textgap
		else
			Bubbley = Above
		end
	else
		Centerx = Viewport.X * 0.5
		Bubbley = Viewport.Y * 0.62
	end
	Centerx = math.min(math.max(Centerx, Width * 0.5 + 12), math.max(Viewport.X - Width * 0.5 - 12, Width * 0.5 + 12))
	Bubbley = math.min(math.max(Bubbley, 12), math.max(Viewport.Y - Height - 12, 12))
	self.bubble.Position = UDim2.fromOffset(Centerx, Bubbley)
end

local function Inputkind(): string
	if Core:GetController("GamepadController"):IsActive() then
		return "Gamepad"
	end
	if Userinputservice:GetLastInputType() == Enum.UserInputType.Touch then
		return "Touch"
	end
	return "Mouse"
end

local function Textfor(Value: any): string
	if type(Value) == "function" then
		return Textfor(Value())
	end
	if type(Value) == "table" then
		return Value[Inputkind()]
	end
	return Value
end

function Tutorialcontroller:Sethand(Gesture: string?)
	local Kind = Inputkind()
	if Gesture == self.gesture and Kind == self.gestureKind then
		return
	end
	self.gesture = Gesture
	self.gestureKind = Kind
	self.gestureStart = os.clock()
	local Definition = if Gesture then Gestures[Gesture] else nil
	local Image = if Definition then Definition.Image or Turnimages[Kind] else ""
	self.hand.Image = Image
	self.hand.Size = if Definition and Definition.Image
		then UDim2.fromOffset(Toolsize, Toolsize)
		else UDim2.fromOffset(Handsize, Handsize)
	self.hand.Visible = Image ~= ""
end

function Tutorialcontroller:Placehand(Position: Vector2?, Size: Vector2?)
	if not self.gesture or not self.hand.Visible then
		return
	end
	local Viewport = self.gui.AbsoluteSize
	local Center = if Position and Size
		then Position + Size * 0.5
		else Vector2.new(Viewport.X * 0.5, Viewport.Y * Handheightscale)
	local Offset = Gestures[self.gesture].Motion(os.clock() - self.gestureStart)
	self.hand.Position = UDim2.fromOffset(math.floor(Center.X + Offset.X), math.floor(Center.Y + Offset.Y))
end

function Tutorialcontroller:Resumeindex(Saved: number, Version: number): number
	local Index = math.max(math.floor(Saved), 1)
	if Version < Stepversion then
		while Index > 1 and not Legacycheckpoints[Index] do
			Index -= 1
		end
		return self.stepindex[Legacycheckpoints[Index]]
	end
	Index = math.min(Index, #self.steps)
	while Index > 1 and not self.steps[Index].Checkpoint do
		Index -= 1
	end
	return Index
end

function Tutorialcontroller:Showstep(Index: number)
	while self.steps[Index] and self.steps[Index].Skip and self.steps[Index].Skip() do
		Index += 1
	end
	self.index = Index
	local Step = self.steps[Index]
	if not Step then
		self:Finish()
		return
	end
	Remotemanager:FireServer(Servicename, "SetStep", Index)
	self.bubbleLarge = Step.Large == true
	self.textSizeConstraint.MaxTextSize = if Step.Large then Largetextsizemax else Textsizemax
	self.text.Text = ""
	if Step.OnEnter then
		task.spawn(Step.OnEnter)
	end
	self.stepStart = os.clock()
	self.doneSince = nil
	self.tapped = false
end

function Tutorialcontroller:Finish()
	self.running = false
	self:Sethand(nil)
	self.gui.Enabled = false
	Core:GetController("ComputerController"):SetSellLocked(false)
	Core:GetController("RestorationController"):GetInterface():SetContinueLocked(false)
	Remotemanager:FireServer(Servicename, "Complete")
	Core:GetController("DailyRewardController"):OpenFromTutorial()
end

local function Restoration()
	return Core:GetController("RestorationController")
end

local function Inspection()
	return Core:GetController("InspectionCameraController")
end

local function Toolbutton(Name: string): GuiObject?
	return Restoration():GetInterface().Buttons[Name]
end

local function Firsttool(Tool: string | { string }): string
	return if type(Tool) == "table" then Tool[1] else Tool
end

local function Toolselected(Tool: string | { string }): boolean
	local Names = if type(Tool) == "table" then Tool else { Tool }
	for _, Name in ipairs(Names) do
		if (Toolbutton(Name) :: GuiObject):GetAttribute("Selected") == true then
			return true
		end
	end
	return false
end

local function Gettarget(Getter: (() -> Instance?)?): Instance?
	if not Getter then
		return nil
	end
	local Success, Target = pcall(Getter)
	return if Success and typeof(Target) == "Instance" then Target else nil
end

local function Categorydone(Kind: string): boolean
	local Object = Restoration():GetActiveObject()
	if not Object then
		return false
	end
	local Total = tonumber(Object:GetAttribute("Total_" .. Kind)) or 0
	local Cleaned = tonumber(Object:GetAttribute("Cleaned_" .. Kind)) or 0
	return Total <= 0 or Cleaned >= Total * Categorytolerance
end

local function Categorymissing(Kind: string): boolean
	local Object = Restoration():GetActiveObject()
	return Object ~= nil and (tonumber(Object:GetAttribute("Total_" .. Kind)) or 0) <= 0
end

local function Categoryframe(Kind: string): GuiObject?
	local Object = Restoration():GetActiveObject()
	if not Object then
		return nil
	end
	local Framename = Framenamebykind[Kind]
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if
			Descendant:IsA("GuiObject")
			and Descendant.Name == Framename
			and Descendant.Visible
			and Descendant:GetAttribute("Cleaned") ~= true
		then
			return Descendant
		end
	end
	return nil
end

local function Categorytexture(Kind: string): ImageLabel?
	local Frame = Categoryframe(Kind)
	if not Frame then
		return nil
	end
	local Texture = Frame:FindFirstChild("Texture")
	return if Texture and Texture:IsA("ImageLabel") then Texture else nil
end

local function Categorydecal(): Decal?
	local Object = Restoration():GetActiveObject()
	if not Object then
		return nil
	end
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if
			Descendant:IsA("Decal")
			and Cleaningconfig.DirtDecals[Descendant.Name]
			and Descendant:GetAttribute("Cleaned") ~= true
		then
			return Descendant
		end
	end
	return nil
end

local function Categoryspot(Kind: string): Instance?
	local Object = Restoration():GetActiveObject()
	if not Object then
		return nil
	end
	if Kind == "Dirt" then
		return Categorydecal() or Object
	end
	if Kind == "Sticker" then
		local Spots = Object:FindFirstChild("RestorationSpots")
		if Spots then
			for _, Spot in ipairs(Spots:GetDescendants()) do
				if Spot:IsA("BasePart") and Spot:GetAttribute("SpotKind") == "Sticker" then
					return Spot
				end
			end
		end
		return Object
	end
	return Categorytexture(Kind) or Object
end

local function Hasliquid(Kind: string, Attribute: string): boolean
	local Texture = Categorytexture(Kind)
	return Texture ~= nil and Texture:GetAttribute(Attribute) == true
end

local function Liquidfolder(Name: string): Instance?
	local Object = Restoration():GetActiveObject()
	if not Object then
		return nil
	end
	local Spots = Object:FindFirstChild("RestorationSpots")
	return if Spots then Spots:FindFirstChild(Name) else nil
end

local function Liquidcount(Name: string): number
	local Folder = Liquidfolder(Name)
	return if Folder then #Folder:GetChildren() else 0
end

local function Categoryclear(Kind: string): boolean
	return Categorymissing(Kind) or Categorydone(Kind)
end

local function Liquidsdry(): boolean
	return Liquidcount("SolventLiquid") + Liquidcount("PolishLiquid") == 0
end

local function Liquidspot(): Instance?
	for _, Name in ipairs({ "SolventLiquid", "PolishLiquid" }) do
		local Folder = Liquidfolder(Name)
		local Drop = if Folder then Folder:FindFirstChildWhichIsA("BasePart") else nil
		if Drop then
			return Drop
		end
	end
	return Restoration():GetActiveObject()
end

local function Facedecals(Face: number): { Decal }
	local Decals = {}
	local Object = Restoration():GetActiveObject()
	if not Object then
		return Decals
	end
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if
			Descendant:IsA("Decal")
			and Cleaningconfig.DirtDecals[Descendant.Name]
			and (Descendant:GetAttribute("TutorialFace") or 1) == Face
		then
			table.insert(Decals, Descendant)
		end
	end
	return Decals
end

local function Facedecal(Face: number): Decal?
	for _, Decal in ipairs(Facedecals(Face)) do
		if Decal:GetAttribute("Cleaned") ~= true then
			return Decal
		end
	end
	return nil
end

local function Frontdone(): boolean
	local Object = Restoration():GetActiveObject()
	if not Object then
		return false
	end
	if not Facedecal(1) then
		return true
	end
	local Share = 0
	for _, Decal in ipairs(Facedecals(1)) do
		Share += tonumber(Decal:GetAttribute("TutorialShare")) or 1
	end
	local Total = tonumber(Object:GetAttribute("Total_Dirt")) or 0
	local Cleaned = tonumber(Object:GetAttribute("Cleaned_Dirt")) or 0
	return Cleaned >= Total * Share * Categorytolerance
end

local function Backdone(): boolean
	return Facedecal(2) == nil or Categorydone("Dirt")
end

local function Dirtfinished(): boolean
	local Object = Restoration():GetActiveObject()
	return Object ~= nil
		and (tonumber(Object:GetAttribute("Cleaned_Dirt")) or 0) >= (tonumber(Object:GetAttribute("Total_Dirt")) or 0)
end

local function Backreference(): Instance?
	local Decal = Facedecals(2)[1]
	if Decal then
		return Decal
	end
	local Object = Restoration():GetActiveObject()
	local Sticker = Categoryspot("Sticker")
	if Sticker and Sticker ~= Object then
		return Sticker
	end
	return Categorytexture("Ink") or Categorytexture("Scratch")
end

local function Cameratravel(): number
	return Inspection():GetOrbitTravel() + Inspection():GetRotateTravel()
end

function Tutorialcontroller:Backvisible(): boolean
	local Reference = Backreference()
	return Reference ~= nil and not self:Isbehind(Reference)
end

function Tutorialcontroller:Turned(): boolean
	return self:Backvisible() or self.turnStart ~= nil and Cameratravel() - self.turnStart >= Turntravel
end

function Tutorialcontroller:Update()
	if not self.running then
		return
	end
	local Step = self.steps[self.index]
	if not Step then
		return
	end
	Restoration():GetInterface():SetContinueLocked(Step.AllowFinish ~= true)
	local Target = Gettarget(Step.Target)
	local Hastarget = Step.Target ~= nil
	local Position, Size, Behind = self:Resolve(Target)
	local Kind = Inputkind()
	local Text, Gesture
	local Fullshade = false
	if Behind and Kind == "Touch" and not Toolselected("Transform") then
		Hastarget = true
		Position, Size = self:Resolve(Toolbutton("Transform"))
		Text = Behindhandtext
	elseif Behind then
		Text, Gesture, Fullshade = Behindtext[Kind], "Rotate", true
	elseif Step.Tool and not Toolselected(Step.Tool) then
		local Tool = Firsttool(Step.Tool)
		Hastarget = true
		Position, Size = self:Resolve(Toolbutton(Tool))
		Text = Textfor(Step.TakeText or "Take the " .. Toolnames[Tool] .. ".")
	else
		Text = Textfor(Step.Text)
		Gesture = if type(Step.Gesture) == "function" then Step.Gesture() else Step.Gesture
	end
	if Text ~= self.text.Text then
		self.text.Text = Text
		self.bubbleScale.Scale = 0.86
		Tweenservice:Create(self.bubbleScale, Steptweeninfo, { Scale = 1 }):Play()
	end
	self:Sethand(Gesture)
	if Fullshade then
		self:Applyspotlight(nil, nil)
		self:Placebubble(nil, nil)
		self:Placehand(nil, nil)
	else
		if Hastarget and not Position then
			self:Clearshades()
		else
			self:Applyspotlight(Position, Size)
		end
		self:Placebubble(Position, Size)
		self:Placehand(Position, Size)
	end
	if Step.MaxSeconds and os.clock() - self.stepStart >= Step.MaxSeconds then
		self:Showstep(self.index + 1)
		return
	end
	if os.clock() - self.stepStart < (Step.MinimumSeconds or 0.35) then
		return
	end
	if Step.WaitForTap and not self.tapped then
		return
	end
	local Success, Done = pcall(Step.Done)
	if not Success or not Done then
		self.doneSince = nil
		return
	end
	if Step.HoldSeconds then
		self.doneSince = self.doneSince or os.clock()
		if os.clock() - self.doneSince < Step.HoldSeconds then
			return
		end
	end
	self:Showstep(self.index + 1)
end

local function Displayspacebought(): boolean
	local State = Core:GetController("ComputerController").upgradeState.DisplaySpace
	return State.Level > Upgradesconfig.DisplaySpace.DefaultLevel
end

local function Showdisplayspacecard()
	local Scrolling = Core:GetController("ComputerController").upgradesScrollingFrame
	local Card = Scrolling:WaitForChild("DisplaySpace") :: GuiObject
	local Top = Card.AbsolutePosition.Y - Scrolling.AbsolutePosition.Y + Scrolling.CanvasPosition.Y
	local Bottom = Top + Card.AbsoluteSize.Y - Scrolling.AbsoluteWindowSize.Y
	Scrolling.CanvasPosition = Vector2.new(0, math.min(math.max(Scrolling.CanvasPosition.Y, Bottom), Top))
end

function Tutorialcontroller:Buildsteps()
	self.steps = {
		{
			Id = "Welcome",
			Text = "Welcome! Tap the customer.",
			Target = function()
				return Core:GetController("CustomerController"):GetInteractionCustomer()
			end,
			Done = function()
				return Core:GetController("CustomerController"):IsVisible()
			end,
		},
		{
			Id = "Buy",
			Text = "Buy this old frame!",
			OnEnter = function()
				self.boughtBaseline = #Core:GetController("ComputerController").inventoryItems
			end,
			Target = function()
				return Core:GetController("CustomerController").buyButton
			end,
			Done = function()
				return #Core:GetController("ComputerController").inventoryItems > (self.boughtBaseline or 0)
			end,
		},
		{
			Id = "Computer",
			Text = "Open your computer.",
			Checkpoint = true,
			Target = function()
				return Core:GetController("ComputerController").computer
			end,
			Done = function()
				return Core:GetController("ComputerController"):IsOpen()
			end,
		},
		{
			Id = "Inventory",
			Text = "Open your inventory.",
			Target = function()
				return Core:GetController("ComputerController").inventoryNavButton
			end,
			Done = function()
				return Core:GetController("ComputerController").activePage == "Inventory"
			end,
		},
		{
			Id = "Card",
			Text = "Tap your frame.",
			Target = function()
				local Computer = Core:GetController("ComputerController")
				if not Computer:IsOpen() then return Computer.computer end
				if Computer.activePage ~= "Inventory" then return Computer.inventoryNavButton end
				local Card = Computer.inventoryCards[1]
				return if Card then Card.Button else Computer.inventoryScrollingFrame
			end,
			Done = function()
				return Core:GetController("ComputerController").inventoryOpenCard ~= nil
			end,
		},
		{
			Id = "Clean",
			Text = "Now clean it!",
			Target = function()
				local Computer = Core:GetController("ComputerController")
				if not Computer:IsOpen() then return Computer.computer end
				if Computer.activePage ~= "Inventory" then return Computer.inventoryNavButton end
				if Computer.inventoryInfoFrame.Visible then return Computer.inventoryInfoCloseButton end
				local Card = Computer.inventoryOpenCard or Computer.inventoryCards[1]
				if not Card then return Computer.inventoryScrollingFrame end
				return if Card.ButtonOpen.Visible then Card.ActionButton else Card.Button
			end,
			Done = function()
				return Restoration():GetActiveObject() ~= nil
			end,
		},
		{
			Id = "Front",
			Tool = Brushtools,
			Text = "Rub off the dirt!",
			Gesture = "ToothBrush",
			MaxSeconds = 120,
			Skip = Frontdone,
			Target = function()
				return Facedecal(1) or Categorydecal() or Restoration():GetActiveObject()
			end,
			Done = Frontdone,
		},
		{
			Id = "Light",
			Tool = "UvTorch",
			Text = "Tap to find hidden dirt!",
			HoldSeconds = 1.5,
			Skip = Uvtorch.IsLit,
			Target = function()
				return Facedecals(1)[1] or Restoration():GetActiveObject()
			end,
			Done = Uvtorch.IsLit,
		},
		{
			Id = "Turn",
			Tool = "Transform",
			TakeText = function()
				return if Facedecal(2) then "Dirt on the back! Tap the hand." else Handtaketext
			end,
			Text = { Touch = "Swipe to turn it around!", Mouse = "Hold right click and drag!", Gamepad = "Use the right stick!" },
			Gesture = "Rotate",
			MinimumSeconds = 1,
			OnEnter = function()
				self.turnStart = Cameratravel()
			end,
			Skip = function()
				return self:Backvisible()
			end,
			Done = function()
				return self:Turned()
			end,
		},
		{
			Id = "Back",
			Tool = Brushtools,
			Text = "Rub off the dirt!",
			Gesture = "ToothBrush",
			MaxSeconds = 120,
			Skip = Backdone,
			Target = function()
				return Facedecal(2) or Categorydecal()
			end,
			Done = Backdone,
		},
		{
			Id = "Sticker",
			Tool = "Tweezers",
			Text = "Pull the sticker off!",
			Gesture = "Tweezers",
			MaxSeconds = 90,
			Skip = function()
				return Categoryclear("Sticker")
			end,
			Target = function()
				return Categoryspot("Sticker")
			end,
			Done = function()
				return Categorydone("Sticker")
			end,
		},
		{
			Id = "Pour",
			Tool = "Solvent",
			Text = "Pour it on the ink!",
			Gesture = "Solvent",
			HoldSeconds = 2.5,
			MaxSeconds = 90,
			Skip = function()
				return Categoryclear("Ink") or Hasliquid("Ink", "HasSolvent")
			end,
			Target = function()
				return Categoryspot("Ink")
			end,
			Done = function()
				return Hasliquid("Ink", "HasSolvent") or Categorydone("Ink")
			end,
		},
		{
			Id = "Ink",
			Tool = "CottonTip",
			Text = "Rub the ink away!",
			Gesture = "CottonTip",
			MaxSeconds = 90,
			Skip = function()
				return Categoryclear("Ink")
			end,
			Target = function()
				return Categoryspot("Ink")
			end,
			Done = function()
				return Categorydone("Ink")
			end,
		},
		{
			Id = "Polish",
			Tool = "Polish",
			Text = "Rub it on the scratch!",
			Gesture = "Polish",
			HoldSeconds = 2.5,
			MaxSeconds = 90,
			Skip = function()
				return Categoryclear("Scratch") or Hasliquid("Scratch", "HasPolish")
			end,
			Target = function()
				return Categoryspot("Scratch")
			end,
			Done = function()
				return Hasliquid("Scratch", "HasPolish") or Categorydone("Scratch")
			end,
		},
		{
			Id = "Scratch",
			Tool = "CottonTip",
			Text = "Rub the scratch away!",
			Gesture = "CottonTip",
			MaxSeconds = 90,
			Skip = function()
				return Categoryclear("Scratch")
			end,
			Target = function()
				return Categoryspot("Scratch")
			end,
			Done = function()
				return Categorydone("Scratch")
			end,
		},
		{
			Id = "Dry",
			Tool = "HeatGun",
			Text = "Dry it all!",
			Gesture = "HeatGun",
			HoldSeconds = 1.5,
			Skip = Liquidsdry,
			Target = Liquidspot,
			Done = Liquidsdry,
		},
		{
			Id = "Last",
			Tool = Brushtools,
			Text = "Rub off the last dirt!",
			Gesture = "ToothBrush",
			MaxSeconds = 45,
			Skip = Dirtfinished,
			Target = function()
				return Categorydecal() or Restoration():GetActiveObject()
			end,
			Done = Dirtfinished,
		},
		{
			Id = "Flip",
			Text = { Touch = "Tap to flip it!", Mouse = "Tap to flip it!", Gamepad = "Press Y to flip it!" },
			Skip = function()
				return Inspection():GetFlipCount() >= 2 or Inspection():IsShowingBack()
			end,
			Target = function()
				return Restoration():GetInterface().ReturnButton
			end,
			Done = function()
				return Inspection():IsShowingBack()
			end,
		},
		{
			Id = "Unflip",
			Text = { Touch = "Flip it back!", Mouse = "Flip it back!", Gamepad = "Press Y again!" },
			Skip = function()
				return not Inspection():IsShowingBack() and Inspection():GetFlipCount() >= 2
			end,
			Target = function()
				return Restoration():GetInterface().ReturnButton
			end,
			Done = function()
				return not Inspection():IsShowingBack()
			end,
		},
		{
			Id = "Spin",
			Tool = "Transform",
			TakeText = Handtaketext,
			Text = Spintext,
			Skip = function()
				return Inspection():GetRotateTravel() >= Spintravel or Inspection():GetTransformMode() == "Rotate"
			end,
			Target = function()
				return Restoration():GetInterface().TurnButton
			end,
			Done = function()
				return Inspection():GetTransformMode() == "Rotate"
			end,
		},
		{
			Id = "Spindrag",
			Tool = "Transform",
			TakeText = Handtaketext,
			Text = function()
				if Inspection():GetTransformMode() ~= "Rotate" then
					return Spintext
				end
				return { Touch = "Swipe to spin it!", Mouse = "Hold right click and drag!", Gamepad = "Use the right stick!" }
			end,
			Gesture = function()
				return if Inspection():GetTransformMode() == "Rotate" then "Rotate" else nil
			end,
			MinimumSeconds = 1,
			Skip = function()
				return Inspection():GetRotateTravel() >= Spintravel
			end,
			Target = function()
				return if Inspection():GetTransformMode() == "Rotate" then nil else Restoration():GetInterface().TurnButton
			end,
			Done = function()
				return Inspection():GetRotateTravel() >= Spintravel
			end,
		},
		{
			Id = "Lock",
			Tool = "Transform",
			TakeText = Handtaketext,
			Text = { Touch = "Tap the lock to stop.", Mouse = "Tap the lock to stop.", Gamepad = "Press X to stop." },
			Skip = function()
				return Inspection():GetTransformMode() == "Orbit"
			end,
			Target = function()
				return Restoration():GetInterface().LockButton
			end,
			Done = function()
				return Inspection():GetTransformMode() == "Orbit"
			end,
		},
		{
			Id = "Finish",
			Text = "All clean! Tap to finish.",
			AllowFinish = true,
			Target = function()
				return Restoration():GetInterface().ContinueButton
			end,
			Done = function()
				return Core:GetController("CompletionController"):IsVisible()
			end,
		},
		{
			Id = "Nice",
			Text = "Nice work! Keep going.",
			Target = function()
				return Core:GetController("CompletionController").nextButton
			end,
			Done = function()
				return not Core:GetController("CompletionController"):IsVisible()
					and not Restoration():IsEditingObject()
			end,
		},
		{
			Id = "Computerintro",
			Text = "This is your computer. Sell items and buy upgrades here!",
			Checkpoint = true,
			Target = function()
				return Core:GetController("ComputerController").computer
			end,
			Done = function()
				return Core:GetController("ComputerController"):IsOpen()
			end,
		},
		{
			Id = "Upgrades",
			Text = "Open your upgrades.",
			Skip = Displayspacebought,
			Target = function()
				local Computer = Core:GetController("ComputerController")
				if not Computer:IsOpen() then return Computer.computer end
				return Computer.upgradesButton
			end,
			Done = function()
				return Core:GetController("ComputerController").activePage == "Upgrades"
			end,
		},
		{
			Id = "Unlock",
			Text = "Unlock your first shelf spot. It's free!",
			Skip = Displayspacebought,
			Target = function()
				local Computer = Core:GetController("ComputerController")
				if not Computer:IsOpen() then return Computer.computer end
				if Computer.activePage ~= "Upgrades" then return Computer.upgradesButton end
				Showdisplayspacecard()
				return Computer.upgradeCards.DisplaySpace.CashButton
			end,
			Done = Displayspacebought,
		},
		{
			Id = "Arrow",
			Text = "Tap the arrow to go back.",
			Target = function()
				return Core:GetController("ComputerController").closeButton
			end,
			Done = function()
				return not Core:GetController("ComputerController"):IsOpen()
			end,
		},
		{
			Id = "Shelf",
			Text = "Open your shelf.",
			Checkpoint = true,
			Target = function()
				return Core:GetController("ExpositionController").reputationButtonL
			end,
			Done = function()
				return Core:GetController("ExpositionController"):IsOpen()
			end,
		},
		{
			Id = "Spot",
			Text = "Pick an empty spot.",
			Target = function()
				return Core:GetController("ExpositionController").slotButtons[1].Button
			end,
			Done = function()
				return Core:GetController("ExpositionController"):IsSelectionOpen()
			end,
		},
		{
			Id = "Put",
			Text = "Put your frame on the shelf!",
			Target = function()
				local Exposition = Core:GetController("ExpositionController")
				if Exposition.infoFrame.Visible then return Exposition.infoCloseButton end
				local Card = Exposition.selectCards[1]
				if not Card then return nil end
				return if Card.Button.Visible then Card.Button else Card.EquipButton
			end,
			Done = function()
				return not Core:GetController("ExpositionController"):IsSelectionOpen()
			end,
		},
		{
			Id = "Reputation",
			Text = "Items on the shelf give you reputation.\nMore reputation, better items!\nTap to continue.",
			Large = true,
			MinimumSeconds = 1.5,
			WaitForTap = true,
			Done = function()
				return true
			end,
		},
		{
			Id = "Desk",
			Text = "Go back to your desk.",
			Checkpoint = true,
			Target = function()
				return Core:GetController("ExpositionController").reputationButtonR
			end,
			Done = function()
				return not Core:GetController("ExpositionController"):IsOpen()
			end,
		},
		{
			Id = "Ready",
			Text = "You are ready. Have fun!",
			MinimumSeconds = 3,
			Done = function()
				return true
			end,
		},
	}
	self.stepindex = {}
	for Index, Step in ipairs(self.steps) do
		self.stepindex[Step.Id] = Index
	end
end

function Tutorialcontroller:Init()
	self:Buildgui()
	self.running = false
	self.index = 0
	self.stepStart = 0
end

function Tutorialcontroller:Start()
	self:Buildsteps()
	Tweenservice:Create(self.ringStroke, Pulsetweeninfo, { Thickness = 9, Transparency = 0.55 }):Play()
	Userinputservice.InputBegan:Connect(function(Input)
		if
			Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.Touch
			or Input.KeyCode == Enum.KeyCode.ButtonA
			or Input.KeyCode == Enum.KeyCode.ButtonR2
		then
			self.tapped = true
		end
	end)
	Runservice.RenderStepped:Connect(function()
		self:Update()
	end)
	task.spawn(function()
		local State = Remotemanager:InvokeServer(Servicename, "GetState")
		if State and State.Completed == true then
			return
		end
		local Index = self:Resumeindex(tonumber(State and State.Step) or 1, tonumber(State and State.Version) or Stepversion)
		self.running = true
		Core:GetController("ComputerController"):SetSellLocked(true)
		self.gui.Enabled = true
		self:Showstep(Index)
	end)
end

return Tutorialcontroller
