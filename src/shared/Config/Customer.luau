local Customer = {
	SpawnIntervalSeconds = 60,
	MinimumIntervalSeconds = 30,
	SecondsPerCooldownLevel = 5,
	SkipArrivalSeconds = 4,
	SkipMarginSeconds = 6,
	DeclineDelaySeconds = 8,
	FreeDeclineReputation = {
		Common = 22,
		Rare = 1000,
	},
	StarterOffers = {
		{ Purchase = 1, Rarity = "Rare", Mutation = "Gold", Floor = 100 },
		{ Purchase = 5, Rarity = "Epic", Floor = 300 },
	},
	StarterPriceShare = 0.8,
	QuickStarterPurchases = 3,
}

function Customer.GetInterval(Level: number): number
	local Reduction = math.max(Level, 0) * Customer.SecondsPerCooldownLevel
	return math.max(Customer.SpawnIntervalSeconds - Reduction, Customer.MinimumIntervalSeconds)
end

function Customer.GetSkipThreshold(): number
	return math.max(Customer.SkipArrivalSeconds + Customer.SkipMarginSeconds, Customer.DeclineDelaySeconds)
end

return Customer
