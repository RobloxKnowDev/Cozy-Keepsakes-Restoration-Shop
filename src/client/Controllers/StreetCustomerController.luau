local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Streetroute = require(Replicatedstorage.Shared.Utils.StreetRoute)

local Controller = { Name = "StreetCustomerController", Priority = 1 }

type Motion = {
	Visual: Model,
	Root: BasePart,
	Walk: AnimationTrack,
	Idle: AnimationTrack,
	Standheight: number,
	Speed: number,
	Points: { Vector3 },
	Holds: { number },
	Looks: { Vector3 },
	Routestart: number,
	Moving: boolean?,
}

local Walkanimation = "rbxassetid://913402848"
local Idleanimation = "rbxassetid://507766666"
local Walkcyclespeed = 6.4
local Turnspeed = 10

local Motions: { [Instance]: Motion } = {}
local Skins: { Model } = {}
local Skincursor = 0
local Template: Model

local function Loadtrack(Animator: Animator, Id: string): AnimationTrack
	local Animation = Instance.new("Animation")
	Animation.AnimationId = Id
	local Track = Animator:LoadAnimation(Animation)
	Track.Looped = true
	return Track
end

local function Nextskin(): Model
	if #Skins == 0 then
		return Template
	end
	Skincursor = Skincursor % #Skins + 1
	return Skins[Skincursor]
end

local function Readroute(Customer: Instance, Motion: Motion)
	Motion.Points, Motion.Holds, Motion.Looks = Streetroute.Decode(Customer:GetAttribute("Route"))
	Motion.Routestart = Customer:GetAttribute("RouteStart")
end

local function Pose(Motion: Motion, Now: number, Blend: number): (boolean, number)
	local Position, Direction, Moving, Pace =
		Streetroute.Sample(Motion.Points, Motion.Holds, Motion.Looks, Motion.Speed, Now - Motion.Routestart)
	local Center = Position + Vector3.new(0, Motion.Standheight, 0)
	local Target = CFrame.lookAt(Center, Center + Vector3.new(Direction.X, 0, Direction.Z))
	Motion.Root.CFrame = CFrame.new(Center) * Motion.Root.CFrame.Rotation:Lerp(Target.Rotation, Blend)
	return Moving, Pace
end

function Controller:Track(Customer: Instance)
	local Visual = Nextskin():Clone()
	Visual.Name = Customer.Name
	for _, Descendant in ipairs(Visual:GetDescendants()) do
		if Descendant:IsA("BasePart") then
			Descendant.Anchored = false
			Descendant.CanCollide = false
			Descendant.CanTouch = false
		end
	end
	local Humanoid = Visual:WaitForChild("Humanoid") :: Humanoid
	local Root = Visual:WaitForChild("HumanoidRootPart") :: BasePart
	Root.Anchored = true
	Humanoid.EvaluateStateMachine = false
	Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local Motion = {
		Visual = Visual,
		Root = Root,
		Standheight = Humanoid.HipHeight + Root.Size.Y / 2,
		Speed = Customer:GetAttribute("Speed"),
	} :: Motion
	Readroute(Customer, Motion)
	Pose(Motion, Workspace:GetServerTimeNow(), 1)
	Visual.Parent = self.visuals
	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		Animator = Instance.new("Animator")
		Animator.Parent = Humanoid
	end
	Motion.Walk = Loadtrack(Animator, Walkanimation)
	Motion.Idle = Loadtrack(Animator, Idleanimation)
	Motions[Customer] = Motion
	Customer:GetAttributeChangedSignal("RouteStart"):Connect(function()
		Readroute(Customer, Motion)
	end)
end

function Controller:Untrack(Customer: Instance)
	Motions[Customer].Visual:Destroy()
	Motions[Customer] = nil
end

function Controller:Init()
	self.visuals = Instance.new("Folder")
	self.visuals.Name = "StreetCustomerVisuals"
	self.visuals.Parent = Workspace
end

function Controller:Start()
	Template = Replicatedstorage:WaitForChild("Asset"):WaitForChild("Customer"):WaitForChild("1") :: Model
	task.spawn(function()
		local Wardrobe = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("CustomerWardrobe")
		for _, Skin in ipairs(Wardrobe:GetChildren()) do
			table.insert(Skins, Skin :: Model)
		end
		Wardrobe.ChildAdded:Connect(function(Skin)
			table.insert(Skins, Skin :: Model)
		end)
	end)

	local Customers = Replicatedstorage:WaitForChild("StreetCustomers")
	for _, Customer in ipairs(Customers:GetChildren()) do
		self:Track(Customer)
	end
	Customers.ChildAdded:Connect(function(Customer)
		self:Track(Customer)
	end)
	Customers.ChildRemoved:Connect(function(Customer)
		self:Untrack(Customer)
	end)

	Runservice.RenderStepped:Connect(function(Delta)
		local Now = Workspace:GetServerTimeNow()
		local Alpha = 1 - math.exp(-Turnspeed * Delta)
		for _, Motion in pairs(Motions) do
			local Moving, Pace = Pose(Motion, Now, Alpha)
			if Moving ~= Motion.Moving then
				Motion.Moving = Moving
				if Moving then
					Motion.Idle:Stop(0.2)
					Motion.Walk:Play(0.2)
				else
					Motion.Walk:Stop(0.2)
					Motion.Idle:Play(0.2)
				end
			end
			if Moving then
				Motion.Walk:AdjustSpeed(Motion.Speed * Pace / Walkcyclespeed)
			end
		end
	end)
end

return Controller
