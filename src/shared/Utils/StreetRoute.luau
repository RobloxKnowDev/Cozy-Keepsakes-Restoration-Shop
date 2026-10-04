local Streetroute = {}

local function Spline(Before: Vector3, Start: Vector3, Finish: Vector3, After: Vector3, T: number): Vector3
	return (
		Start * 2
		+ (Finish - Before) * T
		+ (Before * 2 - Start * 5 + Finish * 4 - After) * T ^ 2
		+ (Start * 3 - Before - Finish * 3 + After) * T ^ 3
	) * 0.5
end

local function Tangent(Before: Vector3, Start: Vector3, Finish: Vector3, After: Vector3, T: number): Vector3
	return (
		(Finish - Before)
		+ (Before * 2 - Start * 5 + Finish * 4 - After) * (2 * T)
		+ (Start * 3 - Before - Finish * 3 + After) * (3 * T ^ 2)
	) * 0.5
end

local function Ease(T: number, Starting: boolean, Stopping: boolean): (number, number)
	if Starting and Stopping then
		return T * T * (3 - 2 * T), 6 * T * (1 - T)
	end
	if Stopping then
		return T + T ^ 2 - T ^ 3, 1 + 2 * T - 3 * T ^ 2
	end
	if Starting then
		return 2 * T ^ 2 - T ^ 3, 4 * T - 3 * T ^ 2
	end
	return T, 1
end

function Streetroute.Encode(Points: { Vector3 }, Holds: { number }, Looks: { [number]: Vector3 }): string
	local Entries = {}
	for Index, Point in ipairs(Points) do
		local Look = Looks[Index] or Points[Index + 1] or Point * 2 - Points[Index - 1]
		table.insert(
			Entries,
			string.format("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f", Point.X, Point.Y, Point.Z, Holds[Index], Look.X, Look.Z)
		)
	end
	return table.concat(Entries, ";")
end

function Streetroute.Decode(Route: string): ({ Vector3 }, { number }, { Vector3 })
	local Points = {}
	local Holds = {}
	local Looks = {}
	for X, Y, Z, Hold, Lookx, Lookz in string.gmatch(Route, "([^,;]+),([^,;]+),([^,;]+),([^,;]+),([^,;]+),([^,;]+)") do
		local Point = Vector3.new(tonumber(X), tonumber(Y), tonumber(Z))
		table.insert(Points, Point)
		table.insert(Holds, tonumber(Hold))
		table.insert(Looks, Vector3.new(tonumber(Lookx), Point.Y, tonumber(Lookz)))
	end
	return Points, Holds, Looks
end

function Streetroute.TimeTo(Points: { Vector3 }, Holds: { number }, Speed: number, Target: number): number
	local Total = 0
	for Index = 1, Target - 1 do
		Total += Holds[Index] + (Points[Index + 1] - Points[Index]).Magnitude / Speed
	end
	return Total
end

function Streetroute.Sample(
	Points: { Vector3 },
	Holds: { number },
	Looks: { Vector3 },
	Speed: number,
	Elapsed: number
): (Vector3, Vector3, boolean, number)
	local Remaining = Elapsed
	for Index = 1, #Points - 1 do
		if Remaining < Holds[Index] then
			return Points[Index], Looks[Index] - Points[Index], false, 0
		end
		Remaining -= Holds[Index]
		local Duration = (Points[Index + 1] - Points[Index]).Magnitude / Speed
		if Remaining < Duration then
			local Progress, Pace = Ease(Remaining / Duration, Holds[Index] > 0, Index + 1 == #Points or Holds[Index + 1] > 0)
			local Before = Points[Index - 1] or Points[Index]
			local After = Points[Index + 2] or Points[Index + 1]
			return Spline(Before, Points[Index], Points[Index + 1], After, Progress),
				Tangent(Before, Points[Index], Points[Index + 1], After, Progress),
				true,
				Pace
		end
		Remaining -= Duration
	end
	return Points[#Points], Looks[#Points] - Points[#Points], false, 0
end

return Streetroute
