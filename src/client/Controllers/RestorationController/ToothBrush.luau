local Replicatedstorage = game:GetService("ReplicatedStorage")
local Userinputservice = game:GetService("UserInputService")
local Core = require(Replicatedstorage.Shared.Packages.Core)

local Toothbrush = {
	Name = "ToothBrush",
	AssetName = "Toothbrush",
	DisplayRotation = CFrame.Angles(math.rad(90), math.rad(0), 0),
}

local Movegrace = 0.25
local Pressing = false
local Scrubbing = false
local Lastposition: Vector3? = nil
local Lastmove = 0

local function Setscrubbing(Active: boolean)
	if Scrubbing == Active then return end
	Scrubbing = Active
	Core:GetController("FeedbackController"):SetLoop("Scrub", Active)
end

function Toothbrush.OnInputBegan()
	Pressing = true
end

function Toothbrush.OnUpdate(Context)
	local Display = Context.Display
	local Touching = Userinputservice:GetLastInputType() == Enum.UserInputType.Touch
	local Active = Context.Object ~= nil and Display.OnObject and (Pressing or not Touching)
	if not Active then
		Setscrubbing(false)
		Lastposition = nil
		return
	end
	local Position = Display.SurfacePosition
	if not Lastposition or (Position - Lastposition).Magnitude > 0.002 then Lastmove = os.clock() end
	Lastposition = Position
	Setscrubbing(os.clock() - Lastmove < Movegrace)
	Core:GetController("CleaningController"):TryCleanDirt(Context.Object, Toothbrush.Name)
end

function Toothbrush.OnInputEnded()
	Pressing = false
end

function Toothbrush.OnDeselected()
	Pressing = false
	Lastposition = nil
	Setscrubbing(false)
end

return Toothbrush
