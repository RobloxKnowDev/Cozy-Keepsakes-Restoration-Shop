local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Boostsconfig = require(Replicatedstorage.Shared.Config.Boosts)

local Friendservice = {
	Name = "FriendService",
	Priority = 6,
}

local Friendsbyplayer: { [Player]: { [Player]: boolean } } = {}

local function Refresh(Player: Player)
	local Count = 0
	for _ in pairs(Friendsbyplayer[Player]) do
		Count += 1
	end
	Player:SetAttribute("Friends", Count)
	if Core:GetService("DataService"):IsLoaded(Player) then
		Core:GetService("InventoryService"):PushItems(Player)
	end
end

local function Link(Player: Player, Other: Player)
	local Success, Isfriend = pcall(Player.IsFriendsWith, Player, Other.UserId)
	if Success and Isfriend and Friendsbyplayer[Player] and Friendsbyplayer[Other] then
		Friendsbyplayer[Player][Other] = true
		Friendsbyplayer[Other][Player] = true
		Refresh(Player)
		Refresh(Other)
	end
end

local function Add(Player: Player)
	Friendsbyplayer[Player] = {}
	Player:SetAttribute("Friends", 0)
	for _, Other in ipairs(Players:GetPlayers()) do
		if Other ~= Player and Friendsbyplayer[Other] then
			task.spawn(Link, Player, Other)
		end
	end
end

local function Remove(Player: Player)
	local Friends = Friendsbyplayer[Player]
	Friendsbyplayer[Player] = nil
	for Friend in pairs(Friends) do
		Friendsbyplayer[Friend][Player] = nil
		Refresh(Friend)
	end
end

function Friendservice:GetSaleMultiplier(Player: Player): number
	return 1 + (Player:GetAttribute("Friends") or 0) * Boostsconfig.FriendBoost.SellPercent / 100
end

function Friendservice:Init()
	for _, Player in ipairs(Players:GetPlayers()) do
		Add(Player)
	end
	Players.PlayerAdded:Connect(Add)
	Players.PlayerRemoving:Connect(Remove)
end

return Friendservice
