return {
	Order = {
		"Common",
		"Rare",
		"Epic",
		"Legendary",
		"Mythic",
	},

	FullLuckReputation = 2200,
	LuckCurve = 0.5,
	MaximumLuck = 5,

	Common = {
		Name = "Common",
		Gradient = ColorSequence.new(Color3.fromHex("15FF00"), Color3.fromHex("90FF86")),
		Weight = 100,
	},

	Rare = {
		Name = "Rare",
		Gradient = ColorSequence.new(Color3.fromHex("0059FF"), Color3.fromHex("81C4FF")),
		Weight = 8,
	},

	Epic = {
		Name = "Epic",
		Gradient = ColorSequence.new(Color3.fromHex("9D00FF"), Color3.fromHex("D187FF")),
		Weight = 2,
	},

	Legendary = {
		Name = "Legendary",
		Gradient = ColorSequence.new(Color3.fromHex("FFD400"), Color3.fromHex("FFEB87")),
		Weight = 0.5,
	},

	Mythic = {
		Name = "Mythic",
		Gradient = ColorSequence.new(Color3.fromHex("FF0000"), Color3.fromHex("FF8787")),
		Weight = 0.1,
	},
}
