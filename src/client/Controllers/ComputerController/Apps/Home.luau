local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local Home = {}
local GainColor = Color3.fromRGB(126, 255, 145)
local LossColor = Color3.fromRGB(255, 138, 138)
local ReputationBoostColor = Color3.fromRGB(255, 228, 77)

function Home.ApplyReputationBoost(Controller, State)
	Controller.reputationText.TextColor3 = if (tonumber(State.ReputationMultiplier) or 1) > 1
		then ReputationBoostColor
		else Controller.baseReputationTextColor
end

function Home.Init(Controller)
	Controller.statsFrame = Controller.homeFrame:WaitForChild("StatsFrame")
	Controller.itemsText = Controller.statsFrame:WaitForChild("ItemsText")
	Controller.reputationText = Controller.statsFrame:WaitForChild("ReputationText")
	Controller.dailyProfitText = Controller.statsFrame:WaitForChild("DailyText")
	Controller.baseReputationTextColor = Controller.reputationText.TextColor3
	Controller.baseDailyProfitTextColor = Controller.dailyProfitText.TextColor3
	Home.ApplyStats(Controller, RemoteManager:InvokeServer("StatsService", "GetStats"))
end

function Home.ApplyStats(Controller, Stats)
	local Profit = Stats.DailyProfit or 0
	Controller.itemsText.Text = tostring(Stats.ItemsSold or 0)
	Controller.reputationText.Text = tostring(Stats.Reputation or 0)
	Controller.dailyProfitText.Text = Shared.FormatProfit(Profit)
	Controller.dailyProfitText.TextColor3 = if Profit > 0 then GainColor elseif Profit < 0 then LossColor else Controller.baseDailyProfitTextColor
end

function Home.Start(Controller)
	Home.ApplyReputationBoost(Controller, Controller.shopState)
	RemoteManager:OnClientEvent("StatsService", "StatsUpdated", function(Stats)
		Home.ApplyStats(Controller, Stats)
	end)
	RemoteManager:OnClientEvent("MonetizationService", "ShopStateUpdated", function(State)
		Home.ApplyReputationBoost(Controller, State)
	end)
end

return Home
