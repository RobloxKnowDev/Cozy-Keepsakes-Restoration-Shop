local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Datastorerequest = require(script.Parent.Parent.Utils.Datastorerequest)
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
local Growingboards = {
	ItemSold = true,
	Donation = true,
}
local Maxentries = 50
local Refreshinterval = 120
local Pushdelay = 1
local Writeattempts = 3
local Refreshattempts = 2
local Shutdowndeadline = 27
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

local function Writescore(Userid: number, Written: { [string]: number }?, Board: string, Value: number, Replace: boolean)
	Pendingwrites += 1
	local Success, Result = Datastorerequest.Run(Writeattempts, function()
		if Growingboards[Board] and not Replace then
			return Stores[Board]:UpdateAsync(tostring(Userid), function(Current)
				return math.max(Current or 0, Value)
			end)
		end
		Stores[Board]:SetAsync(tostring(Userid), Value)
		return Value
	end)
	Pendingwrites -= 1
	if not Success then
		warn("LeaderboardService: could not write " .. Board .. " for " .. Userid .. ": " .. tostring(Result))
		if Written and Written[Board] == Value then
			Written[Board] = nil
		end
		return
	end
	local Stored = tonumber(Result) or Value
	if Written and Written[Board] == Value then
		Written[Board] = Stored
	end
	Mergescore(Board, Userid, Stored)
	Schedulepush()
	pcall(function()
		MessagingService:PublishAsync(Topic, { B = Board, U = Userid, V = Stored })
	end)
end

local function Refreshboard(Board: string)
	local Success, Pages = Datastorerequest.Run(Refreshattempts, function()
		return Stores[Board]:GetSortedAsync(false, Maxentries)
	end)
	if not Success then
		warn("LeaderboardService: could not refresh " .. Board .. ": " .. tostring(Pages))
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

function Leaderboardservice:Wipe(Userid: number)
	local Player = Players:GetPlayerByUserId(Userid)
	if Player then
		Lastwritten[Player] = nil
	end
	while Pendingwrites > 0 do
		task.wait()
	end
	for _, Board in ipairs(Boardorder) do
		local Success, Error = Datastorerequest.Run(Writeattempts, function()
			Stores[Board]:RemoveAsync(tostring(Userid))
		end)
		if not Success then
			warn("LeaderboardService: could not erase " .. Board .. " for " .. Userid .. ": " .. tostring(Error))
		end
		Mergescore(Board, Userid, 0)
		pcall(function()
			MessagingService:PublishAsync(Topic, { B = Board, U = Userid, V = 0 })
		end)
	end
	Schedulepush()
end

function Leaderboardservice:Overwrite(Userid: number, Stats: any)
	local Player = Players:GetPlayerByUserId(Userid)
	if Player then
		Lastwritten[Player] = nil
	end
	while Pendingwrites > 0 do
		task.wait()
	end
	for _, Board in ipairs(Boardorder) do
		local Value = if type(Stats) == "table" then math.floor(tonumber(Stats[Statbyboard[Board]]) or 0) else 0
		if Value ~= Value then
			Value = 0
		end
		Pendingwrites += 1
		local Success, Error = Datastorerequest.Run(Writeattempts, function()
			if Value > 0 then
				Stores[Board]:SetAsync(tostring(Userid), Value)
			else
				Stores[Board]:RemoveAsync(tostring(Userid))
			end
		end)
		Pendingwrites -= 1
		if not Success then
			warn("LeaderboardService: could not overwrite " .. Board .. " for " .. Userid .. ": " .. tostring(Error))
		end
		Mergescore(Board, Userid, math.max(Value, 0))
		pcall(function()
			MessagingService:PublishAsync(Topic, { B = Board, U = Userid, V = math.max(Value, 0) })
		end)
	end
	Schedulepush()
end

function Leaderboardservice:Init()
	Core:GetService("DataService"):Register("Leaderboard", {
		Load = function() end,
		Save = function()
			return nil
		end,
		Clear = function(Player)
			Lastwritten[Player] = nil
		end,
		Committed = function(Player, Snapshot, Release)
			local Stats = Snapshot.Stats
			if type(Stats) ~= "table" then
				return
			end
			local Written = if Release then {} else Lastwritten[Player] or {}
			if not Release then
				Lastwritten[Player] = Written
			end
			for _, Board in ipairs(Boardorder) do
				local Value = math.floor(tonumber(Stats[Statbyboard[Board]]) or 0)
				local Previous = Written[Board]
				local Needswrite = if Growingboards[Board]
					then Value > (Previous or 0)
					else Value ~= Previous and (Previous ~= nil or Value > 0)
				if Needswrite then
					Written[Board] = Value
					task.spawn(Writescore, Player.UserId, if Release then nil else Written, Board, Value, Previous == nil)
				end
			end
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
		local Dataservice = Core:GetService("DataService")
		local Deadline = os.clock() + Shutdowndeadline
		while (Dataservice:IsReleasing() or Pendingwrites > 0) and os.clock() < Deadline do
			task.wait()
		end
	end)
end

return Leaderboardservice
