return {
	Order = {
		"Common",
		"Rare",
		"Epic",
		"Legendary",
		"Mythic",
	},

	MaxCommonStreak = 5,
	OfferRerolls = 3,
	UnaffordableKeepChance = 0.25,

	Tiers = {
		{ Reputation = 0, Common = 67, Rare = 28, Epic = 5, Legendary = 0, Mythic = 0 },
		{ Reputation = 50, Common = 55, Rare = 32, Epic = 13, Legendary = 0, Mythic = 0 },
		{ Reputation = 150, Common = 34, Rare = 43, Epic = 17, Legendary = 6, Mythic = 0 },
		{ Reputation = 400, Common = 20, Rare = 48, Epic = 19, Legendary = 10, Mythic = 3 },
		{ Reputation = 1000, Common = 12, Rare = 37, Epic = 30, Legendary = 14, Mythic = 7 },
		{ Reputation = 2200, Common = 8, Rare = 22, Epic = 40, Legendary = 17, Mythic = 13 },
		{ Reputation = 4400, Common = 6, Rare = 14, Epic = 40, Legendary = 20, Mythic = 20 },
	},

	Common = {
		Name = "Common",
		Gradient = ColorSequence.new(Color3.fromHex("15FF00"), Color3.fromHex("90FF86")),
	},

	Rare = {
		Name = "Rare",
		Gradient = ColorSequence.new(Color3.fromHex("0059FF"), Color3.fromHex("81C4FF")),
	},

	Epic = {
		Name = "Epic",
		Gradient = ColorSequence.new(Color3.fromHex("9D00FF"), Color3.fromHex("D187FF")),
	},

	Legendary = {
		Name = "Legendary",
		Gradient = ColorSequence.new(Color3.fromHex("FFD400"), Color3.fromHex("FFEB87")),
	},

	Mythic = {
		Name = "Mythic",
		Gradient = ColorSequence.new(Color3.fromHex("FF0000"), Color3.fromHex("FF8787")),
	},
}
