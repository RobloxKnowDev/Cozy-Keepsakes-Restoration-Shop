local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")

local Daynightconfig = require(Replicatedstorage.Shared.Config.DayNight)
local Monetizationconfig = require(Replicatedstorage.Shared.Config.Monetization)

local Daynightcontroller = {
	Name = "DayNightController",
	Priority = 7,
}

local Player = Players.LocalPlayer
local Robuxicon = ""

local function Formattime(Clocktime: number): string
	local Totalminutes = math.floor(Clocktime * 60) % 1440
	local Hour24 = math.floor(Totalminutes / 60)
	local Minutes = Totalminutes % 60
	if Minutes == 0 then
		return string.format("%02dh", Hour24)
	end
	return string.format("%02dh%02d", Hour24, Minutes)
end

local function Loadskipdayprice(Robuxtext: TextLabel)
	Robuxtext.Text = "..."
	task.spawn(function()
		local Success, Productinfo = pcall(function()
			return MarketplaceService:GetProductInfoAsync(Monetizationconfig.SkipDayProductId, Enum.InfoType.Product)
		end)
		local Price = if Success then tonumber(Productinfo.PriceInRobux) else nil
		Robuxtext.Text = if Price then string.format("%s%d", Robuxicon, math.floor(Price)) else "N/A"
	end)
end

function Daynightcontroller:Init()
	local Playergui = Player:WaitForChild("PlayerGui")
	local HUD = Playergui:WaitForChild("HUD")
	local Dayframe = HUD:WaitForChild("DayFrame")
	self.DayText = Dayframe:WaitForChild("DayText")
	self.TimeText = Dayframe:WaitForChild("TimeText")
	self.SkipButton = Dayframe:WaitForChild("SkipButton") :: GuiButton
	self.RobuxText = self.SkipButton:WaitForChild("RobuxText") :: TextLabel
	Loadskipdayprice(self.RobuxText)
	self.SkipButton.Activated:Connect(function()
		MarketplaceService:PromptProductPurchase(Player, Monetizationconfig.SkipDayProductId)
	end)
end

function Daynightcontroller:Update()
	local Day = Lighting:GetAttribute("Day") or 1
	local Clocktime = Lighting.ClockTime
	self.DayText.Text = "Day " .. tostring(Day)
	self.TimeText.Text = Formattime(Clocktime)
	self.SkipButton.Visible = Clocktime >= Daynightconfig.SkipDayAvailableHour or Clocktime < Daynightconfig.DayStartHour
end

function Daynightcontroller:Start()
	self:Update()
	Runservice.RenderStepped:Connect(function()
		self:Update()
	end)
end

return Daynightcontroller
