local Replicatedstorage = game:GetService("ReplicatedStorage")
local Core = require(Replicatedstorage.Shared.Packages.Core)

local Cottontip = {
	Name = "CottonTip",
	AssetName = "CottonTip",
	DisplayRotation = CFrame.Angles(math.rad(305), math.rad(180), math.rad(25)),
}

function Cottontip.OnInputBegan(Context)
	if Context.Display.Instance and not Context.Display.OnObject then return end
	local Cleaningcontroller = Core:GetController("CleaningController")
	Context.SetUsing(true)
	if Context.Object then Cleaningcontroller:TryCleanCotton(Context.Object) end
end

function Cottontip.OnUpdate(Context)
	if Context.IsUsing and Context.Object then Core:GetController("CleaningController"):TryCleanCotton(Context.Object) end
end

function Cottontip.OnInputEnded(Context)
	Context.SetUsing(false)
end

function Cottontip.OnDeselected(Context)
	Context.SetUsing(false)
end

return Cottontip
