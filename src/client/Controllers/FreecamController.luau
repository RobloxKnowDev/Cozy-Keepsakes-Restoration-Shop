local Players = game:GetService("Players")

local FreecamController = {
	Name = "FreecamController",
	Priority = 20,
}

local Player = Players.LocalPlayer

local function Remove(Child: Instance)
	if Child.Name == "Freecam" and Player:GetAttribute("Admin") ~= true then
		Child:Destroy()
	end
end

function FreecamController:Start()
	local Playergui = Player:WaitForChild("PlayerGui")
	Playergui.ChildAdded:Connect(Remove)
	for _, Child in ipairs(Playergui:GetChildren()) do
		Remove(Child)
	end
end

return FreecamController
