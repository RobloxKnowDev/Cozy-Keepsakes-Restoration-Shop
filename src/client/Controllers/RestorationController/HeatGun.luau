local Replicatedstorage = game:GetService("ReplicatedStorage")
local Core = require(Replicatedstorage.Shared.Packages.Core)

local Heatgun = {
	Name = "HeatGun",
}

function Heatgun.OnInputBegan(Context)
	if Context.Display.Instance and not Context.Display.OnObject then return end
	Context.SetUsing(true)
	if Context.Object then Core:GetController("CleaningController"):TryClean(Context.Object, Heatgun.Name) end
end

function Heatgun.OnUpdate(Context)
	if Context.IsUsing and Context.Object then Core:GetController("CleaningController"):TryClean(Context.Object, Heatgun.Name) end
end

function Heatgun.OnInputEnded(Context)
	Context.SetUsing(false)
end

return Heatgun
