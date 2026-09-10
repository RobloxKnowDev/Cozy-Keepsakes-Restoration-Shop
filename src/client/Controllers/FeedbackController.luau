local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FeedbackController = {
	Name = "FeedbackController",
	Priority = 2,
	intensity = "Full",
	activeParticles = 0,
	tweens = {},
}

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local FormatCurrency = require(ReplicatedStorage.Shared.Utils.CurrencyFormatter)
local MicroTween = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ReturnTween = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SuccessColor = Color3.fromRGB(255, 211, 105)
local ErrorColor = Color3.fromRGB(255, 132, 92)
local SoundFadeTween = TweenInfo.new(0.2, Enum.EasingStyle.Linear)
local MaxMusicVolume = 0.5
local MusicFadeTween = TweenInfo.new(2, Enum.EasingStyle.Linear)
local MusicLoopFadeTween = TweenInfo.new(1.2, Enum.EasingStyle.Linear)
local UiClickCooldown = 0.08
local ConfirmCooldown = 0.15
local DonationColor = Color3.fromRGB(126, 255, 145)
local RayCount = 14
local ChargeRingCount = 5
local MutationBuildupSeconds = 1.35

local function Shinesequence(Color: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color),
	})
end

local function GetScale(Target: GuiObject): UIScale
	local Scale = Target:FindFirstChildOfClass("UIScale")
	if Scale then return Scale end
	Scale = Instance.new("UIScale")
	Scale.Parent = Target
	return Scale
end

function FeedbackController:SetIntensity(Intensity: string)
	assert(Intensity == "Full" or Intensity == "Reduced" or Intensity == "Off")
	self.intensity = Intensity
end

function FeedbackController:IsDecorativeEnabled(): boolean
	return self.intensity ~= "Off"
end

function FeedbackController:IsMotionEnabled(): boolean
	return self.intensity == "Full" and not GuiService.ReducedMotionEnabled
end

function FeedbackController:Tween(Key: any, InstanceValue: Instance, Info: TweenInfo, Goal: { [string]: any }): Tween
	local Previous = self.tweens[Key]
	if Previous then Previous:Cancel() end
	local Tween = TweenService:Create(InstanceValue, Info, Goal)
	self.tweens[Key] = Tween
	Tween.Completed:Once(function()
		if self.tweens[Key] == Tween then self.tweens[Key] = nil end
	end)
	Tween:Play()
	return Tween
end

function FeedbackController:Pulse(Target: GuiObject, Strength: number?)
	if not self:IsDecorativeEnabled() then return end
	local Scale = GetScale(Target)
	local Amount = if self:IsMotionEnabled() then Strength or 1.08 else 1.025
	self:Tween(Scale, Scale, MicroTween, { Scale = Amount }).Completed:Once(function()
		self:Tween(Scale, Scale, ReturnTween, { Scale = 1 })
	end)
end

function FeedbackController:Shake(Target: GuiObject)
	if not self:IsMotionEnabled() then return end
	local Origin = Target.Position
	local Token = {}
	self.shakeToken = Token
	task.spawn(function()
		for Index = 1, 4 do
			if self.shakeToken ~= Token or not Target.Parent then return end
			Target.Position = Origin + UDim2.fromOffset(if Index % 2 == 0 then 4 else -4, 0)
			task.wait(0.035)
		end
		if Target.Parent then Target.Position = Origin end
	end)
end

function FeedbackController:Flash(Target: GuiObject, Color: Color3?)
	if not self:IsDecorativeEnabled() then return end
	local Flash = Instance.new("Frame")
	Flash.Name = "FeedbackFlash"
	Flash.AnchorPoint = Vector2.new(0.5, 0.5)
	Flash.Position = UDim2.fromScale(0.5, 0.5)
	Flash.Size = UDim2.fromScale(1, 1)
	Flash.BackgroundColor3 = Color or SuccessColor
	Flash.BackgroundTransparency = if self.intensity == "Reduced" then 0.72 else 0.42
	Flash.BorderSizePixel = 0
	Flash.ZIndex = Target.ZIndex + 4
	Flash.Parent = Target
	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0.25, 0)
	Corner.Parent = Flash
	TweenService:Create(Flash, TweenInfo.new(0.24), { BackgroundTransparency = 1, Size = UDim2.fromScale(1.08, 1.25) }):Play()
	Debris:AddItem(Flash, 0.3)
end

function FeedbackController:Burst(Target: GuiObject, Color: Color3, Count: number?)
	if not self:IsDecorativeEnabled() then return end
	local Budget = if self.intensity == "Reduced" then 4 else Count or 10
	Budget = math.min(Budget, 80 - self.activeParticles)
	for _ = 1, Budget do
		local Particle = Instance.new("Frame")
		Particle.Name = "FeedbackParticle"
		Particle.AnchorPoint = Vector2.new(0.5, 0.5)
		Particle.Position = UDim2.fromScale(0.5, 0.5)
		Particle.Size = UDim2.fromOffset(math.random(3, 7), math.random(3, 7))
		Particle.BackgroundColor3 = Color
		Particle.BorderSizePixel = 0
		Particle.ZIndex = Target.ZIndex + 5
		Particle.Parent = Target
		local Corner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(1, 0)
		Corner.Parent = Particle
		self.activeParticles += 1
		local Angle = math.random() * math.pi * 2
		local Distance = math.random(22, 55)
		local Tween = TweenService:Create(Particle, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(math.cos(Angle) * Distance, math.sin(Angle) * Distance),
			BackgroundTransparency = 1,
		})
		Tween:Play()
		Tween.Completed:Once(function()
			self.activeParticles -= 1
			Particle:Destroy()
		end)
	end
end

function FeedbackController:FloatingText(Parent: GuiObject, Text: string, Color: Color3)
	local Label = Instance.new("TextLabel")
	Label.Name = "FeedbackText"
	Label.AnchorPoint = Vector2.new(0.5, 0.5)
	Label.Position = UDim2.fromScale(0.5, 0.45)
	Label.Size = UDim2.fromOffset(300, 52)
	Label.BackgroundTransparency = 1
	Label.Font = Enum.Font.GothamBold
	Label.Text = Text
	Label.TextColor3 = Color
	Label.TextScaled = true
	Label.TextStrokeTransparency = 0.55
	Label.ZIndex = Parent.ZIndex + 10
	Label.Parent = Parent
	local Scale = GetScale(Label)
	Scale.Scale = if self:IsMotionEnabled() then 0.65 else 1
	TweenService:Create(Scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(Label, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.65), {
		Position = Label.Position - UDim2.fromOffset(0, 28),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(Label, 1.05)
end

function FeedbackController:CenterText(Text: string, Color: Color3, Major: boolean?)
	if not self:IsDecorativeEnabled() then return end
	local Label = Instance.new("TextLabel")
	Label.Name = "CenterFeedbackText"
	Label.AnchorPoint = Vector2.new(0.5, 0.5)
	Label.Position = UDim2.fromScale(0.5, 0.5)
	Label.Size = UDim2.fromOffset(if Major then 620 else 460, if Major then 100 else 74)
	Label.BackgroundTransparency = 1
	Label.Font = Enum.Font.GothamBlack
	Label.Text = Text
	Label.TextColor3 = Color
	Label.TextScaled = true
	Label.TextStrokeColor3 = Color3.fromRGB(49, 35, 24)
	Label.TextStrokeTransparency = 0.25
	Label.ZIndex = 20
	Label.Parent = self.overlay
	local Scale = GetScale(Label)
	Scale.Scale = if self:IsMotionEnabled() then 0.35 else 1
	TweenService:Create(Scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(Label, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.72), {
		Position = UDim2.fromScale(0.5, 0.45),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	self:Burst(self.overlay, Color, if Major then 32 else 14)
	Debris:AddItem(Label, 1.05)
end

function FeedbackController:CleaningPercent(Position: Vector2, Amount: number)
	if not self:IsDecorativeEnabled() then return end
	local Label = Instance.new("TextLabel")
	Label.Name = "CleaningPercentText"
	Label.AnchorPoint = Vector2.new(0.5, 0.5)
	Label.Position = UDim2.fromOffset(Position.X + math.random(-42, 42), Position.Y + math.random(-32, 22))
	local Size = math.random(18, 28)
	Label.Size = UDim2.fromOffset(Size * 2.7, Size)
	Label.BackgroundTransparency = 1
	Label.Font = Enum.Font.GothamBlack
	Label.Text = if Amount >= 1 then string.format("+%d%%", Amount) else string.format("+%.1f%%", Amount)
	Label.TextColor3 = Color3.fromRGB(255, 255, 255)
	Label.TextScaled = true
	Label.TextStrokeColor3 = Color3.fromRGB(69, 43, 24)
	Label.TextStrokeTransparency = 0.2
	Label.Rotation = math.random(6, 12) * (if math.random(0, 1) == 0 then -1 else 1)
	Label.ZIndex = 18
	Label.Parent = self.overlay
	if Amount >= 2 then
		local Gradient = Instance.new("UIGradient")
		Gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 75, 75)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 220, 70)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(85, 255, 135)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 195, 255)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(155, 100, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 95, 195)),
		})
		Gradient.Parent = Label
	else
		local Hue = math.random()
		local Gradient = Instance.new("UIGradient")
		Gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV((Hue - 0.035) % 1, 0.36, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromHSV(Hue, 0.48, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV((Hue + 0.035) % 1, 0.36, 1)),
		})
		Gradient.Parent = Label
	end
	local Scale = GetScale(Label)
	Scale.Scale = if self:IsMotionEnabled() then 0.4 else 1
	TweenService:Create(Scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(Label, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), {
		Rotation = -Label.Rotation,
	}):Play()
	TweenService:Create(Label, TweenInfo.new(0.56, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = Label.Position - UDim2.fromOffset(math.random(-14, 14), math.random(38, 64)),
	}):Play()
	TweenService:Create(Label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.38), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(Label, 0.62)
end

function FeedbackController:RestorationCompleteText()
	if not self:IsDecorativeEnabled() then return end
	local Now = os.clock()
	if self.lastRestorationComplete and Now - self.lastRestorationComplete < 2.5 then return end
	self.lastRestorationComplete = Now
	local Container = Instance.new("Frame")
	Container.Name = "RestorationCompleteText"
	Container.AnchorPoint = Vector2.new(0.5, 0.5)
	Container.Position = UDim2.fromScale(0.5, 0.48)
	Container.Size = UDim2.fromOffset(720, 150)
	Container.BackgroundTransparency = 1
	Container.ZIndex = 24
	Container.Parent = self.overlay
	local Glow = Instance.new("TextLabel")
	Glow.Name = "Glow"
	Glow.AnchorPoint = Vector2.new(0.5, 0.5)
	Glow.Position = UDim2.fromScale(0.5, 0.38)
	Glow.Size = UDim2.fromScale(1.08, 0.68)
	Glow.BackgroundTransparency = 1
	Glow.Font = Enum.Font.GothamBlack
	Glow.Text = "RESTORATION COMPLETE!"
	Glow.TextColor3 = Color3.fromRGB(255, 177, 59)
	Glow.TextScaled = true
	Glow.TextTransparency = 0.48
	Glow.ZIndex = 24
	Glow.Parent = Container
	local Title = Instance.new("TextLabel")
	Title.Name = "Title"
	Title.AnchorPoint = Vector2.new(0.5, 0.5)
	Title.Position = UDim2.fromScale(0.5, 0.38)
	Title.Size = UDim2.fromScale(1, 0.62)
	Title.BackgroundTransparency = 1
	Title.Font = Enum.Font.GothamBlack
	Title.Text = "RESTORATION COMPLETE!"
	Title.TextColor3 = Color3.fromRGB(255, 244, 196)
	Title.TextScaled = true
	Title.TextStrokeColor3 = Color3.fromRGB(83, 48, 21)
	Title.TextStrokeTransparency = 0.12
	Title.ZIndex = 26
	Title.Parent = Container
	local Gradient = Instance.new("UIGradient")
	Gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 178, 54)),
		ColorSequenceKeypoint.new(0.42, Color3.fromRGB(255, 252, 218)),
		ColorSequenceKeypoint.new(0.58, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 190, 67)),
	})
	Gradient.Offset = Vector2.new(-1, 0)
	Gradient.Parent = Title
	local Subtitle = Instance.new("TextLabel")
	Subtitle.Name = "Subtitle"
	Subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	Subtitle.Position = UDim2.fromScale(0.5, 0.82)
	Subtitle.Size = UDim2.fromScale(0.58, 0.25)
	Subtitle.BackgroundTransparency = 1
	Subtitle.Font = Enum.Font.GothamBold
	Subtitle.Text = "100%  •  PERFECT CLEAN"
	Subtitle.TextColor3 = Color3.fromRGB(255, 219, 127)
	Subtitle.TextScaled = true
	Subtitle.TextStrokeColor3 = Color3.fromRGB(73, 43, 24)
	Subtitle.TextStrokeTransparency = 0.35
	Subtitle.ZIndex = 26
	Subtitle.Parent = Container
	local Scale = GetScale(Container)
	Scale.Scale = if self:IsMotionEnabled() then 0.2 else 1
	TweenService:Create(Scale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(Glow, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 1, true), {
		Size = UDim2.fromScale(1.16, 0.76),
		TextTransparency = 0.72,
	}):Play()
	TweenService:Create(Gradient, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Offset = Vector2.new(1, 0) }):Play()
	TweenService:Create(Container, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.3), {
		Position = UDim2.fromScale(0.5, 0.43),
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(Title, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.34), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	TweenService:Create(Glow, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.34), { TextTransparency = 1 }):Play()
	TweenService:Create(Subtitle, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.38), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	self:Burst(self.overlay, Color3.fromRGB(255, 211, 105), 52)
	Debris:AddItem(Container, 1.7)
end

function FeedbackController:GlobalCompletion()
	local Now = os.clock()
	if self.lastGlobalCompletion and Now - self.lastGlobalCompletion < 2.5 then return end
	self.lastGlobalCompletion = Now
	for Index = 1, 3 do
		local Wave = Instance.new("Frame")
		Wave.Name = "CompletionWave"
		Wave.AnchorPoint = Vector2.new(0.5, 0.5)
		Wave.Position = UDim2.fromScale(0.5, 0.48)
		Wave.Size = UDim2.fromOffset(80, 80)
		Wave.BackgroundTransparency = 1
		Wave.ZIndex = 21
		Wave.Parent = self.overlay
		local Corner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(1, 0)
		Corner.Parent = Wave
		local Stroke = Instance.new("UIStroke")
		Stroke.Color = if Index == 1 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 203, 91)
		Stroke.Thickness = 5 - Index
		Stroke.Transparency = 0.12
		Stroke.Parent = Wave
		task.delay((Index - 1) * 0.1, function()
			TweenService:Create(Wave, TweenInfo.new(0.72, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(760 + Index * 90, 290 + Index * 50),
			}):Play()
			TweenService:Create(Stroke, TweenInfo.new(0.72, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
				Thickness = 1,
			}):Play()
		end)
		Debris:AddItem(Wave, 0.95)
	end
	self:RestorationCompleteText()
	self:Burst(self.overlay, Color3.fromRGB(255, 224, 143), 60)
	self:FovPunch(3)
end

function FeedbackController:Shockwave(Color: Color3, Count: number)
	if not self:IsDecorativeEnabled() then return end
	for Index = 1, Count do
		local Wave = Instance.new("Frame")
		Wave.Name = "Shockwave"
		Wave.AnchorPoint = Vector2.new(0.5, 0.5)
		Wave.Position = UDim2.fromScale(0.5, 0.5)
		Wave.Size = UDim2.fromOffset(60, 60)
		Wave.BackgroundTransparency = 1
		Wave.ZIndex = 29
		Wave.Parent = self.overlay
		local Corner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(1, 0)
		Corner.Parent = Wave
		local Stroke = Instance.new("UIStroke")
		Stroke.Color = Color
		Stroke.Thickness = 7 - Index
		Stroke.Transparency = 0.08
		Stroke.Parent = Wave
		task.delay((Index - 1) * 0.11, function()
			TweenService:Create(Wave, TweenInfo.new(0.85, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(1000 + Index * 180, 1000 + Index * 180),
			}):Play()
			TweenService:Create(Stroke, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
				Thickness = 1,
			}):Play()
		end)
		Debris:AddItem(Wave, 1.3)
	end
end

function FeedbackController:MutationReveal(Name: string, Color: Color3, Rainbow: boolean?)
	if not self:IsDecorativeEnabled() then return end
	local Buildup = MutationBuildupSeconds
	local Camera = Workspace.CurrentCamera
	local Fovorigin = Camera.FieldOfView
	local Container = Instance.new("Frame")
	Container.Name = "MutationReveal"
	Container.AnchorPoint = Vector2.new(0.5, 0.5)
	Container.Position = UDim2.fromScale(0.5, 0.5)
	Container.Size = UDim2.fromScale(1, 1)
	Container.BackgroundTransparency = 1
	Container.ZIndex = 30
	Container.Parent = self.overlay

	local Shine = nil
	local Tinted = {}
	local function Tint(Object: Instance, Property: string)
		table.insert(Tinted, { Object, Property })
	end

	local Dim = Instance.new("Frame")
	Dim.Name = "Dim"
	Dim.Size = UDim2.fromScale(1, 1)
	Dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	Dim.BackgroundTransparency = 1
	Dim.BorderSizePixel = 0
	Dim.ZIndex = 30
	Dim.Parent = Container
	TweenService:Create(Dim, TweenInfo.new(Buildup * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.42,
	}):Play()

	local Coreglow = Instance.new("Frame")
	Coreglow.Name = "Core"
	Coreglow.AnchorPoint = Vector2.new(0.5, 0.5)
	Coreglow.Position = UDim2.fromScale(0.5, 0.5)
	Coreglow.Size = UDim2.fromOffset(0, 0)
	Coreglow.BackgroundColor3 = Color
	Coreglow.BackgroundTransparency = 0.15
	Coreglow.BorderSizePixel = 0
	Coreglow.ZIndex = 31
	Coreglow.Parent = Container
	Tint(Coreglow, "BackgroundColor3")
	local Corecorner = Instance.new("UICorner")
	Corecorner.CornerRadius = UDim.new(1, 0)
	Corecorner.Parent = Coreglow
	local Corestroke = Instance.new("UIStroke")
	Corestroke.Color = Color3.fromRGB(255, 255, 255)
	Corestroke.Thickness = 2
	Corestroke.Transparency = 0.4
	Corestroke.Parent = Coreglow
	TweenService:Create(Coreglow, TweenInfo.new(Buildup, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		Size = UDim2.fromOffset(120, 120),
	}):Play()

	for Index = 1, ChargeRingCount do
		local Ring = Instance.new("Frame")
		Ring.Name = "ChargeRing"
		Ring.AnchorPoint = Vector2.new(0.5, 0.5)
		Ring.Position = UDim2.fromScale(0.5, 0.5)
		Ring.Size = UDim2.fromOffset(1100, 1100)
		Ring.BackgroundTransparency = 1
		Ring.Rotation = Index * 18
		Ring.ZIndex = 30
		Ring.Parent = Container
		local Corner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(1, 0)
		Corner.Parent = Ring
		local Stroke = Instance.new("UIStroke")
		Stroke.Color = Color
		Stroke.Thickness = 3
		Stroke.Transparency = 1
		Stroke.Parent = Ring
		Tint(Stroke, "Color")
		local Start = Buildup * (Index - 1) / ChargeRingCount
		task.delay(Start, function()
			if not Ring.Parent then return end
			local Travel = math.max(Buildup - Start, 0.12)
			TweenService:Create(Ring, TweenInfo.new(Travel, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.fromOffset(90, 90),
				Rotation = Ring.Rotation + 70,
			}):Play()
			TweenService:Create(Stroke, TweenInfo.new(Travel * 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 0.1,
			}):Play()
		end)
	end

	if self:IsMotionEnabled() then
		self:Tween("Fov", Camera, TweenInfo.new(Buildup, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			FieldOfView = Fovorigin - 9,
		})
	end

	task.spawn(function()
		local Elapsed = 0
		local Step = 0
		while Elapsed < Buildup - 0.05 do
			if not Container.Parent then return end
			Step += 1
			self:PlaySound("Progress", nil, math.min(0.8 + Step * 0.13, 2.4))
			local Wait = math.max(Buildup * 0.2 - Step * 0.022, 0.04)
			task.wait(Wait)
			Elapsed += Wait
		end
	end)

	task.delay(Buildup, function()
		if self:IsMotionEnabled() then
			self:Tween("Fov", Camera, TweenInfo.new(0.09, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				FieldOfView = Fovorigin + 9,
			}).Completed:Once(function()
				self:Tween("Fov", Camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					FieldOfView = Fovorigin,
				})
			end)
		end
		if not Container.Parent then return end
		TweenService:Create(Dim, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(Coreglow, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(2600, 2600),
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(Corestroke, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
		}):Play()

		for Index = 1, RayCount do
			local Ray = Instance.new("Frame")
			Ray.Name = "MutationRay"
			Ray.AnchorPoint = Vector2.new(0.5, 0.5)
			Ray.Position = UDim2.fromScale(0.5, 0.5)
			Ray.Size = UDim2.fromOffset(0, 12)
			Ray.BackgroundColor3 = Color
			Ray.BackgroundTransparency = 0.4
			Ray.BorderSizePixel = 0
			Ray.Rotation = Index * (180 / RayCount)
			Ray.ZIndex = 31
			Ray.Parent = Container
			Tint(Ray, "BackgroundColor3")
			TweenService:Create(Ray, TweenInfo.new(0.62, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(2800, 12),
				Rotation = Ray.Rotation + 24,
			}):Play()
			TweenService:Create(Ray, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5), {
				BackgroundTransparency = 1,
			}):Play()
		end

		local Titleframe = Instance.new("Frame")
		Titleframe.Name = "Title"
		Titleframe.AnchorPoint = Vector2.new(0.5, 0.5)
		Titleframe.Position = UDim2.fromScale(0.5, 0.5)
		Titleframe.Size = UDim2.fromOffset(780, 200)
		Titleframe.BackgroundTransparency = 1
		Titleframe.ZIndex = 32
		Titleframe.Parent = Container

		local Glow = Instance.new("TextLabel")
		Glow.Name = "Glow"
		Glow.AnchorPoint = Vector2.new(0.5, 0.5)
		Glow.Position = UDim2.fromScale(0.5, 0.4)
		Glow.Size = UDim2.fromScale(1.14, 0.78)
		Glow.BackgroundTransparency = 1
		Glow.Font = Enum.Font.GothamBlack
		Glow.Text = string.upper(Name)
		Glow.TextColor3 = Color
		Glow.TextScaled = true
		Glow.TextTransparency = 0.55
		Glow.ZIndex = 32
		Glow.Parent = Titleframe
		Tint(Glow, "TextColor3")

		local Label = Instance.new("TextLabel")
		Label.Name = "Label"
		Label.AnchorPoint = Vector2.new(0.5, 0.5)
		Label.Position = UDim2.fromScale(0.5, 0.4)
		Label.Size = UDim2.fromScale(1, 0.7)
		Label.BackgroundTransparency = 1
		Label.Font = Enum.Font.GothamBlack
		Label.Text = string.upper(Name)
		Label.TextColor3 = Color
		Label.TextScaled = true
		Label.TextStrokeColor3 = Color3.fromRGB(18, 14, 10)
		Label.TextStrokeTransparency = 0.1
		Label.ZIndex = 34
		Label.Parent = Titleframe
		Tint(Label, "TextColor3")

		Shine = Instance.new("UIGradient")
		Shine.Color = Shinesequence(Color)
		Shine.Offset = Vector2.new(-1.2, 0)
		Shine.Parent = Label

		local Subtitle = Instance.new("TextLabel")
		Subtitle.Name = "Subtitle"
		Subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
		Subtitle.Position = UDim2.fromScale(0.5, 0.88)
		Subtitle.Size = UDim2.fromScale(0.62, 0.24)
		Subtitle.BackgroundTransparency = 1
		Subtitle.Font = Enum.Font.GothamBold
		Subtitle.Text = "MUTATION FOUND"
		Subtitle.TextColor3 = Color
		Subtitle.TextScaled = true
		Subtitle.TextStrokeColor3 = Color3.fromRGB(18, 14, 10)
		Subtitle.TextStrokeTransparency = 0.3
		Subtitle.TextTransparency = 1
		Subtitle.ZIndex = 34
		Subtitle.Parent = Titleframe
		Tint(Subtitle, "TextColor3")

		local Scale = GetScale(Titleframe)
		Scale.Scale = if self:IsMotionEnabled() then 2.6 else 1
		TweenService:Create(Scale, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(Scale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.6), { Scale = 1.2 }):Play()
		TweenService:Create(Subtitle, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.18), {
			TextTransparency = 0,
		}):Play()
		TweenService:Create(Shine, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0.3), {
			Offset = Vector2.new(1.2, 0),
		}):Play()
		TweenService:Create(Glow, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 3, true, 0.1), {
			Size = UDim2.fromScale(1.3, 0.9),
		}):Play()
		local Fadeout = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.6)
		TweenService:Create(Label, Fadeout, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(Glow, Fadeout, { TextTransparency = 1 }):Play()
		TweenService:Create(Subtitle, Fadeout, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

		self:Flash(self.overlay, Color3.fromRGB(255, 255, 255))
		self:Shockwave(Color, 4)
		self:Burst(self.overlay, Color, 70)
		self:Shake(self.overlay)
		self:PlaySound("RestorationComplete", 0.2)
		task.delay(0.22, function()
			self:Burst(self.overlay, Color, 50)
		end)
	end)

	if Rainbow then
		local Connection
		Connection = RunService.Heartbeat:Connect(function()
			if not Container.Parent then
				Connection:Disconnect()
				return
			end
			local Current = Core:GetController("MutationController"):GetColor("Rainbow")
			for _, Entry in ipairs(Tinted) do
				if Entry[1].Parent then
					Entry[1][Entry[2]] = Current
				end
			end
			if Shine then
				Shine.Color = Shinesequence(Current)
			end
		end)
	end

	Debris:AddItem(Container, Buildup + 2.5)
end

function FeedbackController:DonationThanks(AmountText: string)
	if not self:IsDecorativeEnabled() then return end
	local Container = Instance.new("Frame")
	Container.Name = "DonationThanks"
	Container.AnchorPoint = Vector2.new(0.5, 0.5)
	Container.Position = UDim2.fromScale(0.5, 0.47)
	Container.Size = UDim2.fromOffset(740, 180)
	Container.BackgroundTransparency = 1
	Container.ZIndex = 30
	Container.Parent = self.overlay

	local Glow = Instance.new("TextLabel")
	Glow.Name = "Glow"
	Glow.AnchorPoint = Vector2.new(0.5, 0.5)
	Glow.Position = UDim2.fromScale(0.5, 0.38)
	Glow.Size = UDim2.fromScale(1.12, 0.74)
	Glow.BackgroundTransparency = 1
	Glow.Font = Enum.Font.GothamBlack
	Glow.Text = "THANK YOU!"
	Glow.TextColor3 = DonationColor
	Glow.TextScaled = true
	Glow.TextTransparency = 0.5
	Glow.ZIndex = 30
	Glow.Parent = Container

	local Label = Instance.new("TextLabel")
	Label.Name = "Label"
	Label.AnchorPoint = Vector2.new(0.5, 0.5)
	Label.Position = UDim2.fromScale(0.5, 0.38)
	Label.Size = UDim2.fromScale(1, 0.66)
	Label.BackgroundTransparency = 1
	Label.Font = Enum.Font.GothamBlack
	Label.Text = "THANK YOU!"
	Label.TextColor3 = Color3.fromRGB(255, 255, 255)
	Label.TextScaled = true
	Label.TextStrokeColor3 = Color3.fromRGB(16, 40, 22)
	Label.TextStrokeTransparency = 0.12
	Label.ZIndex = 32
	Label.Parent = Container

	local Shine = Instance.new("UIGradient")
	Shine.Color = Shinesequence(DonationColor)
	Shine.Offset = Vector2.new(-1.2, 0)
	Shine.Parent = Label

	local Subtitle = Instance.new("TextLabel")
	Subtitle.Name = "Subtitle"
	Subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	Subtitle.Position = UDim2.fromScale(0.5, 0.86)
	Subtitle.Size = UDim2.fromScale(0.7, 0.26)
	Subtitle.BackgroundTransparency = 1
	Subtitle.Font = Enum.Font.GothamBold
	Subtitle.Text = AmountText .. " DONATED"
	Subtitle.TextColor3 = DonationColor
	Subtitle.TextScaled = true
	Subtitle.TextStrokeColor3 = Color3.fromRGB(16, 40, 22)
	Subtitle.TextStrokeTransparency = 0.32
	Subtitle.ZIndex = 32
	Subtitle.Parent = Container

	local Scale = GetScale(Container)
	Scale.Scale = if self:IsMotionEnabled() then 0.2 else 1
	TweenService:Create(Scale, TweenInfo.new(0.44, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(Shine, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0.25), {
		Offset = Vector2.new(1.2, 0),
	}):Play()
	local Fadeout = TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.45)
	TweenService:Create(Container, Fadeout, { Position = UDim2.fromScale(0.5, 0.42) }):Play()
	TweenService:Create(Label, Fadeout, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	TweenService:Create(Glow, Fadeout, { TextTransparency = 1 }):Play()
	TweenService:Create(Subtitle, Fadeout, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

	self:Flash(self.overlay, DonationColor)
	self:Shockwave(DonationColor, 3)
	self:Burst(self.overlay, DonationColor, 64)
	self:FovPunch(4)
	self:PlaySound("RobuxDonation", 0.2)
	task.delay(0.2, function()
		self:Burst(self.overlay, Color3.fromRGB(255, 255, 255), 40)
	end)
	Debris:AddItem(Container, 2)
end

function FeedbackController:Purchase(Name: string, ImageId: string, Color: Color3)
	if not self:IsDecorativeEnabled() then return end
	local Container = Instance.new("Frame")
	Container.Name = "PurchaseFeedback"
	Container.AnchorPoint = Vector2.new(0.5, 0.5)
	Container.Position = UDim2.fromScale(0.5, 0.46)
	Container.Size = UDim2.fromOffset(210, 240)
	Container.BackgroundTransparency = 1
	Container.ZIndex = 28
	Container.Parent = self.overlay

	local Halo = Instance.new("Frame")
	Halo.Name = "Halo"
	Halo.AnchorPoint = Vector2.new(0.5, 0.5)
	Halo.Position = UDim2.fromScale(0.5, 0.4)
	Halo.Size = UDim2.fromOffset(150, 150)
	Halo.BackgroundColor3 = Color
	Halo.BackgroundTransparency = 0.7
	Halo.BorderSizePixel = 0
	Halo.ZIndex = 28
	Halo.Parent = Container
	local Halocorner = Instance.new("UICorner")
	Halocorner.CornerRadius = UDim.new(1, 0)
	Halocorner.Parent = Halo

	local Icon = Instance.new("ImageLabel")
	Icon.Name = "Icon"
	Icon.AnchorPoint = Vector2.new(0.5, 0.5)
	Icon.Position = UDim2.fromScale(0.5, 0.4)
	Icon.Size = UDim2.fromOffset(136, 136)
	Icon.BackgroundTransparency = 1
	Icon.Image = ImageId
	Icon.ScaleType = Enum.ScaleType.Fit
	Icon.ZIndex = 29
	Icon.Parent = Container

	local Label = Instance.new("TextLabel")
	Label.Name = "Label"
	Label.AnchorPoint = Vector2.new(0.5, 0.5)
	Label.Position = UDim2.fromScale(0.5, 0.85)
	Label.Size = UDim2.fromScale(1.6, 0.17)
	Label.BackgroundTransparency = 1
	Label.Font = Enum.Font.GothamBlack
	Label.Text = string.upper(Name)
	Label.TextColor3 = Color
	Label.TextScaled = true
	Label.TextStrokeColor3 = Color3.fromRGB(24, 18, 12)
	Label.TextStrokeTransparency = 0.25
	Label.ZIndex = 29
	Label.Parent = Container

	local Scale = GetScale(Container)
	Scale.Scale = if self:IsMotionEnabled() then 0.4 else 1
	TweenService:Create(Scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(Halo, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(240, 240),
		BackgroundTransparency = 1,
	}):Play()
	local Fadeout = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.75)
	TweenService:Create(Container, Fadeout, { Position = UDim2.fromScale(0.5, 0.4) }):Play()
	TweenService:Create(Icon, Fadeout, { ImageTransparency = 1 }):Play()
	TweenService:Create(Label, Fadeout, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

	self:Burst(self.overlay, Color, 26)
	self:FovPunch(2)
	self:PlaySound("CashGain", 0.15)
	Debris:AddItem(Container, 1.4)
end

function FeedbackController:Sale(Name: string, Value: number, Count: number?)
	local Amount = FormatCurrency(Value)
	local Text = if Count and Count > 1
		then string.format("%d ITEMS SOLD  +%s", Count, Amount)
		else string.format("%s SOLD  +%s", string.upper(Name), Amount)
	self:CenterText(Text, Color3.fromRGB(126, 255, 145), Count ~= nil and Count > 1)
end

function FeedbackController:PlaySound(Name: string, Cooldown: number?, Pitch: number?, Fadeinseconds: number?): Sound?
	local Template = self.sfxFolder:FindFirstChild(Name)
	if not Template or not Template:IsA("Sound") then return end
	local Now = os.clock()
	if Cooldown and self.soundCooldowns[Name] and Now - self.soundCooldowns[Name] < Cooldown then return end
	self.soundCooldowns[Name] = Now
	local Sound = Template:Clone()
	if Pitch then Sound.PlaybackSpeed = Pitch end
	local Target = Sound.Volume * self.soundVolume
	Sound.Volume = if Fadeinseconds then 0 else Target
	Sound.Parent = SoundService
	Sound:Play()
	if Fadeinseconds then
		TweenService:Create(Sound, TweenInfo.new(Fadeinseconds, Enum.EasingStyle.Linear), { Volume = Target }):Play()
	end
	local Length = if Sound.PlaybackSpeed > 0 then Sound.TimeLength / Sound.PlaybackSpeed else 0
	if Length > 0.3 then
		task.delay(Length - 0.2, function()
			if Sound.Parent then
				TweenService:Create(Sound, SoundFadeTween, { Volume = 0 }):Play()
			end
		end)
	end
	Sound.Ended:Once(function() Sound:Destroy() end)
	Debris:AddItem(Sound, 15)
	return Sound
end

function FeedbackController:SetLoop(Name: string, Playing: boolean, Fadeseconds: number?, Volumescale: number?)
	local Current = self.loopSounds[Name]
	if Playing then
		if Current then return end
		local Template = self.sfxFolder:FindFirstChild(Name)
		if not Template or not Template:IsA("Sound") then return end
		local Sound = Template:Clone()
		Sound.Looped = true
		local Target = Sound.Volume * self.soundVolume * (Volumescale or 1)
		Sound.Volume = if Fadeseconds then 0 else Target
		Sound.Parent = SoundService
		Sound:Play()
		if Fadeseconds then
			TweenService:Create(Sound, TweenInfo.new(Fadeseconds, Enum.EasingStyle.Linear), { Volume = Target }):Play()
		end
		self.loopSounds[Name] = Sound
	elseif Current then
		self.loopSounds[Name] = nil
		local Fadeout = if Fadeseconds
			then TweenInfo.new(Fadeseconds, Enum.EasingStyle.Linear)
			else SoundFadeTween
		TweenService:Create(Current, Fadeout, { Volume = 0 }):Play()
		Debris:AddItem(Current, (Fadeseconds or 0.2) + 0.05)
	end
end

function FeedbackController:FovPunch(Amount: number?)
	if not self:IsMotionEnabled() then return end
	local Camera = Workspace.CurrentCamera
	local Origin = Camera.FieldOfView
	self:Tween("Fov", Camera, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { FieldOfView = Origin + (Amount or 2) }).Completed:Once(function()
		self:Tween("Fov", Camera, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { FieldOfView = Origin })
	end)
end

function FeedbackController:Success(Target: GuiObject, Major: boolean?)
	self:Pulse(Target, if Major then 1.14 else 1.08)
	self:Flash(Target, SuccessColor)
	self:Burst(Target, SuccessColor, if Major then 45 else 18)
	self:PlaySound(if Major then "RestorationComplete" else "UISuccess", 0.15)
	if Major then self:FovPunch(2.5) end
end

function FeedbackController:Error(Target: GuiObject)
	self:Shake(Target)
	self:Flash(Target, ErrorColor)
	self:PlaySound("UIError", 0.3)
end

function FeedbackController:UiClick()
	self:PlaySound("UiClick", UiClickCooldown)
end

function FeedbackController:Confirm()
	self:PlaySound("Confirm", ConfirmCooldown)
end

function FeedbackController:FadeMusicIn(Info: TweenInfo)
	if self.musicTween then
		self.musicTween:Cancel()
	end
	self.music.Volume = 0
	if self.musicMuted then
		self.musicTween = nil
		return
	end
	self.musicTween = TweenService:Create(self.music, Info, { Volume = self.musicVolume })
	self.musicTween:Play()
end

function FeedbackController:SetMusicMuted(Muted: boolean)
	self.musicMuted = Muted
	if not self.music then return end
	if self.musicTween then
		self.musicTween:Cancel()
		self.musicTween = nil
	end
	self.music.Volume = if Muted then 0 else self.musicVolume
end

function FeedbackController:SetMusicVolume(Alpha: number)
	self.musicVolume = math.clamp(Alpha, 0, 1) * MaxMusicVolume
	if not self.music then return end
	if self.musicTween then
		self.musicTween:Cancel()
		self.musicTween = nil
	end
	self.music.Volume = if self.musicMuted then 0 else self.musicVolume
end

function FeedbackController:SetSoundVolume(Alpha: number)
	self.soundVolume = math.clamp(Alpha, 0, 1)
end

function FeedbackController:StartMusic()
	local Template = self.sfxFolder:FindFirstChild("Music")
	if not Template or not Template:IsA("Sound") then return end
	local Music = Template:Clone()
	Music.Looped = true
	Music.Volume = 0
	Music.Parent = SoundService
	Music:Play()
	self.music = Music
	self:FadeMusicIn(MusicFadeTween)
	Music.DidLoop:Connect(function()
		self:FadeMusicIn(MusicLoopFadeTween)
	end)
end

function FeedbackController:BindClicksIn(Root: Instance)
	local function Bind(Target: Instance)
		if not Target:IsA("GuiButton") then return end
		Target.Activated:Connect(function()
			if Target:GetAttribute("SilentClick") == true then return end
			self:UiClick()
		end)
	end
	for _, Descendant in ipairs(Root:GetDescendants()) do
		Bind(Descendant)
	end
	Root.DescendantAdded:Connect(Bind)
end

function FeedbackController:Start()
	self:BindClicksIn(Players.LocalPlayer:WaitForChild("PlayerGui"))
	self:StartMusic()
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(_UserId, _ProductId, WasPurchased)
		if WasPurchased then self:Confirm() end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_Player, _GamePassId, WasPurchased)
		if WasPurchased then self:Confirm() end
	end)
end

function FeedbackController:Init()
	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.sfxFolder = ReplicatedStorage:WaitForChild("Asset"):WaitForChild("Sfx")
	self.soundCooldowns = {}
	self.loopSounds = {}
	self.soundVolume = 1
	self.musicVolume = MaxMusicVolume * 0.5
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "FeedbackUi"
	self.gui.DisplayOrder = 1000
	self.gui.IgnoreGuiInset = true
	self.gui.ResetOnSpawn = false
	self.gui.Parent = PlayerGui
	self.overlay = Instance.new("Frame")
	self.overlay.Name = "Overlay"
	self.overlay.Size = UDim2.fromScale(1, 1)
	self.overlay.BackgroundTransparency = 1
	self.overlay.Parent = self.gui
	local Preference = Players.LocalPlayer:GetAttribute("EffectsIntensity")
	if Preference == "Full" or Preference == "Reduced" or Preference == "Off" then self.intensity = Preference end
	Players.LocalPlayer:GetAttributeChangedSignal("EffectsIntensity"):Connect(function()
		local Value = Players.LocalPlayer:GetAttribute("EffectsIntensity")
		if Value == "Full" or Value == "Reduced" or Value == "Off" then self:SetIntensity(Value) end
	end)
end

return FeedbackController
