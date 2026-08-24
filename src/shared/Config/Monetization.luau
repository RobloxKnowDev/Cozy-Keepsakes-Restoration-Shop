return {
	GamePasses = {
		VIP = 1948647642,
		DoubleMoney = 1948869685,
	},

	CashProducts = {
		Cash1 = { Id = 3708631458, Amount = 2_500 },
		Cash2 = { Id = 3708631478, Amount = 15_000 },
		Cash3 = { Id = 3708631495, Amount = 200_000 },
		Cash4 = { Id = 3708631522, Amount = 1_000_000 },
	},

	SkipDayProductId = 3709374250,

	StarterPack = {
		Id =  1949649693, 
		PurchaseType = "GamePass",
		Cash = 1_000,
		ObjectKey = "OldSuitcase",
		ReputationMultiplier = 2,
		ReputationDurationSeconds = 10 * 60,
	},

	ServerReputationLuck = {
		DurationPerPurchaseSeconds = 15 * 60,
		Levels = {
			{ Id = 3708631611, Multiplier = 2 },
			{ Id = 3708631623, Multiplier = 4 },
			{ Id = 3708631649, Multiplier = 8 },
		},
	},

	UpgradeDeveloperProducts = {
		PriceEstimation = 3708293655,
		DailyCustomers = 3708293711,
		PurchaseDiscount = 3708293785,
		DisplaySpace = 3708293275,
	},

	VIP = {
		SaleBonusPercent = 10,
		CustomerDiscountPercent = 5,
		ChatTag = "[VIP]",
	},
}
