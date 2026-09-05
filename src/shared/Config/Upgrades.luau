local Monetization = require(script.Parent.Monetization)

return {
	DisplaySpace = {
		DisplayName = "Display Space",
		DefaultLevel = 2,
		MaxLevel = 9,
		DeveloperProductId = Monetization.UpgradeDeveloperProducts.DisplaySpace,
		CashPriceLevel1 = 120,
		PriceGrowth = 1.7,
	},

	DailyCustomers = {
		DisplayName = "Daily Customers",
		DefaultLevel = 5,
		MaxLevel = 12,
		DeveloperProductId = Monetization.UpgradeDeveloperProducts.DailyCustomers,
		CashPriceLevel1 = 100,
		PriceGrowth = 1.55,
	},

	PriceEstimation = {
		DisplayName = "Price Estimation",
		DefaultLevel = 0,
		DeveloperProductId = Monetization.UpgradeDeveloperProducts.PriceEstimation,
		CashPriceLevel1 = 150,
		PriceGrowth = 1.45,
	},

	PurchaseDiscount = {
		DisplayName = "Purchase Discount",
		MaxPercent = 15,
		DefaultLevel = 0,
		DeveloperProductId = Monetization.UpgradeDeveloperProducts.PurchaseDiscount,
		CashPriceLevel1 = 350,
		PriceGrowth = 1.6,
	},
}
