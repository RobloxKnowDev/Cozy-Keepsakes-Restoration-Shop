local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(Replicatedstorage.Shared.Config.DayNight)
local Dayclock = require(Replicatedstorage.Shared.Utils.DayClock)

local Daynightservice = {
	Name = "DayNightService",
	Priority = 5,
	Starttime = Workspace:GetServerTimeNow(),
	DayChanged = Instance.new("BindableEvent"),
}

type PlayerClock = {
	Offset: number,
	WarpStart: number,
	WarpDuration: number,
	WarpFrom: number,
	Day: number,
}

local Clocks: { [Player]: PlayerClock } = {}
local Savedoffsets: { [number]: number } = {}

local function Getclock(Player: Player): PlayerClock
	local Existing = Clocks[Player]
	if Existing then
		return Existing
	end

	local Offset = Savedoffsets[Player.UserId] or 0
	local Clock: PlayerClock = {
		Offset = Offset,
		WarpStart = 0,
		WarpDuration = 0,
		WarpFrom = 0,
		Day = Dayclock.GetDay(Workspace:GetServerTimeNow() - Daynightservice.Starttime + Offset),
	}
	if Player.Parent then
		Clocks[Player] = Clock
		Player:SetAttribute("DayWarpFrom", Clock.WarpFrom)
		Player:SetAttribute("DayWarpDuration", Clock.WarpDuration)
		Player:SetAttribute("DayWarpStart", Clock.WarpStart)
		Player:SetAttribute("DayOffset", Clock.Offset)
		Player:SetAttribute("Day", Clock.Day)
	end
	return Clock
end

function Daynightservice:Init()
	Lighting:SetAttribute("Day", 1)
	Lighting:SetAttribute("DayCycleStartTime", self.Starttime)
	Lighting.ClockTime = Config.StartClockTime
	for _, Player in ipairs(Players:GetPlayers()) do
		Getclock(Player)
	end
	Players.PlayerAdded:Connect(Getclock)
	Players.PlayerRemoving:Connect(function(Player)
		Savedoffsets[Player.UserId] = Getclock(Player).Offset
		task.defer(function()
			Clocks[Player] = nil
		end)
	end)
end

function Daynightservice:GetElapsed(Player: Player?): number
	local Now = Workspace:GetServerTimeNow()
	if Player then
		return Now - self.Starttime + Dayclock.GetOffset(Getclock(Player), Now)
	end
	return Now - self.Starttime
end

function Daynightservice:GetClockTime(Player: Player?): number
	return Dayclock.GetClockTime(self:GetElapsed(Player))
end

function Daynightservice:GetDay(Player: Player?): number
	return Dayclock.GetDay(self:GetElapsed(Player))
end

function Daynightservice:IsBusinessHours(Player: Player?): boolean
	return Dayclock.IsBusinessHours(self:GetClockTime(Player))
end

function Daynightservice:IsFastForwarding(Player: Player): boolean
	return Dayclock.IsWarping(Getclock(Player), Workspace:GetServerTimeNow())
end

function Daynightservice:FastForward(Player: Player): boolean
	if not Player.Parent or self:IsFastForwarding(Player) then
		return false
	end

	local Clock = Getclock(Player)
	local Now = Workspace:GetServerTimeNow()
	local Elapsed = Now - self.Starttime + Clock.Offset
	local Duration = Dayclock.GetFastForwardDuration(Elapsed)
	Clock.WarpFrom = Clock.Offset
	Clock.WarpDuration = Duration
	Clock.WarpStart = Now
	Clock.Offset += Dayclock.GetNextDayStart(Elapsed) - Elapsed - Duration
	Player:SetAttribute("DayWarpFrom", Clock.WarpFrom)
	Player:SetAttribute("DayWarpDuration", Clock.WarpDuration)
	Player:SetAttribute("DayWarpStart", Clock.WarpStart)
	Player:SetAttribute("DayOffset", Clock.Offset)
	return true
end

function Daynightservice:SkipToNextDayStart(Player: Player): boolean
	local Clock = Getclock(Player)
	local Now = Workspace:GetServerTimeNow()
	local Offset = Dayclock.GetOffset(Clock, Now)
	local Elapsed = Now - self.Starttime + Offset
	Clock.Offset = Offset + Dayclock.GetNextDayStart(Elapsed) - Elapsed
	Clock.WarpStart = 0
	Clock.WarpDuration = 0
	Clock.WarpFrom = 0
	Player:SetAttribute("DayOffset", Clock.Offset)
	Player:SetAttribute("DayWarpStart", Clock.WarpStart)
	Player:SetAttribute("DayWarpDuration", Clock.WarpDuration)
	Player:SetAttribute("DayWarpFrom", Clock.WarpFrom)
	return true
end

function Daynightservice:Start()
	Runservice.Heartbeat:Connect(function()
		local Now = Workspace:GetServerTimeNow()
		local Elapsed = Now - self.Starttime
		local Day = Dayclock.GetDay(Elapsed)
		Lighting.ClockTime = Dayclock.GetClockTime(Elapsed)
		if Lighting:GetAttribute("Day") ~= Day then
			Lighting:SetAttribute("Day", Day)
		end
		for Player, Clock in pairs(Clocks) do
			local Playerday = Dayclock.GetDay(Elapsed + Dayclock.GetOffset(Clock, Now))
			if Playerday ~= Clock.Day then
				Clock.Day = Playerday
				Player:SetAttribute("Day", Playerday)
				self.DayChanged:Fire(Player, Playerday)
			end
		end
	end)
end

return Daynightservice
