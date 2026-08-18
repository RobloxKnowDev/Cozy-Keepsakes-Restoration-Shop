local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Runservice = game:GetService("RunService")

local Daynightcontroller = {
	Name = "DayNightController",
	Priority = 7,
}

local function Formattime(Clocktime: number): string
	local Totalminutes = math.floor(Clocktime * 60) % 1440
	local Hour24 = math.floor(Totalminutes / 60)
	local Minutes = Totalminutes % 60
	if Minutes == 0 then
		return string.format("%02dh", Hour24)
	end
	return string.format("%02dh%02d", Hour24, Minutes)
end

function Daynightcontroller:Init()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local HUD = Playergui:WaitForChild("HUD")
	local Dayframe = HUD:WaitForChild("DayFrame")
	self.DayText = Dayframe:WaitForChild("DayText")
	self.TimeText = Dayframe:WaitForChild("TimeText")
end

function Daynightcontroller:Update()
	local Day = Lighting:GetAttribute("Day") or 1
	self.DayText.Text = "Day " .. tostring(Day)
	self.TimeText.Text = Formattime(Lighting.ClockTime)
end

function Daynightcontroller:Start()
	self:Update()
	Runservice.RenderStepped:Connect(function()
		self:Update()
	end)
end

return Daynightcontroller
