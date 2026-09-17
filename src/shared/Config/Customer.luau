local Customer = {
	SpawnIntervalSeconds = 90,
	MinimumIntervalSeconds = 30,
	SecondsPerCooldownLevel = 6,
}

function Customer.GetInterval(Level: number): number
	local Reduction = math.max(Level, 0) * Customer.SecondsPerCooldownLevel
	return math.max(Customer.SpawnIntervalSeconds - Reduction, Customer.MinimumIntervalSeconds)
end

return Customer
