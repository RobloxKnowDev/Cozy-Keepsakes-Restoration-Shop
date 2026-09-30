return {
	TaskCount = 3,
	Families = {
		Clock = { "AlarmClock", "WallClock", "MantelClock", "CuckooClock" },
		Toy = { "ToyCar", "ElectricTrain" },
		Antique = { "AntiqueGlasses", "AntiqueSafe", "AntiqueTelescope", "AntiqueStatue" },
		Household = { "Teapot", "KitchenScale", "ClothesIron", "Vase", "RetroFan", "SewingMachine" },
	},
	Tasks = {
		BuyItems = {
			Event = "Buy",
			Text = "Buy %s items",
			Tiers = {
				{ Goal = 3, Reward = 100 },
				{ Goal = 5, Reward = 175 },
				{ Goal = 8, Reward = 300, MinimumSold = 15 },
			},
		},
		SpendCash = {
			Event = "Buy",
			Text = "Spend %s on items",
			Measure = "Value",
			Currency = true,
			Tiers = {
				{ Goal = 150, Reward = 100 },
				{ Goal = 400, Reward = 200, MinimumSold = 10 },
				{ Goal = 1500, Reward = 450, MinimumSold = 30 },
			},
		},
		BuyRare = {
			Event = "Buy",
			Text = "Buy a Rare+ item",
			Rarity = "Rare",
			Tiers = {
				{ Goal = 1, Reward = 250, MinimumSold = 10 },
			},
		},
		BuyClock = {
			Event = "Buy",
			Text = "Buy a clock",
			Family = "Clock",
			Tiers = {
				{ Goal = 1, Reward = 125 },
			},
		},
		BuyToy = {
			Event = "Buy",
			Text = "Buy a toy",
			Family = "Toy",
			Tiers = {
				{ Goal = 1, Reward = 125 },
			},
		},
		BuyAntique = {
			Event = "Buy",
			Text = "Buy an antique",
			Family = "Antique",
			Tiers = {
				{ Goal = 1, Reward = 125 },
			},
		},
		BuyHousehold = {
			Event = "Buy",
			Text = "Buy %s household items",
			Family = "Household",
			Tiers = {
				{ Goal = 2, Reward = 100 },
				{ Goal = 4, Reward = 175 },
			},
		},
		CleanDirt = {
			Event = "Clean",
			Text = "Clean %s dirt patches",
			Tiers = {
				{ Goal = 6, Reward = 100 },
				{ Goal = 12, Reward = 175 },
				{ Goal = 20, Reward = 300 },
			},
		},
		ScrubWithBrush = {
			Event = "Clean",
			Text = "Scrub %s dirt patches with the brush",
			Tool = "ToothBrush",
			Tiers = {
				{ Goal = 4, Reward = 125 },
				{ Goal = 8, Reward = 225 },
			},
		},
		WipeWithCotton = {
			Event = "Clean",
			Text = "Wipe %s dirt patches with the cotton",
			Tool = "CottonTip",
			Tiers = {
				{ Goal = 4, Reward = 125 },
				{ Goal = 8, Reward = 225 },
			},
		},
		RestoreItems = {
			Event = "Restore",
			Text = "Fully restore %s items",
			Tiers = {
				{ Goal = 2, Reward = 150 },
				{ Goal = 4, Reward = 250 },
				{ Goal = 6, Reward = 400, MinimumSold = 15 },
			},
		},
		RestoreInOneGo = {
			Event = "Restore",
			Text = "Fully restore %s items in one go",
			FromScratch = true,
			Tiers = {
				{ Goal = 2, Reward = 175 },
				{ Goal = 3, Reward = 250 },
			},
		},
		RestoreValue = {
			Event = "Restore",
			Text = "Restore items worth %s",
			Measure = "Value",
			Currency = true,
			Tiers = {
				{ Goal = 250, Reward = 125 },
				{ Goal = 600, Reward = 250 },
				{ Goal = 2000, Reward = 450, MinimumSold = 15 },
			},
		},
		RestoreRare = {
			Event = "Restore",
			Text = "Fully restore a Rare+ item",
			Rarity = "Rare",
			Tiers = {
				{ Goal = 1, Reward = 300, MinimumSold = 10 },
			},
		},
		RestoreMutated = {
			Event = "Restore",
			Text = "Fully restore a mutated item",
			Mutated = true,
			Tiers = {
				{ Goal = 1, Reward = 300, MinimumSold = 10 },
			},
		},
		RestoreClock = {
			Event = "Restore",
			Text = "Fully restore a clock",
			Family = "Clock",
			Tiers = {
				{ Goal = 1, Reward = 175 },
			},
		},
		RestoreToy = {
			Event = "Restore",
			Text = "Fully restore a toy",
			Family = "Toy",
			Tiers = {
				{ Goal = 1, Reward = 175 },
			},
		},
		RestoreAntique = {
			Event = "Restore",
			Text = "Fully restore an antique",
			Family = "Antique",
			Tiers = {
				{ Goal = 1, Reward = 175 },
			},
		},
		RestoreHousehold = {
			Event = "Restore",
			Text = "Fully restore %s household items",
			Family = "Household",
			Tiers = {
				{ Goal = 2, Reward = 150 },
				{ Goal = 3, Reward = 225 },
			},
		},
		SellItems = {
			Event = "Sell",
			Text = "Sell %s items",
			Tiers = {
				{ Goal = 3, Reward = 150 },
				{ Goal = 5, Reward = 225 },
				{ Goal = 8, Reward = 350, MinimumSold = 15 },
			},
		},
		EarnCash = {
			Event = "Sell",
			Text = "Earn %s from sales",
			Measure = "Value",
			Currency = true,
			Tiers = {
				{ Goal = 300, Reward = 200 },
				{ Goal = 750, Reward = 300, MinimumSold = 10 },
				{ Goal = 2500, Reward = 600, MinimumSold = 30 },
			},
		},
		MakeProfit = {
			Event = "Sell",
			Text = "Make %s profit from sales",
			Measure = "Profit",
			Currency = true,
			Tiers = {
				{ Goal = 150, Reward = 150 },
				{ Goal = 400, Reward = 250, MinimumSold = 10 },
				{ Goal = 1500, Reward = 500, MinimumSold = 30 },
			},
		},
		SellValuable = {
			Event = "Sell",
			Text = "Sell an item for %s",
			Measure = "Value",
			Single = true,
			Currency = true,
			Tiers = {
				{ Goal = 100, Reward = 125 },
				{ Goal = 500, Reward = 300, MinimumSold = 15 },
			},
		},
		SellRare = {
			Event = "Sell",
			Text = "Sell a Rare+ item",
			Rarity = "Rare",
			Tiers = {
				{ Goal = 1, Reward = 350, MinimumSold = 10 },
			},
		},
		SellMutated = {
			Event = "Sell",
			Text = "Sell a mutated item",
			Mutated = true,
			Tiers = {
				{ Goal = 1, Reward = 300, MinimumSold = 10 },
			},
		},
		DisplayRestored = {
			Event = "Display",
			Text = "Display a restored item",
			Restored = true,
			Tiers = {
				{ Goal = 1, Reward = 100 },
			},
		},
		DisplayRare = {
			Event = "Display",
			Text = "Display a restored Rare+ item",
			Rarity = "Rare",
			Restored = true,
			Tiers = {
				{ Goal = 1, Reward = 250, MinimumSold = 15 },
			},
		},
		KeepShopOpen = {
			Event = "Day",
			Text = "Keep your shop open for %s days",
			Tiers = {
				{ Goal = 2, Reward = 100 },
				{ Goal = 4, Reward = 200 },
			},
		},
	},
}
