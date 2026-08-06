local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)

local Controllersfolder = script.Parent.Controllers

for _, Module in ipairs(Controllersfolder:GetChildren()) do
	if Module:IsA("ModuleScript") then
		local Controller = require(Module)
		Core:RegisterController(Controller)
	end
end

Core:Start()
