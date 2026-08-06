local Replicatedstorage = game:GetService("ReplicatedStorage")
local Core = require(Replicatedstorage.Shared.Packages.Core)

local Tweezers = {
	Name = "Tweezers",
	AssetName = "Tweezers",
	UsesCenteredTip = true,
	UsesPullMotion = true,
	DisplayRotation = CFrame.Angles(math.rad(85), 0, math.rad(-12)),
}

function Tweezers.OnInputBegan(Context)
	if Context.Object then
		Core:GetController("StickerController"):Begin(Context.Object, Context.Display.Tip, Context.Display.Instance)
	end
end

function Tweezers.OnUpdate(Context)
	Core:GetController("StickerController"):Update()
end

function Tweezers.OnInputEnded(Context)
	Core:GetController("StickerController"):Release()
end

function Tweezers.GetLockedPivot()
	return Core:GetController("StickerController"):GetLockedToolPivot()
end

return Tweezers
