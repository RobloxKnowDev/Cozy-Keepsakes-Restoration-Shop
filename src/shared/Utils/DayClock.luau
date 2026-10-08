local Replicatedstorage = game:GetService("ReplicatedStorage")

local Config = require(Replicatedstorage.Shared.Config.DayNight)

export type Clock = {
	Offset: number,
	WarpStart: number,
	WarpDuration: number,
	WarpFrom: number,
}

local Dayclock = {}

local Daytimehours = Config.NightStartHour - Config.DayStartHour
local Nighttimehours = 24 - Daytimehours
local Nighttimeduration = Config.DayDuration - Config.DaytimeDuration

local function Ease(Alpha: number): number
	if Alpha < 0.5 then
		return 2 * Alpha * Alpha
	end
	return 1 - (2 - 2 * Alpha) ^ 2 / 2
end

function Dayclock.GetClockTime(Elapsed: number): number
	local Cycleelapsed = Elapsed % Config.DayDuration
	if Cycleelapsed < Config.DaytimeDuration then
		local Progress = Cycleelapsed / Config.DaytimeDuration
		return Config.DayStartHour + Progress * Daytimehours
	end

	local Progress = (Cycleelapsed - Config.DaytimeDuration) / Nighttimeduration
	return (Config.NightStartHour + Progress * Nighttimehours) % 24
end

function Dayclock.GetDay(Elapsed: number): number
	return math.floor(Elapsed / Config.DayDuration) + 1
end

function Dayclock.GetNextDayStart(Elapsed: number): number
	return (math.floor(Elapsed / Config.DayDuration) + 1) * Config.DayDuration
end

function Dayclock.IsBusinessHours(Clocktime: number): boolean
	return Clocktime >= Config.DayStartHour and Clocktime < Config.NightStartHour
end

function Dayclock.IsWarping(Clock: Clock, Now: number): boolean
	return Now < Clock.WarpStart + Clock.WarpDuration
end

function Dayclock.GetOffset(Clock: Clock, Now: number): number
	if not Dayclock.IsWarping(Clock, Now) then
		return Clock.Offset
	end
	if Now <= Clock.WarpStart then
		return Clock.WarpFrom
	end
	return Clock.WarpFrom + (Clock.Offset - Clock.WarpFrom) * Ease((Now - Clock.WarpStart) / Clock.WarpDuration)
end

function Dayclock.GetFastForwardDuration(Elapsed: number): number
	local Hours = 24 - (Dayclock.GetClockTime(Elapsed) - Config.DayStartHour) % 24
	local Duration = math.clamp(
		Hours * Config.FastForwardSecondsPerHour,
		Config.FastForwardMinDuration,
		Config.FastForwardMaxDuration
	)
	return math.min(Duration, Dayclock.GetNextDayStart(Elapsed) - Elapsed)
end

return Dayclock
