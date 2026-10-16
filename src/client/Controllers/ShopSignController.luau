local Replicatedstorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Translation = require(Replicatedstorage.Shared.Utils.Translation)

local Shopsigncontroller = {
	Name = "ShopSignController",
	Priority = 7,
}

local Emptysign = "N/A"

local function Render(Surfacegui: SurfaceGui)
	local Owner = Surfacegui:GetAttribute("Owner")
	for _, Label in ipairs(Surfacegui:GetChildren()) do
		if Label:IsA("TextLabel") then
			if Owner then
				Translation.Set(Label, "{1}'s Shop", Owner)
			else
				Translation.Raw(Label, Emptysign)
			end
		end
	end
end

function Shopsigncontroller:Start()
	task.spawn(function()
		local Signs = Workspace:WaitForChild("Map"):WaitForChild("ShopSigns")
		for _, Sign in ipairs(Signs:GetChildren()) do
			if string.match(Sign.Name, "^Shop%d+Text$") then
				local Surfacegui = Sign:WaitForChild("SurfaceGui") :: SurfaceGui
				Render(Surfacegui)
				Surfacegui:GetAttributeChangedSignal("Owner"):Connect(function()
					Render(Surfacegui)
				end)
			end
		end
	end)
end

return Shopsigncontroller
