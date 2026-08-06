local Guiservice = game:GetService("GuiService")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Userinputservice = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Cleaningcontroller = { Name = "CleaningController", Priority = 9 }

function Cleaningcontroller:Init()
	self.camera = Workspace.CurrentCamera
	self.lastRequest = 0
end

function Cleaningcontroller:TryClean(Object: Model | BasePart, Toolname: string)
	if os.clock() - self.lastRequest < 0.05 then return end
	if Core:GetController("InspectionCameraController"):IsDragging() then return end
	local Mouse = Userinputservice:GetMouseLocation() - Guiservice:GetGuiInset()
	local Ray = self.camera:ViewportPointToRay(Mouse.X, Mouse.Y)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Object }
	local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 100, Params)
	if Result and Result.Instance:GetAttribute("SpotKind") then
		self.lastRequest = os.clock()
		Remotemanager:FireServer("RestorationService", "CleanSpot", Result.Instance, Toolname)
	end
end

return Cleaningcontroller
