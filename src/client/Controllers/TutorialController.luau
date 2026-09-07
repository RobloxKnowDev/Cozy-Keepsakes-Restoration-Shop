local Guiservice = game:GetService("GuiService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Userinputservice = game:GetService("UserInputService")
local Tweenservice = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Tutorialcontroller = {
	Name = "TutorialController",
	Priority = 25,
}

local Servicename = "TutorialService"
local Shadecolor = Color3.new(0, 0, 0)
local Shadetransparency = 0.25
local Ringcolor = Color3.new(1, 1, 1)
local Categorytolerance = 0.97
local Framenamebykind = { Dirt = "DirtFrame", Ink = "Ink", Scratch = "ScratchesFrame" }
local Holepadding = 14
local Textwidth = 320
local Textheight = 96
local Textgap = 18
local Behindtext = "It's on the other side!"
local Handimage = "rbxassetid://116068912861302"
local Mouseimage = "rbxassetid://123373213717142"
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
	self.text.FontFace = Font.new("rbxasset://fonts/families/Inter.json", Enum.FontWeight.SemiBold)
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
	local Textsize = Instance.new("UITextSizeConstraint")
	Textsize.MaxTextSize = 30
	Textsize.Parent = self.text
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

function Tutorialcontroller:Getsurfacerect(Target: GuiObject): (Vector2?, Vector2?)
	local Surface = Target:FindFirstAncestorWhichIsA("SurfaceGui")
	if not Surface then
		return nil, nil
	end
	local Part = Surface.Adornee or Surface.Parent
	if not Part or not Part:IsA("BasePart") then
		return nil, nil
	end
	local Canvas = Surface.AbsoluteSize
	if Canvas.X <= 0 or Canvas.Y <= 0 then
		return nil, nil
	end
	local Origin = Target.AbsolutePosition / Canvas
	local Extent = Target.AbsoluteSize / Canvas
	local Facename = Surface.Face.Name
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
	local Object = Core:GetController("RestorationController"):GetActiveObject()
	if not Object then
		return false
	end
	local Center = if Object:IsA("Model") then (Object:GetBoundingBox()).Position else Object.Position
	local Visibleside = Thinaxis(Target)
	if Visibleside:Dot(Target.Position - Center) > 0 then
		Visibleside = -Visibleside
	end
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

function Tutorialcontroller:Resolvetarget(): (Vector2?, Vector2?, boolean?)
	local Step = self.steps[self.index]
	if not Step or not Step.Target then
		return nil, nil
	end
	local Success, Target = pcall(Step.Target)
	if not Success or typeof(Target) ~= "Instance" then
		return nil, nil
	end
	if Target:IsA("GuiObject") then
		if not Target.Visible then
			return nil, nil
		end
		if Target:FindFirstAncestorWhichIsA("SurfaceGui") then
			return self:Getsurfacerect(Target)
		end
		return self:Getguirect(Target)
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

function Tutorialcontroller:Clearshades()
	for _, Shade in ipairs(self.shades) do
		Shade.Size = UDim2.fromOffset(0, 0)
	end
	self.ring.Size = UDim2.fromOffset(0, 0)
	self.ring.Visible = false
end

function Tutorialcontroller:Applyspotlight(Position: Vector2?, Size: Vector2?)
	local Viewport = self.gui.AbsoluteSize
	local Bleed = 4
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
	local Width = math.min(Textwidth, Viewport.X - 24)
	local Height = math.min(Textheight, Viewport.Y - 24)
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

function Tutorialcontroller:Sethand(Gesture: string?)
	self.gesture = Gesture
	self.gestureStart = os.clock()
	self.hand.Visible = Gesture ~= nil
	if not Gesture then
		return
	end
	local Definition = Gestures[Gesture]
	if Definition.Image then
		self.hand.Image = Definition.Image
		self.hand.Size = UDim2.fromOffset(Toolsize, Toolsize)
		return
	end
	local Istouch = Userinputservice.TouchEnabled and not Userinputservice.MouseEnabled
	self.hand.Image = if Istouch then Handimage else Mouseimage
	self.hand.Size = UDim2.fromOffset(Handsize, Handsize)
end

function Tutorialcontroller:Placehand(Position: Vector2?, Size: Vector2?)
	if not self.gesture then
		return
	end
	local Viewport = self.gui.AbsoluteSize
	local Center = if Position and Size
		then Position + Size * 0.5
		else Vector2.new(Viewport.X * 0.5, Viewport.Y * Handheightscale)
	local Offset = Gestures[self.gesture].Motion(os.clock() - self.gestureStart)
	self.hand.Position = UDim2.fromOffset(math.floor(Center.X + Offset.X), math.floor(Center.Y + Offset.Y))
end

function Tutorialcontroller:Resumeindex(Saved: number): number
	local Index = math.min(math.max(math.floor(Saved), 1), #self.steps)
	while Index > 1 and not self.steps[Index].Checkpoint do
		Index -= 1
	end
	return Index
end

function Tutorialcontroller:Showstep(Index: number)
	self.index = Index
	local Step = self.steps[Index]
	if not Step then
		self:Finish()
		return
	end
	Remotemanager:FireServer(Servicename, "SetStep", Index)
	self.behind = false
	self:Sethand(Step.Gesture)
	self.text.Text = Step.Text
	self.bubbleScale.Scale = 0.86
	Tweenservice:Create(self.bubbleScale, Steptweeninfo, { Scale = 1 }):Play()
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
	Core:GetController("RestorationController"):GetInterface():SetContinueLocked(false)
	Remotemanager:FireServer(Servicename, "Complete")
	Core:GetController("DailyRewardController"):OpenFromTutorial()
end

function Tutorialcontroller:Update()
	if not self.running then
		return
	end
	local Step = self.steps[self.index]
	if not Step then
		return
	end
	Core:GetController("RestorationController"):GetInterface():SetContinueLocked(Step.AllowFinish ~= true)
	local Position, Size, Behind = self:Resolvetarget()
	if Behind ~= self.behind then
		self.behind = Behind
		self.text.Text = if Behind then Behindtext else Step.Text
		self:Sethand(if Behind then "Rotate" else Step.Gesture)
	end
	if Behind then
		self:Applyspotlight(nil, nil)
		self:Placebubble(nil, nil)
		self:Placehand(nil, nil)
	else
		if Step.Target and not Position then
			self:Clearshades()
		else
			self:Applyspotlight(Position, Size)
		end
		self:Placebubble(Position, Size)
		self:Placehand(Position, Size)
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

local function Restoration()
	return Core:GetController("RestorationController")
end

local function Toolbutton(Name: string): GuiObject?
	return Restoration():GetInterface().Buttons[Name]
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

local function Categoryspot(Kind: string): Instance?
	local Object = Restoration():GetActiveObject()
	if not Object then
		return nil
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

function Tutorialcontroller:Buildsteps()
	self.steps = {
		{
			Text = "Welcome! Tap the customer.",
			Target = function()
				return Core:GetController("CustomerController"):GetInteractionCustomer()
			end,
			Done = function()
				return Core:GetController("CustomerController"):IsVisible()
			end,
		},
		{
			Text = "Buy this old frame!",
			OnEnter = function()
				self.boughtBaseline = #Core:GetController("ComputerController").inventoryItems
			end,
			Target = function()
				return Core:GetController("CustomerController").acceptButton
			end,
			Done = function()
				return #Core:GetController("ComputerController").inventoryItems > (self.boughtBaseline or 0)
			end,
		},
		{
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
			Text = "Open your inventory.",
			Target = function()
				return Core:GetController("ComputerController").inventoryNavButton
			end,
			Done = function()
				return Core:GetController("ComputerController").activePage == "Inventory"
			end,
		},
		{
			Text = "Tap your frame.",
			Target = function()
				return Core:GetController("ComputerController").inventoryScrollingFrame
			end,
			Done = function()
				return Core:GetController("ComputerController").selectedInventoryItemId ~= nil
			end,
		},
		{
			Text = "Now clean it!",
			Target = function()
				return Core:GetController("ComputerController").inventoryCleanButton
			end,
			Done = function()
				return Restoration():GetActiveObject() ~= nil
			end,
		},
		{
			Text = "Turn it around!",
			Gesture = "Rotate",
			MinimumSeconds = 1,
			Done = function()
				return Core:GetController("InspectionCameraController"):GetOrbitTravel() >= 1.2
			end,
		},
		{
			Text = "Take the brush.",
			Target = function()
				return Toolbutton("ToothBrush")
			end,
			Done = function()
				return Toolbutton("ToothBrush"):GetAttribute("Selected") == true
			end,
		},
		{
			Text = "Hold and rub off the dirt!",
			Gesture = "ToothBrush",
			Target = function()
				return Categoryspot("Dirt")
			end,
			Done = function()
				return Categorydone("Dirt")
			end,
		},
		{
			Text = "Take the tweezers.",
			Target = function()
				return Toolbutton("Tweezers")
			end,
			Done = function()
				return Toolbutton("Tweezers"):GetAttribute("Selected") == true
			end,
		},
		{
			Text = "Pull the sticker off!",
			Gesture = "Tweezers",
			Target = function()
				return Categoryspot("Sticker")
			end,
			Done = function()
				return Categorydone("Sticker")
			end,
		},
		{
			Text = "Take the solvent.",
			Target = function()
				return Toolbutton("Solvent")
			end,
			Done = function()
				return Toolbutton("Solvent"):GetAttribute("Selected") == true
			end,
		},
		{
			Text = "Pour it on the ink!",
			Gesture = "Solvent",
			HoldSeconds = 2.5,
			Target = function()
				return Categoryspot("Ink")
			end,
			Done = function()
				return Hasliquid("Ink", "HasSolvent") or Categorydone("Ink")
			end,
		},
		{
			Text = "Take the cotton.",
			Target = function()
				return Toolbutton("CottonTip")
			end,
			Done = function()
				return Toolbutton("CottonTip"):GetAttribute("Selected") == true
			end,
		},
		{
			Text = "Rub the ink away!",
			Gesture = "CottonTip",
			Target = function()
				return Categoryspot("Ink")
			end,
			Done = function()
				return Categorydone("Ink")
			end,
		},
		{
			Text = "Take the polish.",
			Target = function()
				return Toolbutton("Polish")
			end,
			Done = function()
				return Toolbutton("Polish"):GetAttribute("Selected") == true
			end,
		},
		{
			Text = "Rub it on the scratches!",
			Gesture = "Polish",
			HoldSeconds = 2.5,
			Target = function()
				return Categoryspot("Scratch")
			end,
			Done = function()
				return Hasliquid("Scratch", "HasPolish") or Categorydone("Scratch")
			end,
		},
		{
			Text = "Take the cotton again.",
			Target = function()
				return Toolbutton("CottonTip")
			end,
			Done = function()
				return Toolbutton("CottonTip"):GetAttribute("Selected") == true
			end,
		},
		{
			Text = "Rub the scratches away!",
			Gesture = "CottonTip",
			Target = function()
				return Categoryspot("Scratch")
			end,
			Done = function()
				return Categorydone("Scratch")
			end,
		},
		{
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
			Text = "Open your shelf.",
			Checkpoint = true,
			Target = function()
				return Core:GetController("ExpositionController").reputationButtonR
			end,
			Done = function()
				return Core:GetController("ExpositionController"):IsOpen()
			end,
		},
		{
			Text = "Pick an empty spot.",
			Target = function()
				return Core:GetController("ExpositionController").slotButtons[1].Button
			end,
			Done = function()
				return Core:GetController("ExpositionController"):IsSelectionOpen()
			end,
		},
		{
			Text = "Put your frame on the shelf!",
			Target = function()
				local Cards = Core:GetController("ExpositionController").selectCards
				return if Cards[1] then Cards[1].SelectButton else nil
			end,
			Done = function()
				return not Core:GetController("ExpositionController"):IsSelectionOpen()
			end,
		},
		{
			Text = "Items on the shelf give you reputation. More reputation, better items!\nTap to continue.",
			MinimumSeconds = 1.5,
			WaitForTap = true,
			Done = function()
				return true
			end,
		},
		{
			Text = "Go back to your desk.",
			Checkpoint = true,
			Target = function()
				return Core:GetController("ExpositionController").reputationButtonL
			end,
			Done = function()
				return not Core:GetController("ExpositionController"):IsOpen()
			end,
		},
		{
			Text = "This is your computer. Sell items and buy upgrades here!",
			Target = function()
				return Core:GetController("ComputerController").computer
			end,
			Done = function()
				return Core:GetController("ComputerController"):IsOpen()
			end,
		},
		{
			Text = "Tap the arrow to go back.",
			Target = function()
				return Core:GetController("ComputerController").exitButton
			end,
			Done = function()
				return not Core:GetController("ComputerController"):IsOpen()
			end,
		},
		{
			Text = "You are ready. Have fun!",
			MinimumSeconds = 3,
			Done = function()
				return true
			end,
		},
	}
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
		local Index = self:Resumeindex(tonumber(State and State.Step) or 1)
		self.running = true
		self.gui.Enabled = true
		self:Showstep(Index)
	end)
end

return Tutorialcontroller
