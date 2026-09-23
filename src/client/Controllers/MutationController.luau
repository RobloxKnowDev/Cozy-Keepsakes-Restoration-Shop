local Collectionservice = game:GetService("CollectionService")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")

local Mutationconfig = require(Replicatedstorage.Shared.Config.Mutation)

local RainbowStops = 6

local Mutationcontroller = {
	Name = "MutationController",
	Priority = 3,
}

local function Rainbowsequence(Hue: number): ColorSequence
	local Keypoints = { ColorSequenceKeypoint.new(0, Color3.fromHSV(Hue, 1, 1)) }
	for Index = 0, RainbowStops - 1 do
		local Time = (Index / RainbowStops - Hue) % 1
		if Time > 0 and Time < 1 then
			table.insert(Keypoints, ColorSequenceKeypoint.new(Time, Color3.fromHSV(Index / RainbowStops, 1, 1)))
		end
	end
	table.sort(Keypoints, function(Left, Right)
		return Left.Time < Right.Time
	end)
	table.insert(Keypoints, ColorSequenceKeypoint.new(1, Color3.fromHSV(Hue, 1, 1)))
	return ColorSequence.new(Keypoints)
end

function Mutationcontroller:GetColor(Mutation: string): Color3?
	local Definition = Mutationconfig[tostring(Mutation)]
	if not Definition or Definition == Mutationconfig.Normal then
		return nil
	end
	if Mutation == "Rainbow" then
		return Color3.fromHSV(self.hue, 1, 1)
	end
	return Definition.Gradient.Keypoints[1].Value
end

function Mutationcontroller:GetGradient(Mutation: string): ColorSequence?
	local Definition = Mutationconfig[tostring(Mutation)]
	if not Definition or Definition == Mutationconfig.Normal then
		return nil
	end
	if Mutation == "Rainbow" then
		return self.rainbowSequence
	end
	return Definition.Gradient
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

function Mutationcontroller:Init()
	self.hue = 0
	self.rainbowSequence = Rainbowsequence(0)
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
		self.rainbowSequence = Rainbowsequence(self.hue)
		self:Paint(self.hue)
	end)
end

return Mutationcontroller
