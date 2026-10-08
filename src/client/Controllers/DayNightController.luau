local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Core = require(Replicatedstorage.Shared.Packages.Core)
local Runservice = game:GetService("RunService")

local Daynightconfig = require(Replicatedstorage.Shared.Config.DayNight)
local Monetizationconfig = require(Replicatedstorage.Shared.Config.Monetization)
local Rarityconfig = require(Replicatedstorage.Shared.Config.Rarity)
local Dayclock = require(Replicatedstorage.Shared.Utils.DayClock)
local Uifade = require(Replicatedstorage.Shared.Utils.UiFade)

local Daynightcontroller = {
	Name = "DayNightController",
	Priority = 7,
}

local Player = Players.LocalPlayer
local Robuxicon = ""

local Messagegradient = Rarityconfig.Common.Gradient
local Clock: Dayclock.Clock = {
	Offset = 0,
	WarpStart = 0,
	WarpDuration = 0,
	WarpFrom = 0,
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
	self.HourText = Dayframe:WaitForChild("HourText")
	self.SkipButton = Dayframe:WaitForChild("SkipButton") :: GuiButton
	self.RobuxText = self.SkipButton:WaitForChild("RobuxText") :: TextLabel
	Loadskipdayprice(self.RobuxText)
	Uifade.BindButton(self.SkipButton)
	Core:GetController("GamepadController"):OnActivated(self.SkipButton, function()
		MarketplaceService:PromptProductPurchase(Player, Monetizationconfig.SkipDayProductId)
	end)
end

function Daynightcontroller:Update()
	local Now = workspace:GetServerTimeNow()
	Clock.Offset = Player:GetAttribute("DayOffset") or 0
	Clock.WarpStart = Player:GetAttribute("DayWarpStart") or 0
	Clock.WarpDuration = Player:GetAttribute("DayWarpDuration") or 0
	Clock.WarpFrom = Player:GetAttribute("DayWarpFrom") or 0
	local Clocktime = Lighting.ClockTime
	local Starttime = Lighting:GetAttribute("DayCycleStartTime")
	if Starttime then
		Clocktime = Dayclock.GetClockTime(Now - Starttime + Dayclock.GetOffset(Clock, Now))
		Lighting.ClockTime = Clocktime
	end
	local Day = Player:GetAttribute("Day") or 1
	self.DayText.Text = "Day " .. tostring(Day)
	self.HourText.Text = Formattime(Clocktime)
	local Showskip = (Clocktime >= Daynightconfig.SkipDayAvailableHour or Clocktime < Daynightconfig.DayStartHour)
		and not Dayclock.IsWarping(Clock, Now)
		and not Player:GetAttribute("CustomersDone")
		and not self.ComputerController:IsOpen()
	if Uifade.SetVisible(self.SkipButton, Showskip) and Showskip then
		Uifade.Pop(self.SkipButton)
	end
	Uifade.SetVisible(self.RobuxText, Showskip)
end

function Daynightcontroller:Start()
	self.ComputerController = Core:GetController("ComputerController")
	local Messagecontroller = Core:GetController("MessageController")
	self.Lastday = Player:GetAttribute("Day")
	Player:GetAttributeChangedSignal("Day"):Connect(function()
		local Day = Player:GetAttribute("Day")
		if self.Lastday and Day > self.Lastday then
			Messagecontroller:Show("A new day begins!", Messagegradient)
		end
		self.Lastday = Day
	end)
	Player:GetAttributeChangedSignal("CustomersDone"):Connect(function()
		if Player:GetAttribute("CustomersDone") then
			Messagecontroller:Show(
				"All of today's customers have been served! The shop reopens tomorrow morning.",
				Messagegradient
			)
		end
	end)
	self:Update()
	Runservice.RenderStepped:Connect(function()
		self:Update()
	end)
end

return Daynightcontroller
