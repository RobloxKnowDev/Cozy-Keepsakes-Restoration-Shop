local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
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
	RankedReputation: number,
	RobuxDonated: number,
	DailyProfit: number,
	LastDay: number,
}

local StatsByPlayer: { [Player]: PlayerStats } = {}

local function GetCurrentDay(Player: Player): number
	return Core:GetService("DayNightService"):GetDay(Player)
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
			RankedReputation = 0,
			RobuxDonated = 0,
			DailyProfit = 0,
			LastDay = GetCurrentDay(Player),
		}
		StatsByPlayer[Player] = Stats
	end
	return Stats
end

function Statsservice:ResetDailyProfitIfNeeded(Player: Player)
	local Stats = self:EnsurePlayer(Player)
	local CurrentDay = GetCurrentDay(Player)
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
		RobuxDonated = Stats.RobuxDonated,
		DailyProfit = Stats.DailyProfit,
	}
end

function Statsservice:AddRobuxDonated(Player: Player, Amount: number)
	local Stats = self:EnsurePlayer(Player)
	Stats.RobuxDonated += Amount
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

function Statsservice:GetReputationContribution(Player: Player, Amount: number): number
	local Multiplier = Core:GetService("MonetizationService"):GetReputationMultiplier(Player)
	return RoundCurrency(math.max(Amount, 0) * Multiplier)
end

function Statsservice:SetReputation(Player: Player, Amount: number): number
	local Stats = self:EnsurePlayer(Player)
	Stats.Reputation = math.max(RoundCurrency(Amount), 0)
	self:PushStats(Player)
	return Stats.Reputation
end

function Statsservice:SetRankedReputation(Player: Player, Amount: number)
	self:EnsurePlayer(Player).RankedReputation = math.max(RoundCurrency(Amount), 0)
end

function Statsservice:Init()
	Core:GetService("DataService"):Register("Stats", {
		Load = function(Player, Saved)
			local Stats = self:EnsurePlayer(Player)
			Stats.ItemsSold = math.max(tonumber(Saved.ItemsSold) or 0, 0)
			Stats.Reputation = math.max(tonumber(Saved.Reputation) or 0, 0)
			Stats.RankedReputation = math.max(tonumber(Saved.RankedReputation) or 0, 0)
			Stats.RobuxDonated = math.max(tonumber(Saved.RobuxDonated) or 0, 0)
			Stats.DailyProfit = 0
			Stats.LastDay = GetCurrentDay(Player)
			self:PushStats(Player)
		end,
		Save = function(Player)
			local Stats = self:EnsurePlayer(Player)
			return {
				ItemsSold = Stats.ItemsSold,
				Reputation = Stats.Reputation,
				RankedReputation = Stats.RankedReputation,
				RobuxDonated = Stats.RobuxDonated,
			}
		end,
		Clear = function(Player)
			StatsByPlayer[Player] = nil
		end,
	})
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

	Core:GetService("DayNightService").DayChanged.Event:Connect(function(Player)
		if self:ResetDailyProfitIfNeeded(Player) then
			self:PushStats(Player)
		end
	end)

	Remotemanager:OnServerInvoke(self.Name, "GetStats", function(Player)
		return self:GetStats(Player)
	end)
end

return Statsservice
