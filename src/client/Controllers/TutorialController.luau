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
local Customerconfig = require(Replicatedstorage.Shared.Config.Customer)
local Rarityconfig = require(Replicatedstorage.Shared.Config.Rarity)
local Facemapping = require(Replicatedstorage.Shared.Utils.FaceMapping)
local Stainlayout = require(Replicatedstorage.Shared.Utils.StainLayout)
local Translation = require(Replicatedstorage.Shared.Utils.Translation)

local Tutorialcontroller = {
	Name = "TutorialController",
	Priority = 25,
}

local Servicename = "TutorialService"
local Stepversion = 3
local Categorytolerance = 0.97
local Fronttolerance = 0.85
local Framenamebykind = { Ink = "Ink", Scratch = "ScratchesFrame" }
local Arrowgradient = Rarityconfig.Legendary.Gradient
local Arrowfillcolor = Color3.new(1, 1, 1)
local Arrowoutlinecolor = Color3.new(0, 0, 0)
local Arrowoutline = 4
local Arrowwidth = 72
local Arrowheight = 84
local Arrowpieces = {
	{ Center = Vector2.new(36, 34), Size = Vector2.new(18, 54), Rotation = 0 },
	{ Center = Vector2.new(26.8, 60), Size = Vector2.new(44, 18), Rotation = 45 },
	{ Center = Vector2.new(45.2, 60), Size = Vector2.new(44, 18), Rotation = -45 },
}
local Arrowgap = 6
local Arrowbob = 12
local Arrowspeed = 6
local Arrowreach = Arrowgap + Arrowbob + Arrowheight
local Arrowclearance = 6
local Compactheight = 540
local Compactscale = 0.75
local Edgemargin = 12
local Textwidth = 320
local Textheight = 96
local Largetextscale = 1.6
local Textsizemax = 30
local Largetextsizemax = 42
local Textgap = 18
local Textfont = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local Behindtext = {
	Touch = "It's on the other side! Swipe to turn it!",
	Mouse = "It's on the other side! Hold right click and drag!",
	Gamepad = "It's on the other side! Use the right stick!",
}
local Tilttext = {
	Touch = "It's on top! Swipe down to see it!",
	Mouse = "It's on top! Hold right click and drag down!",
	Gamepad = "It's on top! Push the right stick down!",
}
local Fliptext = { Touch = "Tap to flip it!", Mouse = "Tap to flip it!", Gamepad = "Press Y to flip it!" }
local Undertext = {
	Touch = "Dirt underneath! Tap to flip it!",
	Mouse = "Dirt underneath! Click to flip it!",
	Gamepad = "Dirt underneath! Press Y to flip it!",
}
local Lessoncheck = 0.5
local Finishtexts = { Clean = "All clean! Tap to finish.", Partial = "Tap to finish." }
local Downfacing = -0.8
local Upfacing = 0.8
local Raisedelay = 8
local Raisepitch = math.rad(-65)
local Handimage = "rbxassetid://116068912861302"
local Mouseimage = "rbxassetid://123373213717142"
local Gamepadimage = "rbxassetid://133575975410772"
local Turnimages = { Touch = Handimage, Mouse = Mouseimage, Gamepad = Gamepadimage }
local Tiltimages = {
	Touch = "rbxassetid://113613120259082",
	Mouse = "rbxassetid://130914886140948",
	Gamepad = "rbxassetid://120810455415199",
}
local Toolnames = {
	ToothBrush = "brush",
	CottonTip = "cotton",
	Transform = "hand",
	Tweezers = "tweezers",
	Solvent = "solvent",
	Polish = "polish",
	HeatGun = "heat gun",
}
local Brushtools = { "ToothBrush", "CottonTip" }
local Legacycheckpoints = { [1] = "Welcome", [3] = "Computer" }
local Handsize = 96
local Toolsize = 84
local Keysize = 40
local Keygap = 8
local Handswipe = 72
local Handheightscale = 0.45
local Scrubreach = 46
local Pourlift = 54
local Peelstart = Vector2.new(70, 50)
local Peelapproach = 0.5
local Peelgrab = 0.3
local Peelpull = 1
local Peelhold = 0.4
local Peelreturn = 0.6
local Peelcycle = Peelapproach + Peelgrab + Peelpull + Peelhold + Peelreturn
local Tiltstroke = 1.1
local Tiltpause = 0.5

local function Peelease(Alpha: number): number
	return Tweenservice:GetValue(Alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
end

local function Peeldirection(Center: Vector2, Viewport: Vector2, Peel: number): Vector2
	if Center.Y >= Peel + Toolsize * 0.5 + Edgemargin then
		return Vector2.new(0, -1)
	end
	local Best, Room = Vector2.new(0, 1), Viewport.Y - Center.Y
	if Viewport.X - Center.X > Room then
		Best, Room = Vector2.new(1, 0), Viewport.X - Center.X
	end
	if Center.X > Room then
		Best = Vector2.new(-1, 0)
	end
	return Best
end

local Gestures = {
	Rotate = {
		Images = Turnimages,
		Motion = function(Time: number): Vector2
			return Vector2.new(math.sin(Time * 1.6) * Handswipe, 0)
		end,
	},
	Tilt = {
		Images = Tiltimages,
		Motion = function(Time: number): Vector2
			local Alpha = math.min(Time % (Tiltstroke + Tiltpause) / Tiltstroke, 1)
			return Vector2.new(0, (Peelease(Alpha) - 0.5) * Handswipe * 2)
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
		Motion = function(Time: number, Center: Vector2, Viewport: Vector2): Vector2
			local Peel = Core:GetController("StickerController"):GetPeelDistance()
			local Direction = Peeldirection(Center, Viewport, Peel)
			local Start = Vector2.new(-Direction.Y, Direction.X) * Peelstart.X - Direction * Peelstart.Y
			local Pulled = Direction * Peel
			local Phase = Time % Peelcycle
			if Phase < Peelapproach then
				return Start:Lerp(Vector2.zero, Peelease(Phase / Peelapproach))
			end
			Phase -= Peelapproach + Peelgrab
			if Phase < 0 then
				return Vector2.zero
			end
			if Phase < Peelpull then
				return Pulled * Peelease(Phase / Peelpull)
			end
			Phase -= Peelpull + Peelhold
			if Phase < 0 then
				return Pulled
			end
			return Pulled:Lerp(Start, Peelease(Phase / Peelreturn))
		end,
	},
}
local Steptweeninfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Surfaceoffset = 0.01
local Surfacerefresh = 0.5
local function Grid(Low: number, High: number, Count: number): { Vector2 }
	local Points = {}
	for Row = 0, Count - 1 do
		for Column = 0, Count - 1 do
			table.insert(Points, Vector2.new(Low + (High - Low) * Column / (Count - 1), Low + (High - Low) * Row / (Count - 1)))
		end
	end
	return Points
end
local Staingrid = Grid(0, 1, 7)
local Decalgrid = Grid(0.02, 0.98, 7)
local Stainlayouts = setmetatable({} :: { [ImageLabel]: Stainlayout.Layout }, { __mode = "k" })
local Surfacepoints = setmetatable({} :: { [Instance]: { Time: number, Points: { Vector3 } } }, { __mode = "k" })

local function Makearrowpiece(Parent: GuiObject, Piece, Grow: number, Color: Color3)
	local Frame = Instance.new("Frame")
	Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	Frame.BackgroundColor3 = Color
	Frame.BorderSizePixel = 0
	Frame.Position = UDim2.fromOffset(Piece.Center.X, Piece.Center.Y)
	Frame.Size = UDim2.fromOffset(Piece.Size.X + Grow * 2, Piece.Size.Y + Grow * 2)
	Frame.Rotation = Piece.Rotation
	Frame.Parent = Parent
	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0.5, 0)
	Corner.Parent = Frame
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

	self.arrow = Instance.new("CanvasGroup")
	self.arrow.Name = "Arrow"
	self.arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	self.arrow.BackgroundTransparency = 1
	self.arrow.BorderSizePixel = 0
	self.arrow.Size = UDim2.fromOffset(Arrowwidth, Arrowheight)
	self.arrow.ZIndex = 2
	self.arrow.Visible = false
	self.arrow.Parent = self.gui
	for _, Piece in ipairs(Arrowpieces) do
		Makearrowpiece(self.arrow, Piece, Arrowoutline, Arrowoutlinecolor)
	end
	for _, Piece in ipairs(Arrowpieces) do
		Makearrowpiece(self.arrow, Piece, 0, Arrowfillcolor)
	end
	local Arrowuigradient = Instance.new("UIGradient")
	Arrowuigradient.Color = Arrowgradient
	Arrowuigradient.Rotation = 90
	Arrowuigradient.Parent = self.arrow

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
	self.textPadding = Instance.new("UIPadding")
	self.textPadding.PaddingLeft = UDim.new(0, 14)
	self.textPadding.PaddingRight = UDim.new(0, 14)
	self.textPadding.PaddingTop = UDim.new(0, 10)
	self.textPadding.PaddingBottom = UDim.new(0, 10)
	self.textPadding.Parent = self.text
	self.textSizeConstraint = Instance.new("UITextSizeConstraint")
	self.textSizeConstraint.MaxTextSize = Textsizemax
	self.textSizeConstraint.Parent = self.text

	self.key = Instance.new("ImageLabel")
	self.key.Name = "Key"
	self.key.AnchorPoint = Vector2.new(0, 0.5)
	self.key.BackgroundTransparency = 1
	self.key.ScaleType = Enum.ScaleType.Fit
	self.key.Position = UDim2.new(0, 12, 0.5, 0)
	self.key.Size = UDim2.fromOffset(Keysize, Keysize)
	self.key.Visible = false
	self.key.Parent = self.bubble
end

function Tutorialcontroller:Setkey(Image: string?)
	self.key.Visible = Image ~= nil
	self.key.Image = Image or ""
	self.textPadding.PaddingLeft = UDim.new(0, if Image then 12 + Keysize + Keygap else 14)
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

local function Castsurfacepoints(Part: BasePart, Face: Enum.NormalId, Facepoints: { Vector2 }): { Vector3 }
	local Localnormal = Vector3.FromNormalId(Face)
	local Worldnormal = Part.CFrame:VectorToWorldSpace(Localnormal)
	local Depth = math.abs(Localnormal:Dot(Part.Size))
	local Cleaning = Core:GetController("CleaningController")
	local Boxpoints = {}
	local Hitpoints = {}
	for _, Facepoint in ipairs(Facepoints) do
		local Boxpoint = Facemapping.GetDecalLocalPoint(Part.Size, Face.Name, Facepoint.X, Facepoint.Y)
		table.insert(Boxpoints, Boxpoint)
		local Origin = Part.CFrame:PointToWorldSpace(Boxpoint) + Worldnormal * Surfaceoffset
		local Hit = Cleaning:CastPart(Part, Origin, -Worldnormal * (Depth + Surfaceoffset * 2))
		if Hit then
			table.insert(Hitpoints, Part.CFrame:PointToObjectSpace(Hit.Position))
		end
	end
	return if #Hitpoints > 0 then Hitpoints else Boxpoints
end

function Tutorialcontroller:Getsurfacepointrect(Target: Instance, Part: BasePart, Face: Enum.NormalId, Facepoints: { Vector2 }): (Vector2?, Vector2?, boolean?)
	local Cached = Surfacepoints[Target]
	if not Cached or os.clock() - Cached.Time >= Surfacerefresh then
		Cached = { Time = os.clock(), Points = Castsurfacepoints(Part, Face, Facepoints) }
		Surfacepoints[Target] = Cached
	end
	local Points = {}
	local Center = Vector3.zero
	for _, Localpoint in ipairs(Cached.Points) do
		local Point = Part.CFrame:PointToWorldSpace(Localpoint)
		table.insert(Points, Point)
		Center += Point / #Cached.Points
	end
	local Worldnormal = Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Face))
	local Toviewer = Workspace.CurrentCamera.CFrame.Position - Center
	local Position, Size = self:Projectrect(Points)
	return Position, Size, Toviewer.Unit:Dot(Worldnormal) <= 0
end

function Tutorialcontroller:Getstainrect(Texture: ImageLabel): (Vector2?, Vector2?, boolean?)
	local Layout = Stainlayouts[Texture]
	if not Layout then
		Layout = Stainlayout.GetLayout(Texture)
		Stainlayouts[Texture] = Layout
	end
	local Facepoints = {}
	for _, Point in ipairs(Staingrid) do
		table.insert(Facepoints, Stainlayout.GetFacePoint(Layout, Point))
	end
	return self:Getsurfacepointrect(Texture, Layout.Part, Layout.Face, Facepoints)
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

function Tutorialcontroller:Getdecalrect(Target: Decal): (Vector2?, Vector2?, boolean?)
	return self:Getsurfacepointrect(Target, Target.Parent :: BasePart, Target.Face, Decalgrid)
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

local function Targetnormal(Target: Instance): Vector3?
	if Target:IsA("Decal") then
		return (Target.Parent :: BasePart).CFrame:VectorToWorldSpace(Vector3.FromNormalId(Target.Face))
	end
	if Target:IsA("BasePart") then
		local Image = Target:FindFirstChildWhichIsA("Decal") or Target:FindFirstChildWhichIsA("SurfaceGui")
		return if Image then Target.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Image.Face)) else Thinaxis(Target)
	end
	if Target:IsA("ImageLabel") and Isstaintexture(Target) then
		local Layout = Stainlayouts[Target] or Stainlayout.GetLayout(Target)
		return Layout.Part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(Layout.Face))
	end
	return nil
end

local function Facesdown(Target: Instance): boolean
	local Normal = Targetnormal(Target)
	return Normal ~= nil and Normal.Y < Downfacing
end

local function Facesup(Target: Instance): boolean
	local Normal = Targetnormal(Target)
	return Normal ~= nil and Normal.Y > Upfacing
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

function Tutorialcontroller:Placearrow(Position: Vector2?, Size: Vector2?)
	self.arrow.Visible = Position ~= nil and Size ~= nil
	if not Position or not Size then
		return
	end
	local Viewport = self.gui.AbsoluteSize
	local Half = Vector2.new(Arrowwidth, Arrowheight) * 0.5
	local Offset = Arrowgap + Arrowbob * (0.5 + 0.5 * math.sin(os.clock() * Arrowspeed)) + Half.Y
	local Centerx = Position.X + Size.X * 0.5
	local Centery = if self.arrowUp then Position.Y + Size.Y + Offset else Position.Y - Offset
	Centerx = math.min(math.max(Centerx, Half.X), math.max(Viewport.X - Half.X, Half.X))
	local Bubble = self.bubbleRect
	if Bubble and Centerx + Half.X > Bubble.Left and Centerx - Half.X < Bubble.Right then
		if self.arrowUp then
			Centery -= math.clamp(Position.Y + Size.Y + Arrowreach + Arrowclearance - Bubble.Top, 0, Arrowheight)
		else
			Centery += math.clamp(Bubble.Bottom + Arrowclearance - Position.Y + Arrowreach, 0, Arrowheight)
		end
	end
	Centery = math.min(math.max(Centery, Half.Y), math.max(Viewport.Y - Half.Y, Half.Y))
	self.arrow.Position = UDim2.fromOffset(math.floor(Centerx), math.floor(Centery))
	self.arrow.Rotation = if self.arrowUp then 180 else 0
end

function Tutorialcontroller:Placebubble(Position: Vector2?, Size: Vector2?)
	local Viewport = self.gui.AbsoluteSize
	local Screenscale = math.clamp(Viewport.Y / Compactheight, Compactscale, 1)
	local Scale = (if self.bubbleLarge then Largetextscale else 1) * Screenscale
	self.textSizeConstraint.MaxTextSize = math.floor((if self.bubbleLarge then Largetextsizemax else Textsizemax) * Screenscale)
	local Keywidth = if self.key.Visible then Keysize + Keygap else 0
	local Width = math.min((Textwidth + Keywidth) * Scale, Viewport.X - 24)
	local Height = math.min(Textheight * Scale, Viewport.Y - 24)
	self.bubble.Size = UDim2.fromOffset(Width, Height)

	local Centerx, Bubbley
	if Position and Size then
		Centerx = Position.X + Size.X * 0.5
		local Above = Position.Y - Arrowreach - Textgap - Height
		self.arrowUp = Above < Edgemargin
		Bubbley = if self.arrowUp then Position.Y + Size.Y + Arrowreach + Textgap else Above
	else
		Centerx = Viewport.X * 0.5
		Bubbley = Viewport.Y * 0.62
	end
	Centerx = math.min(math.max(Centerx, Width * 0.5 + 12), math.max(Viewport.X - Width * 0.5 - 12, Width * 0.5 + 12))
	Bubbley = math.min(math.max(Bubbley, 12), math.max(Viewport.Y - Height - 12, 12))
	self.bubble.Position = UDim2.fromOffset(Centerx, Bubbley)
	self.bubbleRect = { Left = Centerx - Width * 0.5, Right = Centerx + Width * 0.5, Top = Bubbley, Bottom = Bubbley + Height }
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

local function Collecttexts(Texts: { string }, Value: any)
	if type(Value) == "string" then
		table.insert(Texts, Value)
	elseif type(Value) == "table" then
		for _, Text in pairs(Value) do
			table.insert(Texts, Text)
		end
	end
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
	local Image = if Definition then Definition.Image or Definition.Images[Kind] else ""
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
	local Offset = Gestures[self.gesture].Motion(os.clock() - self.gestureStart, Center, Viewport)
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
	if Index > #self.steps then
		return Index
	end
	while Index > 1 and not self.steps[Index].Checkpoint do
		Index -= 1
	end
	return Index
end

local function Inventoryrestored(): boolean
	local Items = Core:GetController("ComputerController").inventoryItems
	for _, Item in ipairs(Items) do
		if (tonumber(Item.RestorationPercent) or 0) < 100 then
			return false
		end
	end
	return #Items > 0
end

function Tutorialcontroller:Showstep(Index: number)
	if self.running and (Index == self.stepindex.Computer or Index == self.stepindex.Inventory) and Inventoryrestored() then
		Index = #self.steps + 1
	end
	while self.steps[Index] and self.steps[Index].Skip and self.steps[Index].Skip() do
		Index += 1
	end
	self.index = Index
	local Step = self.steps[Index]
	if not Step then
		self:Finish()
		return
	end
	if self.running then
		Remotemanager:FireServer(Servicename, "SetStep", Index)
	end
	self.bubbleLarge = Step.Large == true
	self.text.Text = ""
	self:Setkey(nil)
	if Step.OnEnter then
		task.spawn(Step.OnEnter)
	end
	self.stepStart = os.clock()
	self.doneSince = nil
	self.tapped = false
	self.toolEquipped = false
end

function Tutorialcontroller:Finish()
	self:Sethand(nil)
	self.gui.Enabled = false
	Core:GetController("ComputerController"):SetHighlighted(false)
	if self.lesson then
		self:Endlesson()
		return
	end
	self.running = false
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

local function Cleaningstarted(): boolean
	return Restoration():GetActiveObject() ~= nil
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

local function Underdecal(): Decal?
	local Object = Restoration():GetActiveObject()
	if not Object then
		return nil
	end
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if
			Descendant:IsA("Decal")
			and Cleaningconfig.DirtDecals[Descendant.Name]
			and Descendant:GetAttribute("Cleaned") ~= true
			and Facesdown(Descendant)
		then
			return Descendant
		end
	end
	return nil
end

local function Restoring(): boolean
	return Restoration():GetActiveObject() ~= nil and not Core:GetController("CompletionController"):IsVisible()
end

local function Customerwaiting(): boolean
	local Customer = Core:GetController("CustomerController")
	for _, Name in ipairs({ "DailyRewardController", "DonationController", "ExpositionController", "GroupRewardController", "LeaderboardController", "SettingController" }) do
		if Core:GetController(Name):IsOpen() then
			return false
		end
	end
	return Customer:CanInteract() and Customer:GetInteractionCustomer() ~= nil
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

local function Categoryclear(Kind: string): boolean
	return Categorymissing(Kind) or Categorydone(Kind)
end

local function Stainliquids(Name: string): { BasePart }
	local Drops = {}
	local Folder = Liquidfolder(Name)
	if Folder then
		for _, Drop in ipairs(Folder:GetChildren()) do
			local Target = Drop:FindFirstChild("StainTarget") :: ObjectValue?
			if Drop:IsA("BasePart") and Target and Target.Value then
				table.insert(Drops, Drop)
			end
		end
	end
	return Drops
end

local function Staindry(Name: string): boolean
	return #Stainliquids(Name) == 0
end

local function Stainliquidspot(Name: string): Instance?
	local Drops = Stainliquids(Name)
	for _, Drop in ipairs(Drops) do
		if not Isbehindobject(Drop) then
			return Drop
		end
	end
	return Drops[1] or Restoration():GetActiveObject()
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
	return Cleaned >= Total * math.min(Share, 1) * Fronttolerance
end

local function Dirtfinished(): boolean
	local Object = Restoration():GetActiveObject()
	return Object ~= nil
		and (tonumber(Object:GetAttribute("Cleaned_Dirt")) or 0) >= (tonumber(Object:GetAttribute("Total_Dirt")) or 0)
end

local function Allclean(): boolean
	local Object = Restoration():GetActiveObject()
	return Object ~= nil
		and (tonumber(Object:GetAttribute("CleanedSpots")) or 0) >= (tonumber(Object:GetAttribute("TotalSpots")) or 0)
end

function Tutorialcontroller:Getswipespot(): Vector2?
	local Object = Restoration():GetActiveObject()
	if not Object then
		return nil
	end
	local Position, Size = self:Getworldrect(Object)
	if not Position or not Size then
		return nil
	end
	local Viewport = self.gui.AbsoluteSize
	local Interface = Restoration():GetInterface()
	local Inset = Guiservice:GetGuiInset()
	local Centery = Position.Y + Size.Y * 0.5
	local Leftroom = Position.X
	local Rightroom = Viewport.X - Position.X - Size.X
	local Margin = Handsize * 0.5 + Handswipe
	local Right = Vector2.new(math.min(Position.X + Size.X + Rightroom * 0.5, Viewport.X - Margin), Centery)
	local Left = Vector2.new(math.max(Leftroom * 0.5, Margin), Centery)
	local Rightfree = not Interface:IsPointerOverUi(Right - Inset)
	local Leftfree = not Interface:IsPointerOverUi(Left - Inset)
	if Rightfree ~= Leftfree then
		return if Rightfree then Right else Left
	end
	return if Rightroom >= Leftroom then Right else Left
end

function Tutorialcontroller:Dirthidden(): boolean
	if os.clock() < self.hiddenCheck then
		return self.hidden
	end
	self.hiddenCheck = os.clock() + Lessoncheck
	self.hidden = false
	local Object = Restoration():GetActiveObject()
	if not Object then
		return false
	end
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("Decal") and Cleaningconfig.DirtDecals[Descendant.Name] and Descendant:GetAttribute("Cleaned") ~= true then
			if not self:Isbehind(Descendant) then
				self.hidden = false
				return false
			end
			self.hidden = true
		end
	end
	return self.hidden
end

function Tutorialcontroller:Watchlessons()
	if os.clock() < self.lessonCheck then
		return
	end
	self.lessonCheck = os.clock() + Lessoncheck
	local Learned = Players.LocalPlayer:GetAttribute("Lessons")
	if type(Learned) ~= "string" then
		return
	end
	local Done = string.split(Learned, ",")
	for _, Lesson in ipairs(self.lessons) do
		if not table.find(Done, Lesson.Id) and not self.lessonsShown[Lesson.Id] and Lesson.Active() and Lesson.Ready() then
			if not Lesson.Repeat then
				self.lessonsShown[Lesson.Id] = true
				Remotemanager:FireServer(Servicename, "LessonStep", Lesson.Id, false)
			end
			self.lesson = Lesson
			self.steps = Lesson.Steps
			self:Showstep(1)
			return
		end
	end
end

function Tutorialcontroller:Endlesson()
	local Lesson = self.lesson
	self.lesson = nil
	self.steps = self.tutorialsteps
	if Lesson.Learned() then
		Remotemanager:FireServer(Servicename, "LessonStep", Lesson.Id, true)
	end
end

function Tutorialcontroller:Update()
	if not self.running and not self.lesson then
		self:Watchlessons()
		return
	end
	if self.lesson and not self.lesson.Active() then
		self:Finish()
		return
	end
	if self.running and self.index >= self.stepindex.Computer and self.index <= self.stepindex.Card and Inventoryrestored() then
		self:Showstep(#self.steps + 1)
	end
	local Step = self.steps[self.index]
	if not Step then
		return
	end
	if Step.Waiting and Step.Waiting() then
		self.gui.Enabled = false
		self:Sethand(nil)
		if Step.Done() then
			self:Showstep(self.index + 1)
		end
		return
	end
	self.gui.Enabled = true
	if Step.Tool and not self.toolEquipped and Restoration():GetActiveObject() then
		self.toolEquipped = true
		if not Toolselected(Step.Tool) then
			Restoration():SelectTool(Firsttool(Step.Tool))
		end
	end
	if self.running then
		Restoration():GetInterface():SetContinueLocked(Step.AllowFinish ~= true)
	end
	local Target = Gettarget(Step.Target)
	local Computer = Core:GetController("ComputerController")
	Computer:SetHighlighted(Target ~= nil and Target == Computer.computer)
	local Position, Size, Behind = self:Resolve(Target)
	if Step.RaiseCamera and Target and Inspection():IsShowingBack() and Facesup(Target :: Instance) then
		self.raiseSince = self.raiseSince or os.clock()
		if not self.raised and os.clock() - self.raiseSince >= Raisedelay then
			self.raised = true
			Inspection():RaiseCamera(Raisepitch)
		end
	else
		self.raiseSince = nil
		self.raised = false
	end
	local Kind = Inputkind()
	local Text, Gesture, Keyimage, Handspot
	if Behind and Facesdown(Target :: Instance) then
		Position, Size = self:Resolve(Restoration():GetInterface().ReturnButton)
		Text = Textfor(Step.Fliptext or Fliptext)
	elseif Behind and Step.Turnhint then
		local Tilt = Facesup(Target :: Instance)
		Text = if Tilt then Tilttext[Kind] else Behindtext[Kind]
		Gesture = if Tilt then "Tilt" else "Rotate"
		Position, Size = nil, nil
		if Kind == "Touch" then
			Handspot = self:Getswipespot()
		end
	elseif Step.Tool and not Toolselected(Step.Tool) then
		local Tool = Firsttool(Step.Tool)
		Position, Size = self:Resolve(Toolbutton(Tool))
		Text = Textfor(Step.TakeText or "Take the " .. Toolnames[Tool] .. ".")
	else
		Text = Textfor(Step.Text)
		Gesture = if type(Step.Gesture) == "function" then Step.Gesture() else Step.Gesture
		local Hint = Restoration():GetInterface().CurrentHint
		if Step.Tool and Hint and Kind ~= "Touch" then
			Keyimage = Restoration():GetInterface():GetHintImage(Hint)
		end
	end
	if Text ~= self.text.Text then
		self.text.Text = Text
		self.bubbleScale.Scale = 0.86
		Tweenservice:Create(self.bubbleScale, Steptweeninfo, { Scale = 1 }):Play()
	end
	self:Setkey(Keyimage)
	self:Sethand(Gesture)
	self:Placebubble(Position, Size)
	self:Placearrow(Position, Size)
	if Handspot then
		self:Placehand(Handspot, Vector2.zero)
	else
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
			Text = "Buy this old clock!",
			OnEnter = function()
				self.boughtBaseline = #Core:GetController("ComputerController").inventoryItems
			end,
			Target = function()
				return Core:GetController("CustomerController").buyButton
			end,
			Waiting = function()
				return Core:GetController("CustomerController"):IsStartingItem() or Restoration():IsEditingObject()
			end,
			Done = function()
				return Cleaningstarted()
					or not Core:GetController("CustomerController"):IsStartingItem()
						and #Core:GetController("ComputerController").inventoryItems > (self.boughtBaseline or 0)
			end,
		},
		{
			Id = "Computer",
			Text = { Touch = "Tap your computer!", Mouse = "Click your computer!", Gamepad = "Open your computer." },
			Checkpoint = true,
			Skip = Cleaningstarted,
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
			Skip = Cleaningstarted,
			Target = function()
				return Core:GetController("ComputerController").inventoryNavButton
			end,
			Done = function()
				return Core:GetController("ComputerController").activePage == "Inventory"
			end,
		},
		{
			Id = "Card",
			Text = "Tap your clock.",
			Skip = Cleaningstarted,
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
			Skip = Cleaningstarted,
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
			Turnhint = true,
			Tool = Brushtools,
			Text = "Rub off the dirt!",
			Gesture = "ToothBrush",
			MaxSeconds = 40,
			Skip = Frontdone,
			Target = function()
				return Facedecal(1) or Categorydecal() or Restoration():GetActiveObject()
			end,
			Done = Frontdone,
		},
		{
			Id = "Last",
			Turnhint = true,
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
			Id = "Finish",
			Text = function()
				return if Allclean() then Finishtexts.Clean else Finishtexts.Partial
			end,
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
	}
	self.tutorialsteps = self.steps
	local function Drystep(Liquid: string)
		return {
			Id = "Dry",
			Turnhint = true,
			Tool = "HeatGun",
			Text = { Touch = "Dry the stain!", Mouse = "Hold click to dry the stain!", Gamepad = "Hold R2 to dry the stain!" },
			Gesture = "HeatGun",
			MaxSeconds = 45,
			Skip = function()
				return Staindry(Liquid)
			end,
			Target = function()
				return Stainliquidspot(Liquid)
			end,
			Done = function()
				return Staindry(Liquid)
			end,
		}
	end
	self.lessons = {
		{
			Id = "Customer",
			Repeat = true,
			Active = Customerwaiting,
			Ready = function()
				local Purchases = Players.LocalPlayer:GetAttribute("StarterPurchases") or Customerconfig.GuidedStarterPurchases
				return Purchases < Customerconfig.GuidedStarterPurchases
			end,
			Learned = function()
				return false
			end,
			Steps = {
				{
					Id = "Customer",
					Text = { Touch = "Tap the customer!", Mouse = "Click the customer!", Gamepad = "Talk to the customer!" },
					Target = function()
						return Core:GetController("CustomerController"):GetInteractionCustomer()
					end,
					Done = function()
						return Core:GetController("CustomerController"):IsVisible()
					end,
				},
			},
		},
		{
			Id = "Flip",
			Active = Restoring,
			Ready = function()
				return Underdecal() ~= nil and self:Dirthidden()
			end,
			Learned = function()
				return not self:Dirthidden()
			end,
			Steps = {
				{
					Id = "Flip",
					Fliptext = Undertext,
					Text = "Rub off the dirt!",
					MaxSeconds = 30,
					Target = function()
						return Underdecal() or Categorydecal() or Restoration():GetActiveObject()
					end,
					Done = function()
						return not self:Dirthidden()
					end,
				},
			},
		},
		{
			Id = "Sticker",
			Active = Restoring,
			Ready = function()
				return not Categoryclear("Sticker")
			end,
			Learned = function()
				return Categorydone("Sticker")
			end,
			Steps = {
				{
					Id = "Sticker",
					Tool = "Tweezers",
					Turnhint = true,
					Text = { Touch = "Pull the sticker off!", Mouse = "Hold click and pull the sticker off!", Gamepad = "Hold R2 and pull the sticker off!" },
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
			},
		},
		{
			Id = "Turn",
			Active = Restoring,
			Ready = function()
				return Categoryclear("Sticker") and Restoration():GetActiveObject():GetAttribute("FrontDirt") ~= true and self:Dirthidden()
			end,
			Learned = function()
				return not self:Dirthidden()
			end,
			Steps = {
				{
					Id = "Turn",
					Turnhint = true,
					RaiseCamera = true,
					Tool = Brushtools,
					Text = "Clean every side!",
					Gesture = "ToothBrush",
					MaxSeconds = 30,
					Target = function()
						return Categorydecal() or Restoration():GetActiveObject()
					end,
					Done = function()
						return not self:Dirthidden()
					end,
				},
			},
		},
		{
			Id = "Ink",
			Active = Restoring,
			Ready = function()
				return Categoryclear("Sticker") and not Categoryclear("Ink")
			end,
			Learned = function()
				return Categorydone("Ink")
			end,
			Steps = {
				{
					Id = "Pour",
					Turnhint = true,
					Tool = "Solvent",
					Text = { Touch = "Pour it on the ink!", Mouse = "Hold click to pour it on the ink!", Gamepad = "Hold R2 to pour it on the ink!" },
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
					Turnhint = true,
					Tool = "CottonTip",
					Text = "Rub the ink away!",
					Gesture = "CottonTip",
					MaxSeconds = 90,
					Skip = function()
						return Categoryclear("Ink") or not Hasliquid("Ink", "HasSolvent")
					end,
					Target = function()
						return Categoryspot("Ink")
					end,
					Done = function()
						return Categorydone("Ink")
					end,
				},
				Drystep("SolventLiquid"),
			},
		},
		{
			Id = "Scratch",
			Active = Restoring,
			Ready = function()
				return Categoryclear("Sticker") and not Categoryclear("Scratch")
			end,
			Learned = function()
				return Categorydone("Scratch")
			end,
			Steps = {
				{
					Id = "Polish",
					Turnhint = true,
					Tool = "Polish",
					Text = { Touch = "Rub it on the scratch!", Mouse = "Hold click to rub it on the scratch!", Gamepad = "Hold R2 to rub it on the scratch!" },
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
					Turnhint = true,
					Tool = "CottonTip",
					Text = "Rub the scratch away!",
					Gesture = "CottonTip",
					MaxSeconds = 90,
					Skip = function()
						return Categoryclear("Scratch") or not Hasliquid("Scratch", "HasPolish")
					end,
					Target = function()
						return Categoryspot("Scratch")
					end,
					Done = function()
						return Categorydone("Scratch")
					end,
				},
				Drystep("PolishLiquid"),
			},
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
	self.lesson = nil
	self.lessonsShown = {}
	self.lessonCheck = 0
	self.hiddenCheck = 0
	self.hidden = false
	self.index = 0
	self.stepStart = 0
end

function Tutorialcontroller:Preparetexts()
	local Texts = {}
	for _, Value in ipairs({ Behindtext, Tilttext, Fliptext, Undertext, Finishtexts }) do
		Collecttexts(Texts, Value)
	end
	for _, Name in pairs(Toolnames) do
		Collecttexts(Texts, "Take the " .. Name .. ".")
	end
	for _, Step in ipairs(self.tutorialsteps) do
		Collecttexts(Texts, Step.Text)
	end
	for _, Lesson in ipairs(self.lessons) do
		for _, Step in ipairs(Lesson.Steps) do
			Collecttexts(Texts, Step.Text)
		end
	end
	Translation.Prepare(Texts)
end

function Tutorialcontroller:Start()
	self:Buildsteps()
	self:Preparetexts()
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
