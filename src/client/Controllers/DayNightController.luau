local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Runservice = game:GetService("RunService")

local Daynightcontroller = {
	Name = "DayNightController",
	Priority = 7,
}

local function Findtext(Parent: Instance, Name: string): TextLabel | TextButton | TextBox
	local Instance = Parent:FindFirstChild(Name, true)
	assert(Instance and (Instance:IsA("TextLabel") or Instance:IsA("TextButton") or Instance:IsA("TextBox")), Name .. " introuvable dans DayFrame")
	return Instance
end

local function Formattime(Clocktime: number): string
	local Totalminutes = math.floor(Clocktime * 60 + 0.5) % 1440
	local Hour24 = math.floor(Totalminutes / 60)
	local Minutes = Totalminutes % 60
	local Hour12 = Hour24 % 12
	if Hour12 == 0 then Hour12 = 12 end
	return string.format("%d:%02d", Hour12, Minutes)
end

function Daynightcontroller:Init()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local HUD = Playergui:WaitForChild("HUD")
	local Dayframe = HUD:FindFirstChild("DayFrame", true)
	assert(Dayframe, "DayFrame introuvable dans HUD")
	self.DayText = Findtext(Dayframe, "DayText")
	self.TimeText = Findtext(Dayframe, "TimeText")
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
