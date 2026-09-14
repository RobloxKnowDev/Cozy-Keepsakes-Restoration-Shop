local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Leaderboardservice = {
	Name = "LeaderboardService",
	Priority = 16,
	Remotes = {
		GetLeaderboards = "Function",
		LeaderboardsUpdated = "Event",
	},
}

type Entry = { UserId: number, Value: number }

local Boardorder = { "Reputation", "ItemSold", "Donation" }
local Statbyboard = {
	Reputation = "Reputation",
	ItemSold = "ItemsSold",
	Donation = "RobuxDonated",
}
local Maxentries = 50
local Refreshinterval = 120
local Pushdelay = 1
local Topic = "LeaderboardScores"

local Stores: { [string]: OrderedDataStore } = {}
local Entriesbyboard: { [string]: { Entry } } = {}
local Lastwritten: { [Player]: { [string]: number } } = {}
local Namesbyuserid: { [number]: string } = {}
local Pendingwrites = 0
local Pushscheduled = false

for _, Board in ipairs(Boardorder) do
	Stores[Board] = DataStoreService:GetOrderedDataStore("Leaderboard_" .. Board .. "_v1")
	Entriesbyboard[Board] = {}
end

local function Mergescore(Board: string, Userid: number, Value: number)
	local List = Entriesbyboard[Board]
	for Index, Current in ipairs(List) do
		if Current.UserId == Userid then
			table.remove(List, Index)
			break
		end
	end
	if Value > 0 then
		table.insert(List, { UserId = Userid, Value = Value })
	end
	table.sort(List, function(Left, Right)
		return Left.Value > Right.Value
	end)
	while #List > Maxentries do
		table.remove(List)
	end
end

local function Resolvenames()
	local Missing = {}
	for _, Board in ipairs(Boardorder) do
		for _, Current in ipairs(Entriesbyboard[Board]) do
			if not Namesbyuserid[Current.UserId] and not table.find(Missing, Current.UserId) then
				table.insert(Missing, Current.UserId)
			end
		end
	end
	if #Missing == 0 then
		return
	end
	local Success, Infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(Missing)
	end)
	if not Success then
		return
	end
	for _, Info in ipairs(Infos) do
		Namesbyuserid[Info.Id] = Info.DisplayName
	end
end

local function Buildpayload()
	local Payload = {}
	for _, Board in ipairs(Boardorder) do
		local Rows = {}
		for _, Current in ipairs(Entriesbyboard[Board]) do
			table.insert(Rows, {
				UserId = Current.UserId,
				Name = Namesbyuserid[Current.UserId] or "...",
				Value = Current.Value,
			})
		end
		Payload[Board] = Rows
	end
	return Payload
end

local function Schedulepush()
	if Pushscheduled then
		return
	end
	Pushscheduled = true
	task.delay(Pushdelay, function()
		Pushscheduled = false
		Resolvenames()
		Remotemanager:FireAllClients(Leaderboardservice.Name, "LeaderboardsUpdated", Buildpayload())
	end)
end

local function Writescore(Player: Player, Board: string, Value: number)
	local Userid = Player.UserId
	Pendingwrites += 1
	local Success = pcall(function()
		Stores[Board]:SetAsync(tostring(Userid), Value)
	end)
	Pendingwrites -= 1
	if not Success then
		local Written = Lastwritten[Player]
		if Written and Written[Board] == Value then
			Written[Board] = nil
		end
		return
	end
	Mergescore(Board, Userid, Value)
	Schedulepush()
	pcall(function()
		MessagingService:PublishAsync(Topic, { B = Board, U = Userid, V = Value })
	end)
end

local function Refreshboard(Board: string)
	local Success, Pages = pcall(function()
		return Stores[Board]:GetSortedAsync(false, Maxentries)
	end)
	if not Success then
		return
	end
	local List = {}
	for _, Item in ipairs(Pages:GetCurrentPage()) do
		if Item.value > 0 then
			table.insert(List, { UserId = tonumber(Item.key) :: number, Value = Item.value })
		end
	end
	Entriesbyboard[Board] = List
end

local function Refreshall()
	for _, Board in ipairs(Boardorder) do
		Refreshboard(Board)
	end
	for Player, Written in pairs(Lastwritten) do
		for Board, Value in pairs(Written) do
			Mergescore(Board, Player.UserId, Value)
		end
	end
	Schedulepush()
end

function Leaderboardservice:Init()
	Core:GetService("DataService"):Register("Leaderboard", {
		Load = function() end,
		Save = function(Player)
			local Stats = Core:GetService("StatsService"):GetStats(Player)
			local Written = Lastwritten[Player] or {}
			Lastwritten[Player] = Written
			for _, Board in ipairs(Boardorder) do
				local Value = math.floor(Stats[Statbyboard[Board]])
				local Previous = Written[Board]
				if Value ~= Previous and (Previous ~= nil or Value > 0) then
					Written[Board] = Value
					task.spawn(Writescore, Player, Board, Value)
				end
			end
			return nil
		end,
		Clear = function(Player)
			Lastwritten[Player] = nil
		end,
	})

	Remotemanager:OnServerInvoke(self.Name, "GetLeaderboards", function()
		return Buildpayload()
	end)
end

function Leaderboardservice:Start()
	task.spawn(function()
		local Subscribed = pcall(function()
			MessagingService:SubscribeAsync(Topic, function(Message)
				local Data = Message.Data
				Mergescore(Data.B, Data.U, Data.V)
				Schedulepush()
			end)
		end)
		if not Subscribed then
			warn("LeaderboardService: cross-server updates unavailable")
		end
	end)

	task.spawn(function()
		while true do
			Refreshall()
			task.wait(Refreshinterval)
		end
	end)

	game:BindToClose(function()
		while Pendingwrites > 0 do
			task.wait()
		end
	end)
end

return Leaderboardservice
