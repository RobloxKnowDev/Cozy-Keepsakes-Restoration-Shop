local Players = game:GetService("Players")
local Runservice = game:GetService("RunService")
local Guiservice = game:GetService("GuiService")
local Tweenservice = game:GetService("TweenService")
local Userinputservice = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Controller = { Name = "InspectionCameraController", Priority = 5 }

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
type InspectionTarget = Model | BasePart
local Target: InspectionTarget? = nil
local Yaw = 0
local Pitch = math.rad(-38)
local Distance = 8
local Targetdistance = 8
local Mindistance = 4
local Maxdistance = 16
local Dragging = false
local Enabled = false
local Transformmode = "Rotate"
local Dragmode = "RotateObject"
local Draginput: InputObject? = nil
local Lastpointer = Vector2.zero
local Dragaccumulator = Vector2.zero
local Lockedrotationaxis: string? = nil
local Focusoffset = Vector3.zero
local Panlimit = 3
local Objectstartposition = Vector3.zero
local Objectselected = false
local Groundy = 0
local Safecameradistance = 8
local Objectrotationgoal: CFrame? = nil
local Originalobjectrotation = CFrame.identity
local Showingback = false
local Selectioncallback: ((boolean) -> ())? = nil
local Previouscameratype = Enum.CameraType.Custom
local Previouscamerasubject = Camera.CameraSubject
local Completionview = false
local Introcameraactive = false
local Introcameratween: Tween? = nil
local Cameratransitionactive = false
local Cameratransitionelapsed = 0
local Cameratransitionduration = 2
local Cameratransitionstart = CFrame.identity
local Cameratransitionlooktarget = Vector3.zero

local function Pointerposition(Input: InputObject): Vector2
	return Vector2.new(Input.Position.X, Input.Position.Y)
end

local function Viewportposition(Screenposition: Vector2): Vector2
	local Inset = Guiservice:GetGuiInset()
	return Screenposition - Inset
end

local function Raycasttarget(Screenposition: Vector2): RaycastResult?
	if not Target then
		return nil
	end

	local Viewport = Viewportposition(Screenposition)
	local Ray = Camera:ViewportPointToRay(Viewport.X, Viewport.Y)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Target }
	return Workspace:Raycast(Ray.Origin, Ray.Direction * 500, Params)
end

local function Ispointerontarget(Screenposition: Vector2): boolean
	local Result = Raycasttarget(Screenposition)
	return Result ~= nil
end

local function Begindrag(Input: InputObject, Mode: string)
	Dragging = true
	Dragmode = Mode
	Draginput = Input
	Lastpointer = Pointerposition(Input)
	Dragaccumulator = Vector2.zero
	Lockedrotationaxis = nil
end

local function Enddrag()
	Dragging = false
	Draginput = nil
	Userinputservice.MouseBehavior = Enum.MouseBehavior.Default
end

local function Setobjectselected(Value: boolean)
	Objectselected = Value
	if Selectioncallback then
		Selectioncallback(Value)
	end
end

local function Objectpivot(Object: InspectionTarget): CFrame
	return Object:IsA("Model") and Object:GetPivot() or Object.CFrame
end

local function Objectsize(Object: InspectionTarget): Vector3
	return Object:IsA("Model") and select(2, Object:GetBoundingBox()) or Object.Size
end

local function Pivotobject(Object: InspectionTarget, Pivot: CFrame)
	if Object:IsA("Model") then Object:PivotTo(Pivot) else Object.CFrame = Pivot end
end

local function Verticalhalfextent(Object: InspectionTarget): number
	if Object:IsA("Model") then
		local _, Boundssize = Object:GetBoundingBox()
		return Boundssize.Y * 0.5
	end
	local Halfsize = Object.Size * 0.5
	local Rotation = Object.CFrame.Rotation
	return math.abs(Rotation.RightVector.Y) * Halfsize.X
		+ math.abs(Rotation.UpVector.Y) * Halfsize.Y
		+ math.abs(Rotation.LookVector.Y) * Halfsize.Z
end

local function Bottomoffsetfrompivot(Object: InspectionTarget): number
	local Pivoty = Objectpivot(Object).Position.Y
	if Object:IsA("Model") then
		local Bottomy = math.huge
		local Spots = Object:FindFirstChild("RestorationSpots")
		for _, Descendant in ipairs(Object:GetDescendants()) do
			if Descendant:IsA("BasePart") and (not Spots or not Descendant:IsDescendantOf(Spots)) then
				local Halfsize = Descendant.Size * 0.5
				local Rotation = Descendant.CFrame.Rotation
				local Halfheight = math.abs(Rotation.RightVector.Y) * Halfsize.X
					+ math.abs(Rotation.UpVector.Y) * Halfsize.Y
					+ math.abs(Rotation.LookVector.Y) * Halfsize.Z
				Bottomy = math.min(Bottomy, Descendant.Position.Y - Halfheight)
			end
		end
		if Bottomy == math.huge then return Verticalhalfextent(Object) end
		return Pivoty - Bottomy
	end
	return Verticalhalfextent(Object)
end

local function Findgroundy(Object: InspectionTarget): number
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Object, Player.Character }
	Params.IgnoreWater = true
	local Origin = Objectpivot(Object).Position
	local Result = Workspace:Raycast(Origin, Vector3.new(0, -500, 0), Params)
	local Currentbottom = Origin.Y - Bottomoffsetfrompivot(Object)
	return Result and Result.Position.Y or Currentbottom
end

function Controller:FlipObject()
	if not Target then
		return
	end
	Showingback = not Showingback
	Objectrotationgoal = Originalobjectrotation
		* (Showingback and CFrame.Angles(math.pi, 0, 0) or CFrame.identity)
end

function Controller:IsDragging(): boolean
	return Dragging
end

function Controller:IsIntroCameraReady(): boolean
	local Campart = Workspace:WaitForChild("CamPart")
	return Introcameraactive
		and Introcameratween == nil
		and Campart ~= nil
		and Campart:IsA("BasePart")
		and (Camera.CFrame.Position - Campart.Position).Magnitude < 0.05
end

function Controller:SetEnabled(Value: boolean)
	Enabled = Value
	if not Enabled then
		Enddrag()
		Setobjectselected(false)
	end
end

function Controller:SetTransformMode(Mode: string)
	if Mode ~= "Rotate" and Mode ~= "Locked" then
		return
	end
	Transformmode = Mode
	Enddrag()
end

function Controller:SetSelectionCallback(Callback: (boolean) -> ())
	Selectioncallback = Callback
end

function Controller:SelectObject()
	if Target then
		Setobjectselected(true)
	end
end

local function CancelIntroCameraTween()
	local Tween = Introcameratween
	if not Tween then return end
	Introcameratween = nil
	Tween:Cancel()
	Tween:Destroy()
end

local function ShowCameraPart(CameraPart: BasePart): boolean
	if Target then return false end
	if not Introcameraactive then
		Previouscameratype = Camera.CameraType
		Previouscamerasubject = Camera.CameraSubject
	end

	Introcameraactive = true
	Camera.CameraType = Enum.CameraType.Scriptable
	CancelIntroCameraTween()

	local Newtween = Tweenservice:Create(
		Camera,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CameraPart.CFrame }
	)
	Introcameratween = Newtween
	Newtween:Play()
	Newtween.Completed:Once(function()
		if Introcameratween == Newtween then
			Newtween:Destroy()
			Introcameratween = nil
		end
	end)
	return true
end

function Controller:ShowIntroCamera(): boolean
	return ShowCameraPart(Workspace:WaitForChild("CamPart") :: BasePart)
end

function Controller:ShowExpositionCamera(): boolean
	return ShowCameraPart(Workspace:WaitForChild("CamPartExposition") :: BasePart)
end

function Controller:ShowComputerCamera(): boolean
	return ShowCameraPart(Workspace:WaitForChild("CamPartComputer") :: BasePart)
end

function Controller:Begin(Object: InspectionTarget)
	local Shouldtransition = Introcameraactive
	CancelIntroCameraTween()
	Target = Object
	Objectselected = false
	Focusoffset = Vector3.zero
	Objectstartposition = Objectpivot(Object).Position
	Originalobjectrotation = Objectpivot(Object).Rotation
	Showingback = false
	Objectrotationgoal = nil
	Completionview = false
	Groundy = Object:GetAttribute("SpawnFloorY") or Findgroundy(Object)
	Yaw = math.pi
	Pitch = math.rad(-38)

	local Radius = math.max(Objectsize(Object).Magnitude * 0.5, 1)
	Panlimit = math.max(Radius * 0.65, 1)
	Mindistance = math.max(Radius * 0.85, 2.5)
	Maxdistance = math.max(Radius * 3.2, Mindistance + 1)
	Targetdistance = math.clamp(Radius * 1.65, Mindistance, Maxdistance)
	Distance = Targetdistance
	Safecameradistance = Distance

	if not Introcameraactive then
		Previouscameratype = Camera.CameraType
		Previouscamerasubject = Camera.CameraSubject
	end
	Cameratransitionactive = Shouldtransition
	Cameratransitionelapsed = 0
	Cameratransitionstart = Camera.CFrame
	Cameratransitionlooktarget = Camera.CFrame.Position + Camera.CFrame.LookVector * 10
	Introcameraactive = false
	Camera.CameraType = Enum.CameraType.Scriptable
end

function Controller:PrepareCompletion()
	if not Target then return end
	Enabled = false
	Completionview = true
	Enddrag()
	Setobjectselected(false)
	Focusoffset = Vector3.zero
end

function Controller:End()
	Enabled = false
	Completionview = false
	Introcameraactive = false
	Cameratransitionactive = false
	CancelIntroCameraTween()
	Enddrag()
	Setobjectselected(false)
	Target = nil
	Camera.CameraType = Previouscameratype
	if Previouscamerasubject and Previouscamerasubject.Parent then
		Camera.CameraSubject = Previouscamerasubject
	end
end

function Controller:Start()
	Userinputservice.InputBegan:Connect(function(Input, Processed)
		if Processed or not Target or Completionview or Cameratransitionactive then
			return
		end

		local Isprimary = Input.UserInputType == Enum.UserInputType.MouseButton1
		local Issecondary = Input.UserInputType == Enum.UserInputType.MouseButton2
		local Ismiddle = Input.UserInputType == Enum.UserInputType.MouseButton3
		local Istouch = Input.UserInputType == Enum.UserInputType.Touch
		local Position = Pointerposition(Input)
		local Shiftdown = Userinputservice:IsKeyDown(Enum.KeyCode.LeftShift)
			or Userinputservice:IsKeyDown(Enum.KeyCode.RightShift)

		if Enabled and (Isprimary or Istouch) and Ispointerontarget(Position) then
			Setobjectselected(true)
		elseif Enabled and (Isprimary or Istouch) then
			Setobjectselected(false)
		elseif Ismiddle or (Issecondary and Shiftdown) then
			Begindrag(Input, "Move")
			Userinputservice.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif Issecondary and Enabled and Objectselected and Transformmode == "Rotate" then
			Begindrag(Input, "RotateObject")
			Userinputservice.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif Issecondary then
			Begindrag(Input, "OrbitCamera")
			Userinputservice.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		end
	end)

	Userinputservice.InputChanged:Connect(function(Input)
		if not Target or Completionview or Cameratransitionactive then
			return
		end

		if Input.UserInputType == Enum.UserInputType.MouseWheel then
			local Mouse = Viewportposition(Userinputservice:GetMouseLocation())
			local Focus = Objectpivot(Target).Position + Focusoffset
			local Ray = Camera:ViewportPointToRay(Mouse.X, Mouse.Y)
			local Denominator = Ray.Direction:Dot(Camera.CFrame.LookVector)
			if math.abs(Denominator) > 0.001 then
				local Depth = (Focus - Ray.Origin):Dot(Camera.CFrame.LookVector) / Denominator
				if Depth > 0 then
					local Cursorpoint = Ray.Origin + Ray.Direction * Depth
					local Zoomdirection = math.clamp(Input.Position.Z, -1, 1)
					Focusoffset += (Cursorpoint - Focus) * 0.22 * Zoomdirection
					if Focusoffset.Magnitude > Panlimit then
						Focusoffset = Focusoffset.Unit * Panlimit
					end
				end
			end
			Targetdistance = math.clamp(
				Targetdistance * (1 - Input.Position.Z * 0.12),
				Mindistance,
				Maxdistance
			)
			return
		end

		local Ismousemove = Input.UserInputType == Enum.UserInputType.MouseMovement
		local Isactivetouch = Input.UserInputType == Enum.UserInputType.Touch and Input == Draginput
		if Dragging and (Ismousemove or Isactivetouch) then
			local Current = Pointerposition(Input)
			local Delta = Ismousemove and Vector2.new(Input.Delta.X, Input.Delta.Y) or Current - Lastpointer
			Lastpointer = Current
			if Dragmode == "RotateObject" then
				Objectrotationgoal = nil
				Dragaccumulator += Delta
				if not Lockedrotationaxis and Dragaccumulator.Magnitude >= 4 then
					Lockedrotationaxis = math.abs(Dragaccumulator.X) >= math.abs(Dragaccumulator.Y) and "Y" or "X"
				end
				if Lockedrotationaxis == "X" then
					Pivotobject(Target, Objectpivot(Target) * CFrame.Angles(-Delta.Y * 0.003, 0, 0))
				elseif Lockedrotationaxis == "Y" then
					Pivotobject(Target, Objectpivot(Target) * CFrame.Angles(0, -Delta.X * 0.003, 0))
				end
			elseif Dragmode == "OrbitCamera" then
				Yaw -= Delta.X * 0.008
				Pitch = math.clamp(Pitch - Delta.Y * 0.008, math.rad(-82), math.rad(82))
			else
				local Movement = (-Camera.CFrame.RightVector * Delta.X + Camera.CFrame.UpVector * Delta.Y)
					* Distance
					* 0.0018
				Focusoffset += Movement
				if Focusoffset.Magnitude > Panlimit then
					Focusoffset = Focusoffset.Unit * Panlimit
				end
			end
		end
	end)

	Userinputservice.InputEnded:Connect(function(Input)
		if not Dragging then
			return
		end
		if Input == Draginput
			or Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.MouseButton2
			or Input.UserInputType == Enum.UserInputType.MouseButton3 then
			Enddrag()
		end
	end)

	Runservice:BindToRenderStep(self.Name, Enum.RenderPriority.Camera.Value + 1, function(Deltatime)
		if not Target or not Target.Parent then
			return
		end

		local Alpha = 1 - math.exp(-18 * Deltatime)
		Distance += (Targetdistance - Distance) * Alpha
		if Objectrotationgoal then
			local Flipalpha = 1 - math.exp(-10 * Deltatime)
			local Currentpivot = Objectpivot(Target)
			local Nextrotation = Currentpivot.Rotation:Lerp(Objectrotationgoal, Flipalpha)
			Pivotobject(Target, CFrame.new(Currentpivot.Position) * Nextrotation)
			if Nextrotation.LookVector:Dot(Objectrotationgoal.LookVector) > 0.9999
				and Nextrotation.UpVector:Dot(Objectrotationgoal.UpVector) > 0.9999 then
				Pivotobject(Target, CFrame.new(Objectpivot(Target).Position) * Objectrotationgoal)
				Objectrotationgoal = nil
			end
		end

		local Currentposition = Objectpivot(Target).Position
		local Adjustedy = Currentposition.Y
		local Desiredobjecty = Groundy + Bottomoffsetfrompivot(Target)
		if Objectselected then
			Desiredobjecty += 0.2
		end
		local Heightalpha = 1 - math.exp(-12 * Deltatime)
		Adjustedy = Currentposition.Y + (Desiredobjecty - Currentposition.Y) * Heightalpha
		Pivotobject(Target, CFrame.new(Currentposition.X, Adjustedy, Currentposition.Z) * Objectpivot(Target).Rotation)

		local Selectedcenteroffset = Objectselected and (Adjustedy - Objectstartposition.Y) or 0
		local Focus = if Completionview
			then Objectstartposition
			else Objectstartposition
				+ Vector3.new(0, Selectedcenteroffset, 0)
				+ Vector3.new(0, Objectsize(Target).Y * 0, 0)
				+ Focusoffset
		local Orbit = CFrame.fromEulerAnglesYXZ(Pitch, Yaw, 0)
		local Orbitdirection = Orbit:VectorToWorldSpace(Vector3.new(0, 0, 1))
		local Direction = Orbitdirection * Distance
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = { Target, Player.Character }
		Params.IgnoreWater = true
		Params.RespectCanCollide = true
		local Collision = Workspace:Spherecast(Focus, 0.55, Direction, Params)
		local Alloweddistance = Distance
		if Collision then
			Alloweddistance = math.max(Collision.Distance - 0.45, 0.15)
		end
		if Alloweddistance < Safecameradistance then
			Safecameradistance = Alloweddistance
		else
			local Collisionalpha = 1 - math.exp(-8 * Deltatime)
			Safecameradistance += (Alloweddistance - Safecameradistance) * Collisionalpha
		end
		local Safeposition = Focus + Orbitdirection * Safecameradistance
		local Desiredcamera = CFrame.lookAt(Safeposition, Focus)
		if Cameratransitionactive then
			Cameratransitionelapsed += Deltatime
			local Progress = math.clamp(Cameratransitionelapsed / Cameratransitionduration, 0, 1)
			local Easedprogress = Tweenservice:GetValue(
				Progress,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.InOut
			)
			local Traveldistance = (Safeposition - Cameratransitionstart.Position).Magnitude
			local Arc = math.clamp(Traveldistance * 0.06, 0.5, 2) * math.sin(Easedprogress * math.pi)
			local Position = Cameratransitionstart.Position:Lerp(Safeposition, Easedprogress)
				+ Vector3.new(0, Arc, 0)
			local Looktarget = Cameratransitionlooktarget:Lerp(Focus, Easedprogress)
			Camera.CFrame = CFrame.lookAt(Position, Looktarget)

			if Progress >= 1 then
				Cameratransitionactive = false
				Camera.CFrame = Desiredcamera
			end
		else
			Camera.CFrame = Camera.CFrame:Lerp(Desiredcamera, Alpha)
		end
	end)
end

return Controller
