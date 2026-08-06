local Lighting = game:GetService("Lighting")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(Replicatedstorage.Shared.Config.DayNight)

local Daynightservice = {
	Name = "DayNightService",
	Priority = 5,
}

function Daynightservice:Init()
	self.Starttime = Workspace:GetServerTimeNow()
	Lighting:SetAttribute("Day", 1)
	Lighting.ClockTime = Config.StartClockTime
end

function Daynightservice:Start()
	Runservice.Heartbeat:Connect(function()
		local Elapsed = Workspace:GetServerTimeNow() - self.Starttime
		local Dayprogress = Elapsed / Config.DayDuration
		local Day = math.floor(Dayprogress) + 1
		local Clocktime = (Config.StartClockTime + Dayprogress % 1 * 24) % 24
		Lighting.ClockTime = Clocktime
		if Lighting:GetAttribute("Day") ~= Day then
			Lighting:SetAttribute("Day", Day)
		end
	end)
end

return Daynightservice
