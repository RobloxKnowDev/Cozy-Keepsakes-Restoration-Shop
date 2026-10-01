local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.Monetization)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local Home = {}
local GainColor = Color3.fromRGB(126, 255, 145)
local LossColor = Color3.fromRGB(255, 138, 138)
local ReputationBoostColor = Color3.fromRGB(255, 228, 77)

local function FormatBoostDuration(Seconds: number): string
	local Total = math.ceil(Seconds)
	if Total < 60 then
		return string.format("%d s", Total)
	end
	if Total % 60 == 0 then
		return string.format("%d min", Total // 60)
	end
	return string.format("%d min %d s", Total // 60, Total % 60)
end

function Home.ApplyReputationBoost(Controller, State)
	Controller.reputationText.TextColor3 = if (tonumber(State.ReputationMultiplier) or 1) > 1
		then ReputationBoostColor
		else Controller.baseReputationTextColor
	local BoostController = Core:GetController("BoostController")
	BoostController:SetBoost(
		"StarterReputation",
		State.PersonalReputationBoostEndsAt,
		1,
		nil,
		string.format(
			"x%d on your global reputation for %s",
			MonetizationConfig.StarterPack.ReputationMultiplier,
			FormatBoostDuration(State.PersonalReputationBoostDuration)
		)
	)
	BoostController:SetBoost("ServerReputationLuck", State.ServerLuckEndsAt, 2, State.ServerLuckMultiplier)
end

function Home.Init(Controller)
	Controller.statsFrame = Controller.homePage:WaitForChild("StatsFrame")
	Controller.itemsText = Controller.statsFrame:WaitForChild("SoldFrame"):WaitForChild("NumberText")
	Controller.reputationText = Controller.statsFrame:WaitForChild("ReputationFrame"):WaitForChild("NumberText")
	Controller.dailyProfitText = Controller.statsFrame:WaitForChild("DailyFrame"):WaitForChild("NumberText")
	Controller.baseReputationTextColor = Controller.reputationText.TextColor3
	Controller.baseDailyProfitTextColor = Controller.dailyProfitText.TextColor3
	Home.ApplyStats(Controller, RemoteManager:InvokeServer("StatsService", "GetStats"))
	Home.ApplyReputationBoost(Controller, RemoteManager:InvokeServer("MonetizationService", "GetShopState"))
end

function Home.ApplyStats(Controller, Stats)
	local Profit = Stats.DailyProfit or 0
	Controller.itemsText.Text = tostring(Stats.ItemsSold or 0)
	Controller.reputationText.Text = tostring(Stats.Reputation or 0)
	Controller.dailyProfitText.Text = Shared.FormatProfit(Profit)
	Controller.dailyProfitText.TextColor3 = if Profit > 0 then GainColor elseif Profit < 0 then LossColor else Controller.baseDailyProfitTextColor
end

function Home.Start(Controller)
	RemoteManager:OnClientEvent("StatsService", "StatsUpdated", function(Stats)
		Home.ApplyStats(Controller, Stats)
	end)
	RemoteManager:OnClientEvent("MonetizationService", "ShopStateUpdated", function(State)
		Home.ApplyReputationBoost(Controller, State)
	end)
end

return Home
