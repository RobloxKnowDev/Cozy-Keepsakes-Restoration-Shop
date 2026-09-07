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
		Color = Color3.fromRGB(255, 255, 255),
		Weight = 88,
		ValueMultiplier = 1,
		ReputationMultiplier = 1,
	},

	Gold = {
		Name = "Gold",
		Color = Color3.fromRGB(255, 224, 90),
		Weight = 8,
		ValueMultiplier = 2,
		ReputationMultiplier = 1.5,
	},

	Diamond = {
		Name = "Diamond",
		Color = Color3.fromRGB(37, 196, 254),
		Weight = 3,
		ValueMultiplier = 5,
		ReputationMultiplier = 2.5,
	},

	Rainbow = {
		Name = "Rainbow",
		Color = Color3.fromRGB(255, 105, 205),
		Weight = 1,
		ValueMultiplier = 12,
		ReputationMultiplier = 5,
	},
}
