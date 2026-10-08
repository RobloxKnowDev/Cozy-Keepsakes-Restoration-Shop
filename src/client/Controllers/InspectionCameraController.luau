local Guiservice = game:GetService("GuiService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Tweenservice = game:GetService("TweenService")
local Userinputservice = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Playershop = require(Replicatedstorage.Shared.Utils.PlayerShop)

local Controller = { Name = "InspectionCameraController", Priority = 5 }

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Shop = Playershop(Player)
local Mapcamera = Shop:WaitForChild("Camera")
local Generateditems = Shop:WaitForChild("GeneratedItems")
local Planwork = Shop:WaitForChild("Work")
local Leaderboardcamera: Instance? = nil
type InspectionTarget = Model | BasePart
local Target: InspectionTarget? = nil
local Yaw = 0
local Pitch = math.rad(-38)
local Orbittravel = 0
local Distance = 8
local Dragging = false
local Enabled = false
local Transformmode = "Orbit"
local Dragmode = "RotateObject"
local Draginput: InputObject? = nil
local Lastpointer = Vector2.zero
local Dragaccumulator = Vector2.zero
local Lockedrotationaxis: string? = nil
local Stick = Vector2.zero
local Stickdragging = false
local Stickdeadzone = 0.18
local Stickorbitspeed = 2.4
local Stickrotatespeed = 2.6
local Framingfactor = 0.95
local Minimumdistance = 2.5
local Cameraclearance = 0.5
local Maxorbitpitch = math.rad(0)
local Boundsoffset = Vector3.zero
local Boundsradius = 1
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
local Cameratransitionduration = 1.1
local Cameratransitionstart = CFrame.identity
local Cameratransitionlooktarget = Vector3.zero
local Staticcameraduration = 0.45
local Expositioncameraduration = 0.45
local Expositionbuttonleadtime = 0.1
local Defaultfieldofview = Camera.FieldOfView
local Expositionfieldofview = 80
local Fieldofview = Defaultfieldofview

type CameraPartOptions = {
	Folder: Instance?,
	Duration: number?,
	LeadTime: number?,
	FieldOfView: number?,
	OnLead: (() -> ())?,
	OnArrived: (() -> ())?,
}

local Viewname = "CamPart"
local Viewoptions: CameraPartOptions? = nil

local function Pointerposition(Input: InputObject): Vector2
	return Vector2.new(Input.Position.X, Input.Position.Y)
end

local function Ispointerontarget(Screenposition: Vector2): boolean
	if not Target then
		return false
	end

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Target }
	local Ray = Camera:ScreenPointToRay(Screenposition.X, Screenposition.Y)
	return Workspace:Raycast(Ray.Origin, Ray.Direction * 500, Params) ~= nil
end

local function Begindrag(Input: InputObject, Mode: string)
	Dragging = true
	Dragmode = Mode
	Draginput = Input
	Lastpointer = Pointerposition(Input)
	Dragaccumulator = Vector2.zero
	Lockedrotationaxis = nil
	Cameratransitionactive = false
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

local function Objectbounds(Object: InspectionTarget): (CFrame, Vector3)
	if Object:IsA("Model") then
		return Object:GetBoundingBox()
	end
	return Object.CFrame, Object.Size
end

local function Pivotobject(Object: InspectionTarget, Pivot: CFrame)
	if Object:IsA("Model") then
		Object:PivotTo(Pivot)
	else
		Object.CFrame = Pivot
	end
end

local function Rotatearoundcenter(Object: InspectionTarget, Rotation: CFrame)
	Pivotobject(Object, Objectpivot(Object) * CFrame.new(Boundsoffset) * Rotation * CFrame.new(-Boundsoffset))
end

local function Framingdistance(): number
	local Halfvertical = math.rad(Defaultfieldofview * 0.5)
	local Viewport = Camera.ViewportSize
	local Halfhorizontal = math.atan(math.tan(Halfvertical) * Viewport.X / Viewport.Y)
	return math.max(Boundsradius / math.sin(math.min(Halfvertical, Halfhorizontal)) * Framingfactor, Minimumdistance)
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
		if Bottomy == math.huge then
			return Verticalhalfextent(Object)
		end
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
	Objectrotationgoal = Originalobjectrotation * (Showingback and CFrame.Angles(math.pi, 0, 0) or CFrame.identity)
end

function Controller:IsDragging(): boolean
	return Dragging or Stickdragging
end

function Controller:IsIntroCameraReady(): boolean
	return Introcameraactive and Introcameratween == nil and Viewname == "CamPart"
end

function Controller:SetEnabled(Value: boolean)
	Enabled = Value
	if not Enabled then
		Enddrag()
		Setobjectselected(false)
	end
end

function Controller:GetOrbitTravel(): number
	return Orbittravel
end

function Controller:GetFieldOfView(): number
	return Fieldofview
end

function Controller:SetTransformMode(Mode: string)
	if Mode ~= "Rotate" and Mode ~= "Orbit" then
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
	if not Tween then
		return
	end
	Introcameratween = nil
	Tween:Cancel()
	Tween:Destroy()
end

local function Setfieldofview(Value: number, Duration: number)
	if Fieldofview == Value then
		return
	end
	Fieldofview = Value
	Tweenservice:Create(Camera, TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = Value,
	}):Play()
end

local function ShowCameraPart(Name: string, Options: CameraPartOptions?): boolean
	if Target then
		return false
	end
	local Folder = if Options and Options.Folder then Options.Folder else Mapcamera
	local CameraPart = Folder:WaitForChild(Name) :: BasePart
	if not Introcameraactive then
		Previouscameratype = Camera.CameraType
		Previouscamerasubject = Camera.CameraSubject
	end

	Introcameraactive = true
	Viewname = Name
	Viewoptions = Options
	Camera.CameraType = Enum.CameraType.Scriptable
	CancelIntroCameraTween()
	local Duration = if Options and Options.Duration then Options.Duration else Staticcameraduration
	Setfieldofview(if Options and Options.FieldOfView then Options.FieldOfView else Defaultfieldofview, Duration)

	local Newtween = Tweenservice:Create(
		Camera,
		TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CameraPart.CFrame }
	)
	Introcameratween = Newtween
	Newtween:Play()
	if Options and Options.OnLead then
		local OnLead = Options.OnLead
		task.delay(math.max(Duration - (Options.LeadTime or 0), 0), function()
			if Introcameratween == Newtween then
				OnLead()
			end
		end)
	end
	Newtween.Completed:Once(function(State)
		if Introcameratween == Newtween then
			Newtween:Destroy()
			Introcameratween = nil
			if State == Enum.PlaybackState.Completed and Options and Options.OnArrived then
				Options.OnArrived()
			end
		end
	end)
	return true
end

local function Bindshop()
	local Nextshop = Playershop(Player)
	if Nextshop == Shop then
		return
	end
	local Nextcamera = Nextshop:WaitForChild("Camera")
	Nextcamera:WaitForChild("CamPart")
	Nextcamera:WaitForChild("CamPartComputer")
	Nextcamera:WaitForChild("CamPartExposition")
	local Nextitems = Nextshop:WaitForChild("GeneratedItems")
	local Nextwork = Nextshop:WaitForChild("Work")
	if Player:GetAttribute("Shop") ~= Nextshop.Name then
		return
	end
	Shop = Nextshop
	Mapcamera = Nextcamera
	Generateditems = Nextitems
	Planwork = Nextwork
	if Introcameraactive then
		ShowCameraPart(Viewname, Viewoptions)
	end
end

function Controller:ShowIntroCamera(): boolean
	return ShowCameraPart("CamPart")
end

function Controller:ShowIntroCameraFromExposition(): boolean
	return ShowCameraPart("CamPart", {
		Duration = Expositioncameraduration,
	})
end

function Controller:ShowExpositionCamera(OnLead: (() -> ())?, OnArrived: (() -> ())?): boolean
	return ShowCameraPart("CamPartExposition", {
		Duration = Expositioncameraduration,
		LeadTime = Expositionbuttonleadtime,
		FieldOfView = Expositionfieldofview,
		OnLead = OnLead,
		OnArrived = OnArrived,
	})
end

function Controller:ShowComputerCamera(): boolean
	return ShowCameraPart("CamPartComputer")
end

function Controller:ShowLeaderboardCamera(Name: string): boolean
	Leaderboardcamera = Leaderboardcamera or Workspace:WaitForChild("Map"):WaitForChild("Leaderboards"):WaitForChild("Camera")
	return ShowCameraPart(Name, {
		Folder = Leaderboardcamera,
	})
end

function Controller:Begin(Object: InspectionTarget)
	local Shouldtransition = Introcameraactive
	CancelIntroCameraTween()
	Target = Object
	Objectselected = false
	Originalobjectrotation = Objectpivot(Object).Rotation
	Showingback = false
	Objectrotationgoal = nil
	Completionview = false
	Groundy = Object:GetAttribute("SpawnFloorY") or Findgroundy(Object)
	local Look = (Mapcamera:WaitForChild("CamPart") :: BasePart).CFrame.LookVector
	Yaw = math.atan2(-Look.X, -Look.Z)
	Pitch = math.rad(-38)
	Orbittravel = 0

	local Boundscframe, Boundssize = Objectbounds(Object)
	Boundsoffset = Objectpivot(Object):PointToObjectSpace(Boundscframe.Position)
	Boundsradius = Boundssize.Magnitude * 0.5
	Distance = Framingdistance()
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
	Setfieldofview(Defaultfieldofview, Cameratransitionduration)
end

function Controller:PrepareCompletion()
	if not Target then
		return
	end
	Enabled = false
	Completionview = true
	Enddrag()
	Setobjectselected(false)
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

local function Applystick(Deltatime: number)
	local Rotatemode = Enabled and Transformmode == "Rotate"
	if Stick.Magnitude < Stickdeadzone or Completionview or (Cameratransitionactive and Rotatemode) then
		Stickdragging = false
		return
	end
	Stickdragging = true
	local Direction = Stick.Unit * ((Stick.Magnitude - Stickdeadzone) / (1 - Stickdeadzone))
	if Rotatemode then
		Objectrotationgoal = nil
		local Angle = Stickrotatespeed * Deltatime
		Rotatearoundcenter(Target, CFrame.Angles(Direction.Y * Angle, -Direction.X * Angle, 0))
		return
	end
	Cameratransitionactive = false
	local Yawdelta = Direction.X * Stickorbitspeed * Deltatime
	local Pitchdelta = Direction.Y * Stickorbitspeed * Deltatime
	Yaw -= Yawdelta
	Pitch = math.clamp(Pitch + Pitchdelta, math.rad(-82), Maxorbitpitch)
	Orbittravel += math.abs(Yawdelta) + math.abs(Pitchdelta)
end

function Controller:Start()
	Player:GetAttributeChangedSignal("Shop"):Connect(Bindshop)
	Bindshop()
	Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		Distance = Framingdistance()
	end)

	Userinputservice.InputBegan:Connect(function(Input, Processed)
		if Processed or not Target or Completionview then
			return
		end

		local Isprimary = Input.UserInputType == Enum.UserInputType.MouseButton1
		local Issecondary = Input.UserInputType == Enum.UserInputType.MouseButton2
		local Istouch = Input.UserInputType == Enum.UserInputType.Touch
		local Position = Pointerposition(Input)
		local Rotatemode = Enabled and Transformmode == "Rotate"
		if Cameratransitionactive and (Rotatemode or not (Issecondary or Istouch)) then
			return
		end

		if Istouch then
			if Dragging then
				return
			end
			local Ontarget = Ispointerontarget(Position)
			if Enabled then
				Setobjectselected(Ontarget)
				Begindrag(Input, if Rotatemode then "RotateObject" else "OrbitCamera")
			elseif not Ontarget then
				Begindrag(Input, "OrbitCamera")
			end
			return
		end

		if Enabled and Isprimary and Ispointerontarget(Position) then
			Setobjectselected(true)
		elseif Enabled and Isprimary then
			Setobjectselected(false)
		elseif Issecondary and Rotatemode then
			Begindrag(Input, "RotateObject")
			Userinputservice.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif Issecondary then
			Begindrag(Input, "OrbitCamera")
			Userinputservice.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		end
	end)

	Userinputservice.InputChanged:Connect(function(Input)
		if Input.KeyCode == Enum.KeyCode.Thumbstick2 then
			Stick = Vector2.new(Input.Position.X, Input.Position.Y)
			return
		end
		if not Target or Completionview or Cameratransitionactive then
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
					Rotatearoundcenter(Target, CFrame.Angles(-Delta.Y * 0.003, 0, 0))
				elseif Lockedrotationaxis == "Y" then
					Rotatearoundcenter(Target, CFrame.Angles(0, -Delta.X * 0.003, 0))
				end
			elseif Dragmode == "OrbitCamera" then
				Yaw -= Delta.X * 0.008
				Pitch = math.clamp(Pitch - Delta.Y * 0.008, math.rad(-82), Maxorbitpitch)
				Orbittravel += math.abs(Delta.X * 0.008) + math.abs(Delta.Y * 0.008)
			end
		end
	end)

	local function Canceldrag()
		if Dragging then
			Enddrag()
		end
	end
	Userinputservice.WindowFocusReleased:Connect(Canceldrag)
	Guiservice.MenuOpened:Connect(Canceldrag)

	Userinputservice.InputEnded:Connect(function(Input)
		if not Dragging then
			return
		end
		if
			Input == Draginput
			or Input.UserInputType == Enum.UserInputType.MouseButton1
			or Input.UserInputType == Enum.UserInputType.MouseButton2
		then
			Enddrag()
		end
	end)

	Runservice:BindToRenderStep(self.Name, Enum.RenderPriority.Camera.Value + 1, function(Deltatime)
		if not Target or not Target.Parent then
			return
		end
		Applystick(Deltatime)

		local Alpha = 1 - math.exp(-18 * Deltatime)
		if Objectrotationgoal then
			local Flipalpha = 1 - math.exp(-10 * Deltatime)
			local Currentpivot = Objectpivot(Target)
			local Center = Currentpivot * Boundsoffset
			local Nextrotation = Currentpivot.Rotation:Lerp(Objectrotationgoal, Flipalpha)
			Pivotobject(Target, CFrame.new(Center) * Nextrotation * CFrame.new(-Boundsoffset))
			if
				Nextrotation.LookVector:Dot(Objectrotationgoal.LookVector) > 0.9999
				and Nextrotation.UpVector:Dot(Objectrotationgoal.UpVector) > 0.9999
			then
				Pivotobject(Target, CFrame.new(Center) * Objectrotationgoal * CFrame.new(-Boundsoffset))
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

		local Focus = Objectpivot(Target) * Boundsoffset
		local Orbit = CFrame.fromEulerAnglesYXZ(Pitch, Yaw, 0)
		local Orbitdirection = Orbit:VectorToWorldSpace(Vector3.new(0, 0, 1))
		local Direction = Orbitdirection * Distance
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = { Target, Player.Character, Generateditems }
		Params.IgnoreWater = true
		Params.RespectCanCollide = true
		local Collision = Workspace:Spherecast(Focus, 0.55, Direction, Params)
		local Planparams = RaycastParams.new()
		Planparams.FilterType = Enum.RaycastFilterType.Include
		Planparams.FilterDescendantsInstances = { Planwork }
		local Plancollision = Workspace:Spherecast(Focus, 0.55, Direction, Planparams)
		if Plancollision and (not Collision or Plancollision.Distance < Collision.Distance) then
			Collision = Plancollision
		end
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
		local Clearradius = Boundsradius + Cameraclearance
		Safecameradistance = math.max(Safecameradistance, Clearradius)
		local Safeposition = Focus + Orbitdirection * Safecameradistance
		local Desiredcamera = CFrame.lookAt(Safeposition, Focus)
		if Cameratransitionactive then
			Cameratransitionelapsed += Deltatime
			local Progress = math.clamp(Cameratransitionelapsed / Cameratransitionduration, 0, 1)
			local Easedprogress = Tweenservice:GetValue(Progress, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
			local Traveldistance = (Safeposition - Cameratransitionstart.Position).Magnitude
			local Arc = math.clamp(Traveldistance * 0.06, 0.5, 2) * math.sin(Easedprogress * math.pi)
			local Position = Cameratransitionstart.Position:Lerp(Safeposition, Easedprogress) + Vector3.new(0, Arc, 0)
			local Looktarget = Cameratransitionlooktarget:Lerp(Focus, Easedprogress)
			Camera.CFrame = CFrame.lookAt(Position, Looktarget)

			if Progress >= 1 then
				Cameratransitionactive = false
				Camera.CFrame = Desiredcamera
			end
		else
			Camera.CFrame = Camera.CFrame:Lerp(Desiredcamera, Alpha)
		end
		local Camerafromcenter = Camera.CFrame.Position - Focus
		if Camerafromcenter.Magnitude < Clearradius then
			Camera.CFrame = CFrame.new(Focus + Camerafromcenter.Unit * Clearradius) * Camera.CFrame.Rotation
		end
	end)
end

return Controller
