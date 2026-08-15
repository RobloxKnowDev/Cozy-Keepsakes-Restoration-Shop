local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Statsservice = {
	Name = "StatsService",
	Priority = 6,
	Remotes = {
		GetStats = "Function",
		StatsUpdated = "Event",
	},
}

type PlayerStats = {
	ItemsSold: number,
	Reputation: number,
	DailyProfit: number,
	LastDay: number,
}

local StatsByPlayer: { [Player]: PlayerStats } = {}

local function GetCurrentDay(): number
	return Lighting:GetAttribute("Day") or 1
end

local function RoundCurrency(Value: number): number
	return math.round(Value * 100) / 100
end

function Statsservice:EnsurePlayer(Player: Player): PlayerStats
	local Stats = StatsByPlayer[Player]
	if Stats == nil then
		Stats = {
			ItemsSold = 0,
			Reputation = 0,
			DailyProfit = 0,
			LastDay = GetCurrentDay(),
		}
		StatsByPlayer[Player] = Stats
	end
	return Stats
end

function Statsservice:ResetDailyProfitIfNeeded(Player: Player)
	local Stats = self:EnsurePlayer(Player)
	local CurrentDay = GetCurrentDay()
	if Stats.LastDay == CurrentDay then
		return false
	end

	Stats.LastDay = CurrentDay
	Stats.DailyProfit = 0
	return true
end

function Statsservice:PushStats(Player: Player)
	self:ResetDailyProfitIfNeeded(Player)
	local Stats = self:EnsurePlayer(Player)
	Remotemanager:FireClient(self.Name, "StatsUpdated", Player, {
		ItemsSold = Stats.ItemsSold,
		Reputation = Stats.Reputation,
		DailyProfit = Stats.DailyProfit,
	})
end

function Statsservice:GetStats(Player: Player)
	self:ResetDailyProfitIfNeeded(Player)
	local Stats = self:EnsurePlayer(Player)
	return {
		ItemsSold = Stats.ItemsSold,
		Reputation = Stats.Reputation,
		DailyProfit = Stats.DailyProfit,
	}
end

function Statsservice:AddItemsSold(Player: Player, Amount: number)
	local Stats = self:EnsurePlayer(Player)
	Stats.ItemsSold += Amount
	self:PushStats(Player)
end

function Statsservice:AddDailyProfit(Player: Player, Amount: number)
	local Stats = self:EnsurePlayer(Player)
	self:ResetDailyProfitIfNeeded(Player)
	Stats.DailyProfit = RoundCurrency(Stats.DailyProfit + Amount)
	self:PushStats(Player)
end

function Statsservice:Init()
	for _, Player in ipairs(Players:GetPlayers()) do
		self:EnsurePlayer(Player)
	end

	Players.PlayerAdded:Connect(function(Player)
		self:EnsurePlayer(Player)
		task.defer(function()
			if Player.Parent then
				self:PushStats(Player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(Player)
		StatsByPlayer[Player] = nil
	end)

	Lighting:GetAttributeChangedSignal("Day"):Connect(function()
		for _, Player in ipairs(Players:GetPlayers()) do
			if self:ResetDailyProfitIfNeeded(Player) then
				self:PushStats(Player)
			end
		end
	end)

	Remotemanager:OnServerInvoke(self.Name, "GetStats", function(Player)
		return self:GetStats(Player)
	end)
end

return Statsservice
