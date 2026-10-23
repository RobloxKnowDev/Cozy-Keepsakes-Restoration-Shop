local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Soundservice = game:GetService("SoundService")
local Tweenservice = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Typingsoundid = "rbxassetid://131238032"
local Collectsoundid = "rbxassetid://92277186786351"
local Beamtexture = "rbxassetid://16848361091"
local Bookicons = {
	Book1 = "rbxassetid://108126123654465",
	Book2 = "rbxassetid://109292934125001",
	Book3 = "rbxassetid://121638963416819",
	Book4 = "rbxassetid://105569047095787",
	Book5 = "rbxassetid://123819206582697",
}

local Player = Players.LocalPlayer
local Playergui = Player:WaitForChild("PlayerGui")
local Remotes = Replicatedstorage:WaitForChild("HalloweenBooksRemotes")
local Progressevent = Remotes:WaitForChild("Progress")
local Collectedevent = Remotes:WaitForChild("Collected")
local Dialogueevent = Remotes:WaitForChild("Dialogue")
local Getprogress = Remotes:WaitForChild("GetProgress")
local Booksfolder = Workspace:WaitForChild("HalloweenBooks")
local Npctop = Remotes:GetAttribute("NpcTop") :: Vector3
local Npccenter = Remotes:GetAttribute("NpcCenter") :: Vector3
local Zonecframe = Remotes:GetAttribute("ZoneCFrame") :: CFrame
local Zonesize = Remotes:GetAttribute("ZoneSize") :: Vector3
local Eventui = Playergui:WaitForChild("EventUi") :: ScreenGui
local Eventframe = Eventui:WaitForChild("Frame") :: Frame
local Eventtext = Eventframe:WaitForChild("Text") :: TextLabel
local Eventicon = Eventframe:WaitForChild("ImageLabel") :: ImageLabel
Eventui.ResetOnSpawn = false

local Orange = Color3.fromRGB(255, 140, 26)
local Yellow = Color3.fromRGB(255, 214, 92)
local Purple = Color3.fromRGB(122, 48, 196)
local Textfont = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local Collectduration = 0.6
local Bobheight = 0.35
local Bobspeed = 2
local Spinspeed = 1.2
local Tilt = math.rad(12)
local Iconstartscale = 1.3
local Iconappear = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local Iconfly = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local Iconspin = 25
local Countfallback = 2
local Typingdelay = 0.03
local Typingsoundevery = 2
local Speechstay = 5
local Wizardname = "Wizard"
local Housetext = "House unlocked!"
local Housetextscale = 0.4
local Beamwidth = 1.6
local Beamarrowspacing = 3
local Beamspeed = 2
local Beamheight = -1
local Poptween = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local Markertween = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local Glowtween = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local Wizardfloat = 0.4
local Wizardfloatspeed = 1.6
local Wizardsway = math.rad(6)
local Wizardswayspeed = 0.7
local Wizardhop = 1.4
local Wizardhopduration = 0.45
local Wizardauraidle = 6
local Wizardauraready = 20
local Breathspeed = 1.3
local Breathheight = 0.06
local Breathlean = math.rad(2)
local Castraise = math.rad(55)
local Castcircle = math.rad(9)
local Castspeed = 2.2
local Leftsway = math.rad(5)
local Leftspread = math.rad(7)
local Lookdistance = 25
local Lookspeed = 6
local Lookyawlimit = math.rad(70)
local Lookpitchlimit = math.rad(30)
local Lookaroundyaw = math.rad(25)
local Lookaroundspeed = 0.4
local Orbitbooks = { "Book1", "Book2", "Book3" }
local Orbitbooksize = 1.6
local Orbitmargin = 1.5
local Orbitspeed = 1.3
local Orbitbob = 0.4
local Orbittilt = math.rad(20)

local Animating = setmetatable({} :: { [Model]: boolean }, { __mode = "k" })
local State = { Books = 0, Required = 0, Claimed = false, Met = true }
local Displayed = 0
local Guiding = false
local Received = false
local Speechtoken = 0
local Wizardhopat = -math.huge
local Speech: BillboardGui
local Speechtext: TextLabel
local Speechpop: UIScale

local function Create(Class: string, Properties: { [string]: any }, Parent: Instance?): any
	local Object = Instance.new(Class)
	for Name, Value in pairs(Properties) do
		Object[Name] = Value
	end
	Object.Parent = Parent
	return Object
end

local function Pose(Rest: CFrame, Offset: CFrame): CFrame
	return CFrame.new(Rest.Position) * Offset * Rest.Rotation
end

local Typingsound = Create("Sound", { SoundId = Typingsoundid, Volume = 0.5 }, script)
local Collectsound = Create("Sound", { SoundId = Collectsoundid, Volume = 0.6 }, script)
local Eventpop = Create("UIScale", {}, Eventframe)
local Eventcolor = Eventtext.TextColor3
local Housemessage = Eventtext:Clone()
Housemessage.Name = "HouseMessage"
Housemessage.Text = Housetext
Housemessage.AnchorPoint = Vector2.new(0.5, 0)
Housemessage.Position = UDim2.new(0.5, 0, 1, 4)
Housemessage.Size = UDim2.new(1.5, 0, Housetextscale, 0)
Housemessage.TextSize = math.floor(Eventtext.TextSize * Housetextscale)
Housemessage.Visible = false
Housemessage.Parent = Eventframe
local Housepop = Create("UIScale", {}, Housemessage)

local Gui = Create("ScreenGui", {
	Name = "HalloweenBooksUi",
	ResetOnSpawn = false,
	IgnoreGuiInset = Eventui.IgnoreGuiInset,
	DisplayOrder = Eventui.DisplayOrder + 1,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, Playergui)

local Marker = Create("Part", {
	Name = "HalloweenMarker",
	Size = Vector3.new(1, 1, 1),
	CFrame = CFrame.new(Npctop + Vector3.new(0, 2.5, 0)),
	Transparency = 1,
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
})
local Markergui = Create("BillboardGui", {
	Size = UDim2.fromOffset(70, 70),
	AlwaysOnTop = true,
	LightInfluence = 0,
}, Marker)
Create("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	FontFace = Textfont,
	Text = "!",
	TextColor3 = Orange,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 0,
	TextSize = 64,
}, Markergui)
Tweenservice:Create(Markergui, Markertween, { StudsOffset = Vector3.new(0, 0.8, 0) }):Play()

local Startattachment = Create("Attachment", { Name = "HalloweenBeamStart", Position = Vector3.new(0, Beamheight, 0) })
local Targetattachment = Create("Attachment", { Name = "HalloweenBeamTarget" }, Marker)
Targetattachment.WorldPosition = Npccenter
Create("Beam", {
	Attachment0 = Startattachment,
	Attachment1 = Targetattachment,
	Texture = Beamtexture,
	TextureMode = Enum.TextureMode.Static,
	TextureLength = Beamarrowspacing,
	TextureSpeed = Beamspeed,
	Width0 = Beamwidth,
	Width1 = Beamwidth,
	FaceCamera = true,
	LightEmission = 1,
	LightInfluence = 0,
	Color = ColorSequence.new(Orange, Yellow),
	Transparency = NumberSequence.new(0.1),
}, Marker)

local function Showcount()
	Eventtext.Text = string.format("%d/%d", Displayed, State.Required)
end

local function Arrive()
	Displayed = math.min(Displayed + 1, State.Books)
	Showcount()
	Eventpop.Scale = 1.25
	Tweenservice:Create(Eventpop, Poptween, { Scale = 1 }):Play()
end

local function Flyicon(Kind: string)
	local Size = Eventicon.AbsoluteSize
	local Target = Eventicon.AbsolutePosition + Size / 2
	local Icon = Eventicon:Clone()
	Icon.Image = Bookicons[Kind]
	Icon.AnchorPoint = Vector2.new(0.5, 0.5)
	Icon.Position = UDim2.fromScale(0.5, 0.5)
	Icon.Size = UDim2.fromOffset(0, 0)
	Icon.Rotation = -Iconspin
	Icon.ZIndex = 10
	Icon.Parent = Gui
	local Appear = Tweenservice:Create(
		Icon,
		Iconappear,
		{ Size = UDim2.fromOffset(Size.X * Iconstartscale, Size.Y * Iconstartscale) }
	)
	Appear:Play()
	Appear.Completed:Wait()
	local Fly = Tweenservice:Create(Icon, Iconfly, {
		Position = UDim2.fromOffset(Target.X, Target.Y),
		Size = UDim2.fromOffset(Size.X, Size.Y),
		Rotation = Iconspin,
	})
	Fly:Play()
	Fly.Completed:Wait()
	Icon:Destroy()
	Arrive()
end

local function Showspeech(Message: string)
	while not Speech do
		task.wait()
	end
	Speechtoken += 1
	local Token = Speechtoken
	Speechtext.Text = Message
	Speechtext.MaxVisibleGraphemes = 0
	Speechpop.Scale = 0.6
	Tweenservice:Create(Speechpop, Poptween, { Scale = 1 }):Play()
	for Index = 1, utf8.len(Message) or #Message do
		if Speechtoken ~= Token then
			return
		end
		Speechtext.MaxVisibleGraphemes = Index
		if Index % Typingsoundevery == 1 then
			Soundservice:PlayLocalSound(Typingsound)
		end
		task.wait(Typingdelay)
	end
	Speechtext.MaxVisibleGraphemes = -1
	task.wait(Speechstay)
	if Speechtoken == Token then
		Speechtext.Text = Wizardname
		Speechpop.Scale = 0.6
		Tweenservice:Create(Speechpop, Poptween, { Scale = 1 }):Play()
	end
end

local function Burst(Position: Vector3, Color: Color3)
	local Attachment = Create("Attachment", {}, Workspace.Terrain)
	Attachment.WorldPosition = Position
	local Emitter = Create("ParticleEmitter", {
		Color = ColorSequence.new(Color, Orange),
		LightEmission = 1,
		Size = NumberSequence.new(0.5, 0),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		Rate = 0,
	}, Attachment)
	Emitter:Emit(30)
	task.delay(1.5, function()
		Attachment:Destroy()
	end)
end

local function Playcollect(Book: Model, Collector: Player)
	if Animating[Book] then
		return
	end
	Animating[Book] = true
	if Collector == Player then
		Soundservice:PlayLocalSound(Collectsound)
	end
	local Kind = Book:GetAttribute("Kind")
	local Start = Book:GetPivot()
	local Scale = Book:GetScale()
	Burst(Start.Position, Book:GetAttribute("Color") or Orange)
	local Started = os.clock()
	local Connection
	Connection = Runservice.RenderStepped:Connect(function()
		local Alpha = math.min((os.clock() - Started) / Collectduration, 1)
		local Eased = 1 - (1 - Alpha) ^ 3
		local Character = Collector.Character
		local Root = if Character then Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		local Goal = if Root then Root.Position else Start.Position + Vector3.new(0, 4, 0)
		local Position = Start.Position:Lerp(Goal, Eased) + Vector3.new(0, math.sin(Alpha * math.pi) * 2.5, 0)
		Book:PivotTo(CFrame.new(Position) * CFrame.Angles(0, Alpha * math.pi * 4, 0))
		Book:ScaleTo(Scale * math.max(1 - Eased * 0.85, 0.05))
		if Alpha >= 1 then
			Connection:Disconnect()
			Book:Destroy()
			if Collector == Player then
				Flyicon(Kind)
			end
		end
	end)
end

local function Applyprogress(Progress, Animate: boolean)
	State = Progress
	Guiding = Progress.Books >= Progress.Required and not Progress.Claimed
	Eventtext.TextColor3 = if Progress.Claimed then Orange else Eventcolor
	if Progress.Claimed and not Housemessage.Visible then
		Housemessage.Visible = true
		if Animate then
			Housepop.Scale = 0.3
			Tweenservice:Create(Housepop, Poptween, { Scale = 1 }):Play()
		end
	end
	if not Animate or Progress.Books < Displayed then
		Displayed = Progress.Books
		Showcount()
		return
	end
	if Progress.Books > Displayed then
		task.delay(Countfallback, function()
			if Displayed < State.Books then
				Displayed = State.Books
				Showcount()
			end
		end)
	end
end

local function Updatebooks(Now: number)
	for _, Book in ipairs(Booksfolder:GetChildren()) do
		local Base = Book:GetAttribute("Base")
		if Base and not Animating[Book] then
			local Seed = Book:GetAttribute("Seed")
			Book:PivotTo(
				Base
					* CFrame.new(0, math.sin(Now * Bobspeed + Seed) * Bobheight, 0)
					* CFrame.Angles(0, Now * Spinspeed, 0)
					* CFrame.Angles(Tilt, 0, 0)
			)
		end
	end
end

local function Inzone(Position: Vector3): boolean
	local Local = Zonecframe:PointToObjectSpace(Position)
	return math.abs(Local.X) <= Zonesize.X / 2 and math.abs(Local.Z) <= Zonesize.Z / 2
end

local function Updatebeam()
	local Character = Player.Character
	local Root = if Character then Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if Root and Startattachment.Parent ~= Root then
		Startattachment.Parent = Root
	end
	local Intro = Root ~= nil and not State.Met and State.Books == 0 and Inzone(Root.Position)
	Marker.Parent = if Guiding or Intro then Workspace else nil
end

local function Orbitbook(Template: Model): Model
	local Book = Template:Clone()
	for _, Part in ipairs(Book:GetDescendants()) do
		if Part:IsA("BasePart") then
			Part.Anchored = true
			Part.CanCollide = false
			Part.CanQuery = false
			Part.CanTouch = false
			Part.CastShadow = false
		end
	end
	local Size = Book:GetExtentsSize()
	Book:ScaleTo(Book:GetScale() * Orbitbooksize / math.max(Size.X, Size.Y, Size.Z))
	local Center = Book:GetBoundingBox()
	Book.WorldPivot = Center
	Book.Parent = Workspace
	return Book
end

local function Setupwizard()
	local Wizard = Workspace:WaitForChild("EventMap"):WaitForChild("Wizard") :: Model
	local Head = Wizard:WaitForChild("Head") :: BasePart
	local Billboard = Head:WaitForChild("BillboardGui") :: BillboardGui
	local Bubble = Billboard:WaitForChild("Frame")
	Speechtext = Bubble:WaitForChild("Text")
	Speechpop = Create("UIScale", {}, Bubble)
	Speechtext.Text = Wizardname
	Billboard.Enabled = true
	Speech = Billboard
	local Torso = Wizard:WaitForChild("Torso") :: BasePart
	local Rootpart = Wizard:WaitForChild("HumanoidRootPart") :: BasePart
	local Rightarm = Wizard:WaitForChild("Right Arm") :: BasePart
	local Neck = Torso:WaitForChild("Neck") :: Motor6D
	local Rightshoulder = Torso:WaitForChild("Right Shoulder") :: Motor6D
	local Leftshoulder = Torso:WaitForChild("Left Shoulder") :: Motor6D
	local Rootjoint = Rootpart:WaitForChild("RootJoint") :: Motor6D
	local Neckrest = Neck.C0
	local Rightrest = Rightshoulder.C0
	local Leftrest = Leftshoulder.C0
	local Rootrest = Rootjoint.C0
	local Base = Wizard:GetPivot()
	local Boxcframe, Boxsize = Wizard:GetBoundingBox()
	local Orbitcenter = Base:ToObjectSpace(Boxcframe).Position + Vector3.new(0, Boxsize.Y * 0.1, 0)
	local Orbitradius = math.max(Boxsize.X, Boxsize.Z) / 2 + Orbitmargin
	local Templates = Replicatedstorage:WaitForChild("Assets"):WaitForChild("Book")
	local Orbit = {}
	for Index, Name in ipairs(Orbitbooks) do
		Orbit[Index] = Orbitbook(Templates:WaitForChild(Name) :: Model)
	end
	local Aura = Create("ParticleEmitter", {
		Color = ColorSequence.new(Purple, Orange),
		LightEmission = 1,
		Size = NumberSequence.new(0.35, 0),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(1.5, 3),
		Acceleration = Vector3.new(0, 2, 0),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = Wizardauraidle,
	}, Wizard.PrimaryPart)
	local Glow = Create("PointLight", { Color = Purple, Range = 14, Brightness = 2 }, Wizard.PrimaryPart)
	Tweenservice:Create(Glow, Glowtween, { Brightness = 0.6 }):Play()
	local Hand = Create("Attachment", { Position = Vector3.new(0, -Rightarm.Size.Y / 2, 0) }, Rightarm)
	Create("ParticleEmitter", {
		Color = ColorSequence.new(Yellow, Purple),
		LightEmission = 1,
		Size = NumberSequence.new(0.25, 0),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 1.5, 0),
		Rate = 14,
	}, Hand)
	local Yaw = 0
	local Pitch = 0
	Runservice.RenderStepped:Connect(function(Delta)
		local Now = os.clock()
		local Hop = math.clamp((Now - Wizardhopat) / Wizardhopduration, 0, 1)
		local Lift = Wizardfloat + math.sin(Now * Wizardfloatspeed) * Wizardfloat + math.sin(Hop * math.pi) * Wizardhop
		local Pivot = Base * CFrame.new(0, Lift, 0) * CFrame.Angles(0, math.sin(Now * Wizardswayspeed) * Wizardsway, 0)
		Wizard:PivotTo(Pivot)
		Aura.Rate = if Guiding then Wizardauraready else Wizardauraidle
		local Middle = (Pivot * CFrame.new(Orbitcenter)).Position
		for Index, Book in ipairs(Orbit) do
			local Angle = Now * Orbitspeed + Index * math.pi * 2 / #Orbit
			local Position = Middle
				+ Vector3.new(math.cos(Angle) * Orbitradius, math.sin(Now * 2 + Index) * Orbitbob, math.sin(Angle) * Orbitradius)
			Book:PivotTo(CFrame.lookAt(Position, Middle) * CFrame.Angles(0, math.pi / 2, Orbittilt))
		end
		local Breath = math.sin(Now * Breathspeed)
		Rootjoint.C0 =
			Pose(Rootrest, CFrame.new(0, Breath * Breathheight, 0) * CFrame.Angles(Breath * Breathlean, 0, 0))
		Rightshoulder.C0 = Pose(
			Rightrest,
			CFrame.Angles(Castraise + math.sin(Now * Castspeed) * Castcircle, 0, math.cos(Now * Castspeed) * Castcircle)
		)
		Leftshoulder.C0 = Pose(Leftrest, CFrame.Angles(math.sin(Now * Breathspeed + 1) * Leftsway, 0, -Leftspread))
		local Wantyaw = math.sin(Now * Lookaroundspeed) * Lookaroundyaw
		local Wantpitch = 0
		local Character = Player.Character
		local Target = if Character then Character:FindFirstChild("Head") :: BasePart? else nil
		if Target and (Target.Position - Head.Position).Magnitude <= Lookdistance then
			local Direction = Torso.CFrame:VectorToObjectSpace(Target.Position - Head.Position)
			Wantyaw = math.clamp(math.atan2(-Direction.X, -Direction.Z), -Lookyawlimit, Lookyawlimit)
			Wantpitch = math.clamp(
				math.atan2(Direction.Y, Vector2.new(Direction.X, Direction.Z).Magnitude),
				-Lookpitchlimit,
				Lookpitchlimit
			)
		end
		local Blend = math.min(Delta * Lookspeed, 1)
		Yaw += (Wantyaw - Yaw) * Blend
		Pitch += (Wantpitch - Pitch) * Blend
		Neck.C0 = Pose(Neckrest, CFrame.Angles(0, Yaw, 0) * CFrame.Angles(Pitch, 0, 0))
	end)
end

task.spawn(Setupwizard)

Progressevent.OnClientEvent:Connect(function(Progress)
	Received = true
	Applyprogress(Progress, true)
end)

Collectedevent.OnClientEvent:Connect(function(Book: Model?, Collector: Player)
	if Book then
		Playcollect(Book, Collector)
	end
end)

Dialogueevent.OnClientEvent:Connect(function(Message: string)
	Wizardhopat = os.clock()
	task.spawn(Showspeech, Message)
end)

Runservice.RenderStepped:Connect(function()
	Updatebooks(os.clock())
	Updatebeam()
end)

local Initial = Getprogress:InvokeServer()
if Initial and not Received then
	Applyprogress(Initial, false)
end
