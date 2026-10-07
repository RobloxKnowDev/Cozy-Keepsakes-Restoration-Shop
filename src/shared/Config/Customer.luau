local Customer = {
	SpawnIntervalSeconds = 90,
	MinimumIntervalSeconds = 30,
	SecondsPerCooldownLevel = 6,
	SkipArrivalSeconds = 4,
	SkipMarginSeconds = 6,
	DeclineDelaySeconds = 8,
	FreeDeclineReputation = {
		Common = 22,
		Rare = 1000,
	},
}

function Customer.GetInterval(Level: number): number
	local Reduction = math.max(Level, 0) * Customer.SecondsPerCooldownLevel
	return math.max(Customer.SpawnIntervalSeconds - Reduction, Customer.MinimumIntervalSeconds)
end

function Customer.GetSkipThreshold(): number
	return math.max(Customer.SkipArrivalSeconds + Customer.SkipMarginSeconds, Customer.DeclineDelaySeconds)
end

return Customer
