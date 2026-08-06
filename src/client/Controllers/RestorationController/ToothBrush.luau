local Replicatedstorage = game:GetService("ReplicatedStorage")
local Core = require(Replicatedstorage.Shared.Packages.Core)

local Toothbrush = {
	Name = "ToothBrush",
	AssetName = "Toothbrush",
	DisplayRotation = CFrame.Angles(math.rad(270), math.rad(180), 0),
}

function Toothbrush.OnInputBegan(Context)
	if Context.Display.Instance and not Context.Display.OnObject then return end
	Context.SetUsing(true)
	if Context.Object then Core:GetController("CleaningController"):TryClean(Context.Object, Toothbrush.Name) end
end

function Toothbrush.OnUpdate(Context)
	if Context.IsUsing and Context.Object then Core:GetController("CleaningController"):TryClean(Context.Object, Toothbrush.Name) end
end

function Toothbrush.OnInputEnded(Context)
	Context.SetUsing(false)
end

return Toothbrush
