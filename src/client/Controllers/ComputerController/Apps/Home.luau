local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local Home = {}
local GainColor = Color3.fromRGB(126, 255, 145)
local LossColor = Color3.fromRGB(255, 138, 138)

function Home.Init(Controller)
	Controller.statsFrame = Controller.homeFrame:WaitForChild("StatsFrame")
	Controller.itemsText = Controller.statsFrame:WaitForChild("ItemsText")
	Controller.reputationText = Controller.statsFrame:WaitForChild("ReputationText")
	Controller.dailyProfitText = Controller.statsFrame:WaitForChild("DailyText")
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
	RemoteManager:OnClientEvent("StatsService", "StatsUpdated", function(Stats)
		Home.ApplyStats(Controller, Stats)
	end)
end

return Home
