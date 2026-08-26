local Lighting = game:GetService("Lighting")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(Replicatedstorage.Shared.Config.DayNight)

local Daynightservice = {
	Name = "DayNightService",
	Priority = 5,
}

local Daytimehours = Config.NightStartHour - Config.DayStartHour
local Nighttimehours = 24 - Daytimehours
local Nighttimeduration = Config.DayDuration - Config.DaytimeDuration
local Midnightoffset = Config.DaytimeDuration
	+ Nighttimeduration * ((24 - Config.NightStartHour) / Nighttimehours)

local function Getclocktime(Cycleelapsed: number): number
	if Cycleelapsed < Config.DaytimeDuration then
		local Progress = Cycleelapsed / Config.DaytimeDuration
		return Config.DayStartHour + Progress * Daytimehours
	end

	local Progress = (Cycleelapsed - Config.DaytimeDuration) / Nighttimeduration
	return (Config.NightStartHour + Progress * Nighttimehours) % 24
end

local function Getday(Elapsed: number): number
	if Elapsed < Midnightoffset then
		return 1
	end

	return math.floor((Elapsed - Midnightoffset) / Config.DayDuration) + 2
end

function Daynightservice:Init()
	self.Starttime = Workspace:GetServerTimeNow()
	Lighting:SetAttribute("Day", 1)
	Lighting:SetAttribute("DayCycleStartTime", self.Starttime)
	Lighting.ClockTime = Config.StartClockTime
end

function Daynightservice:SkipToNextDayStart(): boolean
	local Currenttime = Workspace:GetServerTimeNow()
	local Elapsed = Currenttime - self.Starttime
	local Targetelapsed = (math.floor(Elapsed / Config.DayDuration) + 1) * Config.DayDuration
	self.Starttime = Currenttime - Targetelapsed
	Lighting:SetAttribute("DayCycleStartTime", self.Starttime)
	Lighting.ClockTime = Config.DayStartHour

	local Day = Getday(Targetelapsed)
	if Lighting:GetAttribute("Day") ~= Day then
		Lighting:SetAttribute("Day", Day)
	end
	return true
end

function Daynightservice:Start()
	Runservice.Heartbeat:Connect(function()
		local Elapsed = Workspace:GetServerTimeNow() - self.Starttime
		local Cycleelapsed = Elapsed % Config.DayDuration
		local Day = Getday(Elapsed)
		local Clocktime = Getclocktime(Cycleelapsed)
		Lighting.ClockTime = Clocktime
		if Lighting:GetAttribute("Day") ~= Day then
			Lighting:SetAttribute("Day", Day)
		end
	end)
end

return Daynightservice
