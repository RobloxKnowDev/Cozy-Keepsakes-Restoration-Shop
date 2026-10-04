local Runservice = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Controller = { Name = "DisplayItemController", Priority = 7 }

type DisplayObject = Model | BasePart
type DisplayMotion = {
	Center: Vector3,
	Offset: CFrame,
	Phase: number,
}

local Spinspeed = math.rad(30)
local Bobspeed = math.pi * 2 / 4
local Bobheight = 0.2
local Slotphase = 0.8

local Motions: { [DisplayObject]: DisplayMotion } = {}

local function Track(Object: DisplayObject)
	local Center = if Object:IsA("Model") then Object:GetBoundingBox().Position else Object.Position
	Motions[Object] = {
		Center = Center,
		Offset = CFrame.new(Center):ToObjectSpace(Object:GetPivot()),
		Phase = Object:GetAttribute("SlotIndex") * Slotphase,
	}
end

local function Untrack(Object: DisplayObject)
	local Motion = Motions[Object]
	Object:PivotTo(CFrame.new(Motion.Center) * Motion.Offset)
	Motions[Object] = nil
end

local function Watchshop(Shop: Instance)
	local Displayedobjects = Shop:WaitForChild("DisplayedObjects")
	for _, Object in ipairs(Displayedobjects:GetChildren()) do
		Track(Object)
	end
	Displayedobjects.ChildAdded:Connect(Track)
	Displayedobjects.ChildRemoved:Connect(Untrack)
end

function Controller:Start()
	for _, Shop in ipairs(Workspace:WaitForChild("Map"):WaitForChild("Shops"):GetChildren()) do
		task.spawn(Watchshop, Shop)
	end
	Runservice.RenderStepped:Connect(function()
		local Clock = os.clock()
		for Object, Motion in pairs(Motions) do
			local Time = Clock + Motion.Phase
			local Height = Bobheight * (0.5 - 0.5 * math.cos(Time * Bobspeed))
			Object:PivotTo(
				CFrame.new(Motion.Center + Vector3.new(0, Height, 0))
					* CFrame.Angles(0, Time * Spinspeed % (math.pi * 2), 0)
					* Motion.Offset
			)
		end
	end)
end

return Controller
