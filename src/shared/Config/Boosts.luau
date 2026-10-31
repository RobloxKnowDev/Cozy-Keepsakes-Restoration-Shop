local DailyRewards = require(script.Parent.DailyRewards)
local Rarity = require(script.Parent.Rarity)

local SaleBoost = DailyRewards.Rewards[4]

return {
	StarterReputation = {
		Title = "Luck Boost",
		Icon = "rbxassetid://140355094643401",
		Gradient = Rarity.Rare.Gradient,
	},

	ServerReputationLuck = {
		Title = "Server Luck",
		Description = "Better rare item luck for the whole server",
		Icon = "rbxassetid://114937702344454",
		Gradient = Rarity.Epic.Gradient,
	},

	DailySaleBoost = {
		Title = "Sell Boost",
		Description = string.format("+%d%% money on every sale", SaleBoost.Percent),
		Icon = "rbxassetid://131705537343553",
		Gradient = Rarity.Common.Gradient,
	},

	IndexSellBonus = {
		Title = "Index Sell Bonus",
		Icon = "rbxassetid://88682218694776",
		Gradient = Rarity.Common.Gradient,
	},

	VIP = {
		Title = "VIP",
		Icon = "rbxassetid://105316064080717",
		Gradient = Rarity.Legendary.Gradient,
	},

	FriendBoost = {
		Title = "Friend Boost",
		Icon = "rbxassetid://127587294585411",
		Gradient = Rarity.Common.Gradient,
		SellPercent = 10,
	},
}
