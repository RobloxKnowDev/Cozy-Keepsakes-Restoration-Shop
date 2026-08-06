local Replicatedstorage = game:GetService("ReplicatedStorage")
local Core = require(Replicatedstorage.Shared.Packages.Core)

local Cottontip = {
	Name = "CottonTip",
	AssetName = "CottonTip",
	DisplayRotation = CFrame.Angles(math.rad(305), math.rad(180), math.rad(25)),
}

function Cottontip.OnInputBegan(Context)
	if Context.Display.Instance and not Context.Display.OnObject then return end
	Context.SetUsing(true)
	if Context.Object then Core:GetController("CleaningController"):TryClean(Context.Object, Cottontip.Name) end
end

function Cottontip.OnUpdate(Context)
	if Context.IsUsing and Context.Object then Core:GetController("CleaningController"):TryClean(Context.Object, Cottontip.Name) end
end

function Cottontip.OnInputEnded(Context)
	Context.SetUsing(false)
end

return Cottontip
