local Replicatedstorage = game:GetService("ReplicatedStorage")
local Userinputservice = game:GetService("UserInputService")
local Core = require(Replicatedstorage.Shared.Packages.Core)

local Cottontip = {
	Name = "CottonTip",
	AssetName = "CottonTip",
	DisplayRotation = CFrame.Angles(math.rad(305), math.rad(180), math.rad(25)),
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

function Cottontip.OnInputBegan()
	Pressing = true
end

function Cottontip.OnUpdate(Context)
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
	Core:GetController("CleaningController"):TryCleanCotton(Context.Object)
end

function Cottontip.OnInputEnded()
	Pressing = false
end

function Cottontip.OnDeselected()
	Pressing = false
	Lastposition = nil
	Setscrubbing(false)
end

return Cottontip
