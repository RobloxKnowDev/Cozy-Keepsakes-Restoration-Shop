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
		{ Reputation = 150, Common = 46, Rare = 38, Epic = 15, Legendary = 1, Mythic = 0 },
		{ Reputation = 400, Common = 39, Rare = 41, Epic = 17, Legendary = 3, Mythic = 0 },
		{ Reputation = 1000, Common = 32, Rare = 43, Epic = 20, Legendary = 4.6, Mythic = 0.4 },
		{ Reputation = 2200, Common = 26, Rare = 44, Epic = 23, Legendary = 6, Mythic = 1 },
		{ Reputation = 4400, Common = 21, Rare = 44, Epic = 26, Legendary = 7.5, Mythic = 1.5 },
		{ Reputation = 8000, Common = 18, Rare = 43, Epic = 28, Legendary = 9, Mythic = 2 },
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
