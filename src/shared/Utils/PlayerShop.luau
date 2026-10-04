local Workspace = game:GetService("Workspace")

return function(Player: Player): Model
	while not Player:GetAttribute("Shop") do
		Player:GetAttributeChangedSignal("Shop"):Wait()
	end
	return Workspace:WaitForChild("Map"):WaitForChild("Shops"):WaitForChild(Player:GetAttribute("Shop")) :: Model
end
