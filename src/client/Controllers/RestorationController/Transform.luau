local Replicatedstorage = game:GetService("ReplicatedStorage")
local Core = require(Replicatedstorage.Shared.Packages.Core)

local Transform = {
	Name = "Transform",
	EnablesInspection = true,
}

function Transform.OnSelected(Context)
	local Camera = Core:GetController("InspectionCameraController")
	Camera:SetEnabled(true)
	Camera:SelectObject()
end

function Transform.OnDeselected()
	Core:GetController("InspectionCameraController"):SetEnabled(false)
end

return Transform
