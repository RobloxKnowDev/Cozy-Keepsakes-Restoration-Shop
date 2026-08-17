local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local Home = {}
local GainColor = Color3.fromRGB(126, 255, 145)
local LossColor = Color3.fromRGB(255, 138, 138)

function Home.Init(Controller)
	Controller.statsFrame = Shared.RequireFrame(Controller.homeFrame, "StatsFrame")
	Controller.itemsText = Shared.FindText(Controller.statsFrame, "ItemsText")
	Controller.reputationText = Shared.FindText(Controller.statsFrame, "ReputationText")
	Controller.dailyProfitText = Shared.FindText(Controller.statsFrame, "DailyText")
	Controller.baseDailyProfitTextColor = if Controller.dailyProfitText then Controller.dailyProfitText.TextColor3 else Color3.new(1, 1, 1)
	Home.ApplyStats(Controller, RemoteManager:InvokeServer("StatsService", "GetStats"))
end

function Home.ApplyStats(Controller, Stats)
	if not Stats then return end
	if Controller.itemsText then Controller.itemsText.Text = tostring(Stats.ItemsSold or 0) end
	if Controller.reputationText then Controller.reputationText.Text = tostring(Stats.Reputation or 0) end
	if Controller.dailyProfitText then
		local Profit = Stats.DailyProfit or 0
		Controller.dailyProfitText.Text = Shared.FormatProfit(Profit)
		Controller.dailyProfitText.TextColor3 = if Profit > 0
			then GainColor
			elseif Profit < 0 then LossColor
			else Controller.baseDailyProfitTextColor
	end
end

function Home.Start(Controller)
	RemoteManager:OnClientEvent("StatsService", "StatsUpdated", function(Stats)
		Home.ApplyStats(Controller, Stats)
	end)
end

return Home
