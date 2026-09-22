local DailyRewards = require(script.Parent.DailyRewards)
local Monetization = require(script.Parent.Monetization)

local SaleBoost = DailyRewards.Rewards[4]

return {
	StarterReputation = {
		Title = "Reputation Boost",
		Description = string.format("x%d reputation on every sale", Monetization.StarterPack.ReputationMultiplier),
	},

	ServerReputationLuck = {
		Title = "Server Luck",
		Description = "Better rare item luck for the whole server",
	},

	DailySaleBoost = {
		Title = "Sell Boost",
		Description = string.format("+%d%% money on every sale", SaleBoost.Percent),
	},
}
