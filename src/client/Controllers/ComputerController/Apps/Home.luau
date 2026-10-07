local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.Monetization)
local RarityConfig = require(ReplicatedStorage.Shared.Config.Rarity)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local UiGradient = require(ReplicatedStorage.Shared.Utils.UiGradient)
local Shared = require(script.Parent.Shared)

local Home = {}

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

function Home.ApplyReputationBoost(State)
	local BoostController = Core:GetController("BoostController")
	BoostController:SetBoost(
		"StarterReputation",
		State.PersonalReputationBoostEndsAt,
		2,
		nil,
		string.format(
			"x%d on your global reputation for %s",
			MonetizationConfig.StarterPack.ReputationMultiplier,
			FormatBoostDuration(State.PersonalReputationBoostDuration)
		)
	)
	BoostController:SetBoost("ServerReputationLuck", State.ServerLuckEndsAt, 3, State.ServerLuckMultiplier)
end

function Home.ApplyVIP(State)
	local BoostController = Core:GetController("BoostController")
	if not State.OwnsVIP then
		BoostController:RemoveBoost("VIP")
		return
	end
	BoostController:SetPermanentBoost(
		"VIP",
		1,
		string.format("+%g%%", MonetizationConfig.VIP.SaleBonusPercent),
		string.format(
			"+%g%% on all sales, -%g%% on all purchases",
			MonetizationConfig.VIP.SaleBonusPercent,
			MonetizationConfig.VIP.CustomerDiscountPercent
		)
	)
end

function Home.Init(Controller)
	Controller.statsFrame = Controller.homePage:WaitForChild("StatsFrame")
	Controller.itemsText = Controller.statsFrame:WaitForChild("SoldFrame"):WaitForChild("NumberText")
	Controller.reputationText = Controller.statsFrame:WaitForChild("ReputationFrame"):WaitForChild("NumberText")
	Controller.dailyProfitText = Controller.statsFrame:WaitForChild("DailyFrame"):WaitForChild("NumberText")
	Controller.dailyProfitGradient = UiGradient.Ensure(Controller.dailyProfitText)
	Controller.dailyProfitBaseGradient = Controller.dailyProfitGradient.Color
	Home.ApplyStats(Controller, RemoteManager:InvokeServer("StatsService", "GetStats"))
	local ShopState = RemoteManager:InvokeServer("MonetizationService", "GetShopState")
	Home.ApplyReputationBoost(ShopState)
	Home.ApplyVIP(ShopState)
end

function Home.ApplyStats(Controller, Stats)
	local Profit = Stats.DailyProfit or 0
	Controller.itemsText.Text = tostring(Stats.ItemsSold or 0)
	Controller.reputationText.Text = tostring(Stats.Reputation or 0)
	Controller.dailyProfitText.Text = Shared.FormatProfit(Profit)
	Controller.dailyProfitGradient.Color = if Profit < 0 then RarityConfig.Mythic.Gradient else Controller.dailyProfitBaseGradient
end

function Home.Start(Controller)
	RemoteManager:OnClientEvent("StatsService", "StatsUpdated", function(Stats)
		Home.ApplyStats(Controller, Stats)
	end)
	RemoteManager:OnClientEvent("MonetizationService", "ShopStateUpdated", function(State, Granted)
		Home.ApplyReputationBoost(State)
		Home.ApplyVIP(State)
		if Granted then
			Core:GetController("BoostController"):PlayGain(Granted, true)
		end
	end)
end

return Home
