return {
	GamePasses = {
		VIP = 2032874454,
		DoubleMoney = 2033642412,
		DoubleReputation = 2034290420,
	},

	CashProducts = {
		Cash1 = { Id = 3718400358, Amount = 2_500 },
		Cash2 = { Id = 3718400326, Amount = 12_000 },
		Cash3 = { Id = 3718400292, Amount = 60_000 },
		Cash4 = { Id = 3718400252, Amount = 250_000 },
	},

	SkipDayProductId = 3718400092,
	SkipCooldownProductId = 3718399727,
	CleanAllProductId = 3718399685,

	StarterPack = {
		Id = 2032868421,
		PurchaseType = "GamePass",
		Cash = 3_000,
		ObjectKey = "ElectricTrain",
		ReputationMultiplier = 2,
		ReputationDurationSeconds = 15 * 60,
	},

	ServerReputationLuck = {
		DurationPerPurchaseSeconds = 15 * 60,
		Levels = {
			{ Id = 3718400218, Multiplier = 2 },
			{ Id = 3718400186, Multiplier = 4 },
			{ Id = 3718400157, Multiplier = 8 },
		},
	},

	UpgradeDeveloperProducts = {
		CooldownReduction = 3718399770,
		PriceEstimation = 3718400476,
		DailyCustomers = 3718400442,
		PurchaseDiscount = 3718400405,
		DisplaySpace = 3718400498,
	},

	VIP = {
		SaleBonusPercent = 10,
		CustomerDiscountPercent = 5,
		ChatTag = "[VIP]",
	},
}
