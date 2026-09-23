local Rainbowgradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FF0000")),
	ColorSequenceKeypoint.new(1 / 6, Color3.fromHex("FFFF00")),
	ColorSequenceKeypoint.new(2 / 6, Color3.fromHex("00FF00")),
	ColorSequenceKeypoint.new(3 / 6, Color3.fromHex("00FFFF")),
	ColorSequenceKeypoint.new(4 / 6, Color3.fromHex("0000FF")),
	ColorSequenceKeypoint.new(5 / 6, Color3.fromHex("FF00FF")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("FF0000")),
})

return {
	Order = {
		"Normal",
		"Gold",
		"Diamond",
		"Rainbow",
	},

	TestSequence = { "Gold", "Diamond", "Rainbow" },

	RevealRatio = 0.5,
	RevealDelaySeconds = 1.15,
	VfxName = "MutationVfx",
	RainbowTag = "RainbowVfx",
	RainbowCycleSeconds = 4,
	RainbowUpdateInterval = 0.05,

	Normal = {
		Name = "Normal",
		Gradient = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		BackgroundGradient = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Weight = 88,
		ValueMultiplier = 1,
		ReputationMultiplier = 1,
	},

	Gold = {
		Name = "Gold",
		Gradient = ColorSequence.new(Color3.fromHex("FFE05A"), Color3.fromHex("FFE98C")),
		BackgroundGradient = ColorSequence.new(Color3.fromHex("FFE05A"), Color3.fromHex("FFEEA7")),
		Weight = 8,
		ValueMultiplier = 2,
		ReputationMultiplier = 1.5,
	},

	Diamond = {
		Name = "Diamond",
		Gradient = ColorSequence.new(Color3.fromHex("25C4FE"), Color3.fromHex("8CE0FF")),
		BackgroundGradient = ColorSequence.new(Color3.fromHex("25C4FE"), Color3.fromHex("9DE5FF")),
		Weight = 3,
		ValueMultiplier = 5,
		ReputationMultiplier = 2.5,
	},

	Rainbow = {
		Name = "Rainbow",
		Gradient = Rainbowgradient,
		BackgroundGradient = Rainbowgradient,
		Weight = 1,
		ValueMultiplier = 12,
		ReputationMultiplier = 5,
	},
}
