local DailyRewards = require(script.Parent.DailyRewards)

local SaleBoost = DailyRewards.Rewards[4]

return {
	StarterReputation = {
		Title = "Reputation Boost",
		Icon = "rbxassetid://140355094643401",
	},

	ServerReputationLuck = {
		Title = "Server Luck",
		Description = "Better rare item luck for the whole server",
		Icon = "rbxassetid://114937702344454",
	},

	DailySaleBoost = {
		Title = "Sell Boost",
		Description = string.format("+%d%% money on every sale", SaleBoost.Percent),
		Icon = "rbxassetid://131705537343553",
	},

	IndexSellBonus = {
		Title = "Index Sell Bonus",
		Icon = "rbxassetid://88682218694776",
	},
}
