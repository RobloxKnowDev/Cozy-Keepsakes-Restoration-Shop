local Lighting = game:GetService("Lighting")
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

function Statsservice:Init()
	Core:GetService("DataService"):Register("Stats", {
		Load = function(Player, Saved)
			local Stats = self:EnsurePlayer(Player)
			Stats.ItemsSold = math.max(tonumber(Saved.ItemsSold) or 0, 0)
			Stats.Reputation = math.max(tonumber(Saved.Reputation) or 0, 0)
			Stats.DailyProfit = tonumber(Saved.DailyProfit) or 0
			Stats.LastDay = tonumber(Saved.LastDay) or Stats.LastDay
			self:PushStats(Player)
		end,
		Save = function(Player)
			return self:EnsurePlayer(Player)
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
