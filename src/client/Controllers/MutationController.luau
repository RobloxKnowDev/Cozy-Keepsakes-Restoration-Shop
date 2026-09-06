local Collectionservice = game:GetService("CollectionService")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")

local Mutationconfig = require(Replicatedstorage.Shared.Config.Mutation)

local Mutationcontroller = {
	Name = "MutationController",
	Priority = 3,
}

function Mutationcontroller:GetColor(Mutation: string): Color3?
	local Definition = Mutationconfig[tostring(Mutation)]
	if not Definition or Definition == Mutationconfig.Normal then
		return nil
	end
	if Mutation == "Rainbow" then
		return Color3.fromHSV(self.hue or 0, 1, 1)
	end
	return Definition.Color
end

function Mutationcontroller:Paint(Hue: number)
	local Color = Color3.fromHSV(Hue, 1, 1)
	local Sequence = ColorSequence.new(Color)
	for _, Attachment in ipairs(Collectionservice:GetTagged(Mutationconfig.RainbowTag)) do
		for _, Child in ipairs(Attachment:GetChildren()) do
			if Child:IsA("ParticleEmitter") then
				Child.Color = Sequence
			elseif Child:IsA("Light") then
				Child.Color = Color
			end
		end
	end
end

function Mutationcontroller:Start()
	local Elapsed = 0
	local Sincepaint = 0
	Runservice.Heartbeat:Connect(function(Delta)
		Elapsed += Delta
		Sincepaint += Delta
		if Sincepaint < Mutationconfig.RainbowUpdateInterval then
			return
		end
		Sincepaint = 0
		self.hue = Elapsed % Mutationconfig.RainbowCycleSeconds / Mutationconfig.RainbowCycleSeconds
		self:Paint(self.hue)
	end)
end

return Mutationcontroller
