local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Cashservice = {
	Name = "CashService",
	Priority = 5,
	Remotes = {
		GetCash = "Function",
		CashUpdated = "Event",
	},
}

local Startingcash = 150
local Cashbyplayer: { [Player]: number } = {}

local function Normalizecash(Value: number): number
	return math.max(math.round(Value * 100) / 100, 0)
end

function Cashservice:EnsurePlayer(Player: Player): number
	local Cash = Cashbyplayer[Player]
	if Cash == nil then
		Cash = Startingcash
		Cashbyplayer[Player] = Cash
	end
	return Cash
end

function Cashservice:PushCash(Player: Player)
	self:EnsurePlayer(Player)
	Remotemanager:FireClient(self.Name, "CashUpdated", Player, Cashbyplayer[Player])
end

function Cashservice:GetCash(Player: Player): number
	return self:EnsurePlayer(Player)
end

function Cashservice:AddCash(Player: Player, Amount: number, TrackProfit: boolean?): number
	local Currentcash = self:EnsurePlayer(Player)
	Cashbyplayer[Player] = Normalizecash(Currentcash + Amount)
	if TrackProfit ~= false then Core:GetService("StatsService"):AddDailyProfit(Player, Amount) end
	self:PushCash(Player)
	return Cashbyplayer[Player]
end

function Cashservice:SpendCash(Player: Player, Amount: number): boolean
	local Currentcash = self:EnsurePlayer(Player)
	local Normalizedamount = Normalizecash(Amount)
	if Currentcash < Normalizedamount then
		return false
	end

	Cashbyplayer[Player] = Normalizecash(Currentcash - Normalizedamount)
	Core:GetService("StatsService"):AddDailyProfit(Player, -Normalizedamount)
	self:PushCash(Player)
	return true
end

function Cashservice:Init()
	for _, Player in ipairs(Players:GetPlayers()) do
		self:EnsurePlayer(Player)
	end

	Players.PlayerAdded:Connect(function(Player)
		self:EnsurePlayer(Player)
		task.defer(function()
			if Player.Parent then
				self:PushCash(Player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(Player)
		Cashbyplayer[Player] = nil
	end)

	Remotemanager:OnServerInvoke(self.Name, "GetCash", function(Player)
		return self:GetCash(Player)
	end)
end

return Cashservice
