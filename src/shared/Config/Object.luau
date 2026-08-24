return {
	Variation = {
		MinimumPercent = 70,
		MaximumPercent = 130,
	},

	Offer = {
		Rarities = {
			"Common",
			"Uncommon",
			"Rare",
			"Epic",
			"Legendary",
			"Mythic",
		},
		ReputationTiers = {
			{
				MinimumReputation = 0,
				Chances = {
					Common = 80,
					Uncommon = 20,
				},
			},
			{
				MinimumReputation = 5,
				Chances = {
					Common = 60,
					Uncommon = 30,
					Rare = 10,
				},
			},
			{
				MinimumReputation = 15,
				Chances = {
					Common = 40,
					Uncommon = 35,
					Rare = 20,
					Epic = 5,
				},
			},
			{
				MinimumReputation = 30,
				Chances = {
					Common = 25,
					Uncommon = 30,
					Rare = 25,
					Epic = 15,
					Legendary = 5,
				},
			},
			{
				MinimumReputation = 60,
				Chances = {
					Common = 15,
					Uncommon = 25,
					Rare = 25,
					Epic = 20,
					Legendary = 12,
					Mythic = 3,
				},
			},
			{
				MinimumReputation = 100,
				Chances = {
					Common = 10,
					Uncommon = 15,
					Rare = 20,
					Epic = 25,
					Legendary = 20,
					Mythic = 10,
				},
			},
			{
				MinimumReputation = 200,
				Chances = {
					Common = 5,
					Uncommon = 10,
					Rare = 15,
					Epic = 25,
					Legendary = 25,
					Mythic = 20,
				},
			},
		},
	},

	Object = {
		OldSuitcase = {
			Name = "Old suitcase",
			MaxValue = 100,
			PriceMinValue = 35,
			PriceMaxValue = 90,
			IdImage = "rbxassetid://102276550411027",
			Rarity = "Common",
			Reputation = 2,
		},
	},
}
