local Badgeservice = game:GetService("BadgeService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Badgesconfig = require(script.Parent.Parent.Config.Badges)

local Badgeawardservice = {
	Name = "BadgeAwardService",
	Priority = 6,
}

local Readattempts = 3
local Ownedbyplayer: { [Player]: { [number]: boolean } } = {}

local function Readowned(Player: Player): { [number]: boolean }?
	local Ids = {}
	for _, Badge in ipairs(Badgesconfig) do
		table.insert(Ids, Badge.Id)
	end
	for Attempt = 1, Readattempts do
		local Success, Result = pcall(function()
			return Badgeservice:CheckUserBadgesAsync(Player.UserId, Ids)
		end)
		if Success then
			local Owned = {}
			for _, Id in ipairs(Result) do
				Owned[Id] = true
			end
			return Owned
		end
		warn("BadgeAwardService: could not read the badges of " .. Player.Name .. ": " .. tostring(Result))
		if Attempt < Readattempts and Player.Parent then
			task.wait(2 ^ Attempt)
		end
	end
	return nil
end

local function Award(Player: Player, Badge)
	local Success, Result = pcall(function()
		return Badgeservice:AwardBadge(Player.UserId, Badge.Id)
	end)
	if not Success or not Result then
		warn("BadgeAwardService: could not award " .. Badge.Name .. " to " .. Player.Name .. ": " .. tostring(Result))
	end
end

function Badgeawardservice:Check(Player: Player)
	local Owned = Ownedbyplayer[Player]
	if not Owned then
		return
	end
	local Stats = Core:GetService("StatsService"):EnsurePlayer(Player)
	local Values = { ItemsSold = Stats.ItemsSold, Luck = Stats.RankedReputation }
	for _, Badge in ipairs(Badgesconfig) do
		if not Owned[Badge.Id] and (if Badge.Stat then Values[Badge.Stat] else 0) >= Badge.Threshold then
			Owned[Badge.Id] = true
			task.spawn(Award, Player, Badge)
		end
	end
end

local function Begin(Player: Player)
	Core:GetService("DataService"):WaitForLoad(Player)
	if not Player.Parent then
		return
	end
	local Owned = Readowned(Player)
	if not Owned or not Player.Parent then
		return
	end
	Ownedbyplayer[Player] = Owned
	Badgeawardservice:Check(Player)
end

function Badgeawardservice:Init()
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(Begin, Player)
	end
	Players.PlayerAdded:Connect(function(Player)
		task.spawn(Begin, Player)
	end)
	Players.PlayerRemoving:Connect(function(Player)
		Ownedbyplayer[Player] = nil
	end)
end

return Badgeawardservice
