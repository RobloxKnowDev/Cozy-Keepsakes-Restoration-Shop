local Replicatedstorage = game:GetService("ReplicatedStorage")
local Userinputservice = game:GetService("UserInputService")
local Core = require(Replicatedstorage.Shared.Packages.Core)

local Tweezers = {
	Name = "Tweezers",
	AssetName = "Tweezers",
	UsesPullMotion = true,
	DisplayRotation = CFrame.Angles(math.rad(180), 0, math.rad(-12)),
}

local Pressing = false
local Grabbing = false

local function Trygrab(Context)
	if Grabbing or not Context.Object then
		return
	end
	Grabbing = true
	Core:GetController("StickerController"):Begin(Context.Object, Context.Display.Tip, Context.Display.Instance)
	Grabbing = false
end

function Tweezers.GetDisplayCFrame(Context): CFrame
	local Position = Context.SurfacePosition
	return CFrame.lookAt(Position, Position + Context.SurfaceNormal, Context.Camera.CFrame.UpVector)
		* Tweezers.DisplayRotation
end

function Tweezers.OnInputBegan(Context)
	Pressing = true
	Trygrab(Context)
end

function Tweezers.OnUpdate(Context)
	if Pressing and Userinputservice:GetLastInputType() == Enum.UserInputType.Touch then
		Trygrab(Context)
	end
	Core:GetController("StickerController"):Update()
end

function Tweezers.OnInputEnded(Context)
	Pressing = false
	Core:GetController("StickerController"):Release()
end

function Tweezers.OnDeselected(Context)
	Pressing = false
	Core:GetController("StickerController"):Release()
end

function Tweezers.GetLockedPivot()
	return Core:GetController("StickerController"):GetLockedToolPivot()
end

return Tweezers
