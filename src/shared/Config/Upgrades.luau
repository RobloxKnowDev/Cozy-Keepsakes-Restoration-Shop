local Monetization = require(script.Parent.Monetization)

return {
	PriceEstimation = {
		DisplayName = "Price Estimation",
		DefaultLevel = 0,
		DeveloperProductId = Monetization.UpgradeDeveloperProducts.PriceEstimation,
		CashPriceLevel1 = 200,
	},

	DailyCustomers = {
		DisplayName = "Daily Customers",
		DefaultLevel = 5,
		DeveloperProductId = Monetization.UpgradeDeveloperProducts.DailyCustomers,
		CashPriceLevel1 = 150,
	},

	PurchaseDiscount = {
		DisplayName = "Purchase Discount",
		MaxPercent = 10,
		DefaultLevel = 0,
		DeveloperProductId = Monetization.UpgradeDeveloperProducts.PurchaseDiscount,
		CashPriceLevel1 = 500,
	},
}
