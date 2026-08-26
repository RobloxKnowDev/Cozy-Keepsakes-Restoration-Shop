local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Tweenservice = game:GetService("TweenService")
local Userinputservice = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Rarityconfig = require(Replicatedstorage.Shared.Config.Rarity)

type RestorationObject = Model | BasePart

local Completioncontroller = {
	Name = "CompletionController",
	Priority = 8,
	displayObject = nil,
	basePivot = CFrame.identity,
	dragging = false,
	dragStart = 0,
	dragOffset = 0,
	rotation = 0,
	celebrationId = 0,
	closing = false,
}

local Completionkinds = { "Dirt", "Sticker", "Ink", "Scratch" }
local Rownames = {
	Dirt = "DirtFrame",
	Sticker = "StickersFrame",
	Ink = "InkFrame",
	Scratch = "ScratchesFrame",
}

local function Pivotof(Object: RestorationObject): CFrame
	return Object:IsA("Model") and Object:GetPivot() or Object.CFrame
end

local function Boundsof(Object: RestorationObject): (CFrame, Vector3)
	if Object:IsA("Model") then
		return Object:GetBoundingBox()
	end
	return Object.CFrame, Object.Size
end

local function Pivotto(Object: RestorationObject, Cframe: CFrame)
	if Object:IsA("Model") then
		Object:PivotTo(Cframe)
	else
		Object.CFrame = Cframe
	end
end

function Completioncontroller:EnsurePreviewObjects()
	if not self.viewport then
		return
	end

	local World = self.viewport:FindFirstChild("WorldModel")
	if not World or not World:IsA("WorldModel") then
		World = Instance.new("WorldModel")
		World.Name = "WorldModel"
		World.Parent = self.viewport
	end
	self.world = World

	local Camera = self.viewport:FindFirstChild("Camera")
	if not Camera or not Camera:IsA("Camera") then
		Camera = Instance.new("Camera")
		Camera.Name = "Camera"
		Camera.FieldOfView = 38
		Camera.Parent = self.viewport
	end
	self.previewCamera = Camera
	self.viewport.CurrentCamera = Camera
end

function Completioncontroller:Init()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = Playergui:WaitForChild("CompleteUi") :: ScreenGui
	self.frame = self.gui:WaitForChild("CompleteFrame") :: GuiObject
	self.preview = self.frame:WaitForChild("ObjectPreview")
	self.viewport = if self.preview:IsA("ViewportFrame") then self.preview else nil
	self.nextButton = self.frame:WaitForChild("NextButton") :: GuiButton
	self.objectNameText = self.frame:WaitForChild("ObjectName")
	self.rarityFrame = self.frame:WaitForChild("RarityFrame") :: GuiObject
	self.rarityText = self.rarityFrame:WaitForChild("Rarity")
	self.totalProgressText = self.frame:WaitForChild("TotalProgress")
	self.valueText = self.frame:WaitForChild("Value")
	self.reputationText = self.frame:WaitForChild("ReputationText")
	self.maxValueText = self.frame:WaitForChild("MaxValue")
	self.frameShownPosition = self.frame.Position
	self.transition = self.gui:FindFirstChild("CompletionTransition")
	if not self.transition then
		local Transition = Instance.new("Frame")
		Transition.Name = "CompletionTransition"
		Transition.AnchorPoint = Vector2.new(0.5, 0.5)
		Transition.Position = UDim2.fromScale(0.5, 0.5)
		Transition.BackgroundColor3 = Color3.fromRGB(37, 37, 37)
		Transition.BorderSizePixel = 0
		Transition.Size = UDim2.fromOffset(0, 0)
		Transition.ZIndex = 500
		Transition.Visible = false
		Transition.Parent = self.gui
		local Corner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(0, 0)
		Corner.Parent = Transition
		self.transition = Transition
	end

	self:EnsurePreviewObjects()
end

local function Formatcurrency(Value: number): string
	if math.abs(Value - math.round(Value)) < 0.005 then
		return string.format("$%d", math.round(Value))
	end

	return string.format("$%.2f", Value)
end

local function Formatreputation(Value: number): string
	local Rounded = math.round(Value * 100) / 100
	if math.abs(Rounded - math.round(Rounded)) < 0.005 then return tostring(math.round(Rounded)) end
	return string.format("%.2f", Rounded)
end

local function Ratiofromattributes(Object: RestorationObject, Kind: string): number
	local Total = Object:GetAttribute("Total_" .. Kind) or 0
	local Cleaned = Object:GetAttribute("Cleaned_" .. Kind) or 0
	return Total > 0 and math.clamp(Cleaned / Total, 0, 1) or 0
end

local function Progressfromattributes(Object: RestorationObject): number
	local Totalspots = Object:GetAttribute("TotalSpots") or 0
	local Cleanedspots = Object:GetAttribute("CleanedSpots") or 0
	return Totalspots > 0 and math.clamp(Cleanedspots / Totalspots, 0, 1) or 0
end

function Completioncontroller:ApplyProgressStats(Object: RestorationObject)
	local Progressframe = self.frame:WaitForChild("ProgressFrame")
	local Overallratio = Progressfromattributes(Object)
	local Maxvalue = tonumber(Object:GetAttribute("MaxValue")) or tonumber(Object:GetAttribute("MaxPrice")) or 0
	local Currentvalue = Maxvalue * Overallratio
	local Reputation = (tonumber(Object:GetAttribute("MaxReputation")) or 0) * Overallratio
	local Rarity = Rarityconfig[tostring(Object:GetAttribute("Rarity") or "Common")]

	self.objectNameText.Text = tostring(Object:GetAttribute("DisplayName") or Object.Name)
	self.rarityText.Text = Rarity.Name
	self.rarityFrame.BackgroundColor3 = Rarity.Color
	self.totalProgressText.Text = string.format("%d%%", math.floor(Overallratio * 100 + 0.5))
	self.valueText.Text = Formatcurrency(Currentvalue)
	self.reputationText.Text = Formatreputation(Reputation)
	self.maxValueText.Text = Formatcurrency(Maxvalue)

	for _, Kind in ipairs(Completionkinds) do
		local Row = Progressframe:WaitForChild(Rownames[Kind])
		local Ratio = Ratiofromattributes(Object, Kind)
		Row:WaitForChild("PercentText").Text = string.format("%d%%", math.floor(Ratio * 100 + 0.5))
		Row:WaitForChild("FrameBar"):WaitForChild("Bar").Size = UDim2.fromScale(Ratio, 1)
	end
end

function Completioncontroller:IsVisible(): boolean
	return self.frame.Visible or self.transition.Visible
end

function Completioncontroller:Hide()
	self.celebrationId += 1
	self.frame.Visible = false
	self.dragging = false
	self.closing = false
	self.onContinue = nil
	self.frame.Position = self.frameShownPosition
	self.transition.Visible = false
	self.transition.Size = UDim2.new(1, 0, 1, 0)
	self.transition.BackgroundTransparency = 1
	for _, Child in self.frame:GetChildren() do
		if Child.Name == "Confetti" then
			Child:Destroy()
		end
	end

	if self.viewportSizeConnection then
		self.viewportSizeConnection:Disconnect()
		self.viewportSizeConnection = nil
	end
	if self.objectArrivalTween then
		self.objectArrivalTween:Cancel()
		self.objectArrivalTween = nil
	end
	if self.displayObject then
		self.displayObject:Destroy()
		self.displayObject = nil
	end
end

function Completioncontroller:PlayAppearanceAnimation()
	local Scale = self.frame:FindFirstChildOfClass("UIScale")
	if not Scale then
		Scale = Instance.new("UIScale")
		Scale.Parent = self.frame
	end
	Scale.Scale = 1
	self.frame.Position = self.frameShownPosition
	self.transition.Visible = true
	self.transition.BackgroundTransparency = 1
	self.transition.Size = UDim2.new(1, 0, 1, 0)
	local Transitionin = Tweenservice:Create(
		self.transition,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0 }
	)
	Transitionin:Play()
	Transitionin.Completed:Once(function()
		self.frame.Visible = true
		self:AnimateObjectArrival()
		self:StartConfetti()
		self:PlayProgressAnimation()
		task.delay(0.1, function()
			if not self.frame.Visible or self.closing then
				return
			end
			local Transitionout = Tweenservice:Create(
				self.transition,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ BackgroundTransparency = 1 }
			)
			Transitionout:Play()
			Transitionout.Completed:Once(function()
				self.transition.Visible = false
			end)
		end)
	end)

	local Buttonscale = self.nextButton:FindFirstChildOfClass("UIScale")
	if not Buttonscale then
		Buttonscale = Instance.new("UIScale")
		Buttonscale.Parent = self.nextButton
	end
	Buttonscale.Scale = 0
	self.nextButton.Visible = false
	self.rotation = math.rad(-18)
end

function Completioncontroller:StartConfetti()
	local Celebrationid = self.celebrationId
	local Colors = {
		Color3.fromRGB(255, 145, 0),
		Color3.fromRGB(255, 180, 0),
		Color3.fromRGB(255, 215, 38),
		Color3.fromRGB(255, 242, 112),
		Color3.fromRGB(255, 253, 221),
	}

	task.spawn(function()
		while self.celebrationId == Celebrationid and self.frame.Visible and not self.closing do
			for _ = 1, math.random(2, 4) do
				local Confetti = Instance.new("Frame")
				Confetti.Name = "Confetti"
				Confetti.AnchorPoint = Vector2.new(0.5, 0.5)
				Confetti.BorderSizePixel = 0
				Confetti.BackgroundColor3 = Colors[math.random(1, #Colors)]
				Confetti.Position = UDim2.fromScale(math.random(3, 97) / 100, -0.04)
				local Shape = math.random(1, 10)
				if Shape <= 3 then
					Confetti.Size = UDim2.fromOffset(math.random(10, 18), math.random(20, 38))
				elseif Shape <= 7 then
					Confetti.Size = UDim2.fromOffset(math.random(5, 10), math.random(7, 15))
				else
					Confetti.Size = UDim2.fromOffset(math.random(3, 6), math.random(28, 52))
				end
				Confetti.Rotation = math.random(0, 359)
				Confetti.ZIndex = 100
				Confetti.Parent = self.frame

				local Target = UDim2.fromScale(
					math.clamp(Confetti.Position.X.Scale + (math.random() - 0.5) * 0.24, -0.05, 1.05),
					1.08
				)
				local Tween = Tweenservice:Create(
					Confetti,
					TweenInfo.new(math.random(22, 38) / 10, Enum.EasingStyle.Linear),
					{ Position = Target, Rotation = Confetti.Rotation + math.random(400, 900) }
				)
				Tween:Play()
				Tween.Completed:Once(function()
					Confetti:Destroy()
				end)
			end
			task.wait(0.11)
		end
	end)
end

function Completioncontroller:PlayProgressAnimation()
	local Progressframe = self.frame:WaitForChild("ProgressFrame")
	if not Progressframe then
		return
	end

	local Rows = {}
	for _, Child in Progressframe:GetChildren() do
		if Child:IsA("Frame") then
			table.insert(Rows, Child)
		end
	end
	table.sort(Rows, function(A, B)
		if A.AbsolutePosition.Y == B.AbsolutePosition.Y then
			if A.LayoutOrder ~= B.LayoutOrder then
				return A.LayoutOrder < B.LayoutOrder
			end
			return A.Name < B.Name
		end
		return A.AbsolutePosition.Y < B.AbsolutePosition.Y
	end)

	local Celebrationid = self.celebrationId
	for _, Row in Rows do
		local Rowscale = Row:FindFirstChildOfClass("UIScale")
		if not Rowscale then
			Rowscale = Instance.new("UIScale")
			Rowscale.Parent = Row
		end
		Row.Visible = false
		Rowscale.Scale = 0.72
	end

	local Startdelay = 0.55
	local Rowdelay = 0.48
	for Index, Row in Rows do
		task.delay(Startdelay + (Index - 1) * Rowdelay, function()
			if self.celebrationId ~= Celebrationid or not self.frame.Visible or self.closing then
				return
			end
			Row.Visible = true
			local Rowscale = Row:FindFirstChildOfClass("UIScale")
			if Rowscale then
				Tweenservice
					:Create(
						Rowscale,
						TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ Scale = 1 }
					)
					:Play()
			end
		end)
	end

	local Buttondelay = Startdelay + math.max(#Rows - 1, 0) * Rowdelay + 0.42
	task.delay(Buttondelay, function()
		if self.celebrationId ~= Celebrationid or not self.frame.Visible or self.closing then
			return
		end
		self.nextButton.Visible = true
		local Buttonscale = self.nextButton:FindFirstChildOfClass("UIScale")
		if Buttonscale then
			Tweenservice
				:Create(
					Buttonscale,
					TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Scale = 1 }
				)
				:Play()
		end
	end)
end

function Completioncontroller:PlayExitAnimation(Onfinished: () -> ())
	if self.closing then
		return
	end
	self.closing = true
	self.dragging = false

	for _, Child in self.frame:GetChildren() do
		if Child.Name == "Confetti" and Child:IsA("GuiObject") then
			Tweenservice:Create(Child, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
				Position = Child.Position + UDim2.fromOffset(0, 70),
			}):Play()
		end
	end
	self.transition.Visible = true
	self.transition.BackgroundTransparency = 1
	self.transition.Size = UDim2.new(1, 0, 1, 0)
	local Transitionin = Tweenservice:Create(
		self.transition,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0 }
	)
	Transitionin:Play()
	Transitionin.Completed:Once(function()
		self.frame.Visible = false
		task.delay(0.1, function()
			local Transitionout = Tweenservice:Create(
				self.transition,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ BackgroundTransparency = 1 }
			)
			Transitionout:Play()
			Transitionout.Completed:Once(Onfinished)
		end)
	end)
end

function Completioncontroller:FrameObject()
	if not self.viewport then
		return
	end

	local Clone = self.displayObject
	if not Clone or not Clone.Parent then
		return
	end

	local Bounds, Size = Boundsof(Clone)
	local Aspect = math.max(self.viewport.AbsoluteSize.X / math.max(self.viewport.AbsoluteSize.Y, 1), 0.1)
	local Verticalfov = math.rad(self.previewCamera.FieldOfView * 0.5)
	local Horizontalfov = math.atan(math.tan(Verticalfov) * Aspect)
	local Distance = (
		math.max(Size.Y * 0.5 / math.tan(Verticalfov), Size.X * 0.5 / math.tan(Horizontalfov)) + Size.Z * 0.5
	) * 1.12
	self.objectCenter = Bounds.Position
	self.previewCameraTarget = CFrame.lookAt(Bounds.Position + Vector3.new(0, 0, Distance), Bounds.Position)
	if not self.objectArrivalTween then
		self.previewCamera.CFrame = self.previewCameraTarget
	end
end

function Completioncontroller:AnimateObjectArrival()
	if not self.viewport then
		return
	end

	if not self.previewCameraTarget or not self.objectCenter then
		return
	end
	if self.objectArrivalTween then
		self.objectArrivalTween:Cancel()
	end
	local Offset = self.previewCameraTarget.Position - self.objectCenter
	self.previewCamera.CFrame = CFrame.lookAt(self.objectCenter + Offset * 4.5, self.objectCenter)
	self.objectArrivalTween = Tweenservice:Create(
		self.previewCamera,
		TweenInfo.new(1.65, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ CFrame = self.previewCameraTarget }
	)
	self.objectArrivalTween:Play()
	self.objectArrivalTween.Completed:Once(function()
		self.objectArrivalTween = nil
	end)
end

function Completioncontroller:Show(Object: RestorationObject, Oncontinue: () -> ())
	self:Hide()
	self:EnsurePreviewObjects()
	self.closing = false
	self.onContinue = Oncontinue
	self:ApplyProgressStats(Object)

	if self.viewport and self.world then
		Object.Archivable = true
		local Clone = Object:Clone()
		for _, Item in Clone:GetDescendants() do
			if Item:IsA("BasePart") then
				Item.Anchored = true
				Item.CanCollide = false
				Item.CanQuery = false
				Item.CanTouch = false
			end
		end
		if Clone:IsA("BasePart") then
			Clone.Anchored = true
			Clone.CanCollide = false
			Clone.CanQuery = false
			Clone.CanTouch = false
		end

		Pivotto(Clone, CFrame.Angles(math.rad(90), math.rad(-90), math.rad(90)))
		Clone.Parent = self.world
		self.displayObject = Clone
		self.basePivot = Pivotof(Clone)
		self.rotation = 0
	else
		self.displayObject = nil
	end

	self.gui.Enabled = true
	self.frame.Visible = false
	if self.viewport then
		self:FrameObject()
	end
	self:PlayAppearanceAnimation()
	if self.viewport then
		self.viewportSizeConnection = self.viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:FrameObject()
		end)
	end
end

function Completioncontroller:InputBegan(Input: InputObject): boolean
	if
		not self:IsVisible()
		or not self.viewport
		or (
			Input.UserInputType ~= Enum.UserInputType.MouseButton1
			and Input.UserInputType ~= Enum.UserInputType.MouseButton2
		)
	then
		return false
	end
	local Position = Vector2.new(Input.Position.X, Input.Position.Y)
	local Minimum = self.viewport.AbsolutePosition
	local Maximum = Minimum + self.viewport.AbsoluteSize
	if Position.X < Minimum.X or Position.Y < Minimum.Y or Position.X > Maximum.X or Position.Y > Maximum.Y then
		return false
	end
	self.dragging = true
	self.dragStart = Input.Position.X
	self.dragOffset = self.rotation
	return true
end

function Completioncontroller:InputChanged(Input: InputObject)
	if not self.dragging or Input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local Width = math.max(Workspace.CurrentCamera.ViewportSize.X, 1)
	self.rotation = math.clamp(
		self.dragOffset - (Input.Position.X - self.dragStart) / Width * math.rad(240),
		math.rad(-75),
		math.rad(75)
	)
end

function Completioncontroller:InputEnded(Input: InputObject)
	if
		Input.UserInputType == Enum.UserInputType.MouseButton1
		or Input.UserInputType == Enum.UserInputType.MouseButton2
	then
		self.dragging = false
	end
end

function Completioncontroller:Update(Deltatime: number)
	if not self:IsVisible() then
		return
	end
	if not self.dragging then
		self.rotation *= math.exp(-9 * Deltatime)
		if math.abs(self.rotation) < 0.002 then
			self.rotation = 0
		end
	end
	if self.displayObject then
		Pivotto(self.displayObject, self.basePivot * CFrame.Angles(0, self.rotation, 0))
	end
end

function Completioncontroller:Start()
	self.nextButton.Activated:Connect(function()
		local Oncontinue = self.onContinue
		if Oncontinue and not self.closing then
			self:PlayExitAnimation(Oncontinue)
		end
	end)
	local Buttonscale = self.nextButton:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	Buttonscale.Parent = self.nextButton
	self.nextButton.MouseEnter:Connect(function()
		if not self.closing then
			Tweenservice:Create(Buttonscale, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Scale = 1.08 }):Play()
		end
	end)
	self.nextButton.MouseLeave:Connect(function()
		if not self.closing then
			Tweenservice:Create(Buttonscale, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
		end
	end)
	self.nextButton.MouseButton1Down:Connect(function()
		if not self.closing then
			Tweenservice:Create(Buttonscale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = 0.94 }):Play()
		end
	end)
	self.nextButton.MouseButton1Up:Connect(function()
		if not self.closing then
			Tweenservice:Create(Buttonscale, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Scale = 1.08 }):Play()
		end
	end)
	Userinputservice.InputBegan:Connect(function(Input)
		self:InputBegan(Input)
	end)
	Userinputservice.InputChanged:Connect(function(Input)
		self:InputChanged(Input)
	end)
	Userinputservice.InputEnded:Connect(function(Input)
		self:InputEnded(Input)
	end)
	Runservice.RenderStepped:Connect(function(Deltatime)
		self:Update(Deltatime)
	end)
end

return Completioncontroller
