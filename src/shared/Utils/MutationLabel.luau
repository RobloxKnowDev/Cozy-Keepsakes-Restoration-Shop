local Replicatedstorage = game:GetService("ReplicatedStorage")

local Mutationconfig = require(Replicatedstorage.Shared.Config.Mutation)

local MutationLabel = {}

function MutationLabel.Apply(Label: TextLabel, Item: any)
	local Basecolor = Label:GetAttribute("BaseTextColor")
	if not Basecolor then
		Basecolor = Label.TextColor3
		Label:SetAttribute("BaseTextColor", Basecolor)
	end
	Label.Text = tostring(Item and Item.Name or "")
	local Definition = Mutationconfig[tostring(Item and Item.Mutation)]
	if not Definition or Definition == Mutationconfig.Normal then
		Label.TextColor3 = Basecolor
		return
	end
	Label.TextColor3 = Definition.Color
end

return MutationLabel
