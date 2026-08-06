local Replicatedstorage = game:GetService("ReplicatedStorage")
local Core = require(Replicatedstorage.Shared.Packages.Core)

local Polish = {
	Name = "Polish",
}

function Polish.OnInputBegan(Context)
	if Context.Display.Instance and not Context.Display.OnObject then return end
	Context.SetUsing(true)
	if Context.Object then Core:GetController("CleaningController"):TryClean(Context.Object, Polish.Name) end
end

function Polish.OnUpdate(Context)
	if Context.IsUsing and Context.Object then Core:GetController("CleaningController"):TryClean(Context.Object, Polish.Name) end
end

function Polish.OnInputEnded(Context)
	Context.SetUsing(false)
end

return Polish
