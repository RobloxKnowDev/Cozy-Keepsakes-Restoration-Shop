local Objectconfig = require(script.Parent.Parent.Config.Object)

local function GetObjectRotation(Objectkey: string): CFrame
	local Rotation = Objectconfig.Object[Objectkey].Rotation
	if not Rotation then
		return CFrame.identity
	end
	return CFrame.Angles(math.rad(Rotation.X), math.rad(Rotation.Y), math.rad(Rotation.Z))
end

return GetObjectRotation
