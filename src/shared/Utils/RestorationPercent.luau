local function RestorationPercent(Ratio: number): number
	if Ratio >= 1 then
		return 100
	end
	return math.min(math.floor(Ratio * 100 + 0.5), 99)
end

return RestorationPercent
