local Separatenumber = require(script.Parent.NumberAbbreviator)

local function FormatCurrency(Value: number): string
	local Rounded = math.round((tonumber(Value) or 0) * 100) / 100
	local Sign = if Rounded < 0 then "-" else ""
	local Absolute = math.abs(Rounded)
	local Integer = math.floor(Absolute)
	local Cents = math.round((Absolute - Integer) * 100)
	if Cents == 0 then
		return Sign .. "$" .. Separatenumber(Integer)
	end
	return string.format("%s$%s.%02d", Sign, Separatenumber(Integer), Cents)
end

return FormatCurrency
