local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Datastorerequest = require(script.Parent.Parent.Utils.Datastorerequest)
local Separatenumber = require(Replicatedstorage.Shared.Utils.NumberAbbreviator)

local Leaderboardservice = {
	Name = "LeaderboardService",
	Priority = 16,
}

type Entry = { UserId: number, Value: number }
type Row = { Frame: GuiObject, Name: TextLabel, Value: TextLabel }
type Display = { List: ScrollingFrame, Template: GuiObject, Rows: { Row } }

local Boardorder = { "Reputation", "ItemSold", "Donation" }
local Statbyboard = {
	Reputation = "RankedReputation",
	ItemSold = "ItemsSold",
	Donation = "RobuxDonated",
}
local Growingboards = {
	ItemSold = true,
	Donation = true,
}
local Storeversions = {
	Reputation = 2,
	ItemSold = 1,
	Donation = 1,
}
local Modelbyboard = {
	Reputation = "Reputation",
	ItemSold = "Sold",
	Donation = "Robux",
}
local Robuxicon = "\u{E002}"
local Valueprefixbyboard = {
	Reputation = "",
	ItemSold = "",
	Donation = Robuxicon,
}
local Placecolors = {
	Color3.fromRGB(255, 196, 0),
	Color3.fromRGB(205, 215, 230),
	Color3.fromRGB(214, 133, 66),
}
local Defaultplacecolor = Color3.fromRGB(162, 162, 162)
local Cameramarkers = { "CamRobux", "CamSold", "CamReputation" }
local Maxentries = 100
local Namebatchsize = 200
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
local Displaybyboard: { [string]: Display } = {}
local Pendingwrites = 0
local Pushscheduled = false

for _, Board in ipairs(Boardorder) do
	Stores[Board] = DataStoreService:GetOrderedDataStore("Leaderboard_" .. Board .. "_v" .. Storeversions[Board])
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
	for First = 1, #Missing, Namebatchsize do
		local Batch = table.move(Missing, First, math.min(First + Namebatchsize - 1, #Missing), 1, {})
		local Success, Infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(Batch)
		end)
		if Success then
			for _, Info in ipairs(Infos) do
				Namesbyuserid[Info.Id] = Info.DisplayName
			end
		end
	end
end

local function Createrow(Display: Display, Rank: number): Row
	local Rowframe = Display.Template:Clone()
	Rowframe.Name = string.format("%03d", Rank)
	Rowframe.LayoutOrder = Rank
	local Place = Rowframe:WaitForChild("Place") :: TextLabel
	Place.Text = "#" .. Rank
	Place.TextColor3 = Placecolors[Rank] or Defaultplacecolor
	Rowframe.Parent = Display.List
	local Row = {
		Frame = Rowframe,
		Name = Rowframe:WaitForChild("Name") :: TextLabel,
		Value = Rowframe:WaitForChild("Value") :: TextLabel,
	}
	Display.Rows[Rank] = Row
	return Row
end

local function Renderboards()
	for _, Board in ipairs(Boardorder) do
		local Display = Displaybyboard[Board]
		local Entries = Entriesbyboard[Board]
		for Rank, Current in ipairs(Entries) do
			local Row = Display.Rows[Rank] or Createrow(Display, Rank)
			Row.Name.Text = Namesbyuserid[Current.UserId] or "..."
			Row.Value.Text = Valueprefixbyboard[Board] .. Separatenumber(Current.Value)
			Row.Frame.Visible = true
		end
		for Rank = #Entries + 1, #Display.Rows do
			Display.Rows[Rank].Frame.Visible = false
		end
	end
end

local function Schedulepush()
	if Pushscheduled then
		return
	end
	Pushscheduled = true
	task.delay(Pushdelay, function()
		Pushscheduled = false
		Resolvenames()
		Renderboards()
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

function Leaderboardservice:Read(Userid: number): { { Board: string, Ok: boolean, Value: any, Rank: number? } }
	local Scores = {}
	for _, Board in ipairs(Boardorder) do
		local Success, Value = Datastorerequest.Run(Refreshattempts, function()
			return Stores[Board]:GetAsync(tostring(Userid))
		end)
		local Rank = nil
		for Index, Current in ipairs(Entriesbyboard[Board]) do
			if Current.UserId == Userid then
				Rank = Index
				break
			end
		end
		table.insert(Scores, { Board = Board, Ok = Success, Value = if Success then Value else tostring(Value), Rank = Rank })
	end
	return Scores
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
	local Leaderboards = Workspace:WaitForChild("Map"):WaitForChild("Leaderboards") :: Model
	local Camera = Leaderboards:WaitForChild("Camera")
	for _, Name in ipairs(Cameramarkers) do
		local Marker = Camera:WaitForChild(Name) :: BasePart
		Marker.Anchored = true
		Marker.CanCollide = false
		Marker.CanQuery = false
		Marker.CanTouch = false
		Marker.Transparency = 1
	end
	Leaderboards.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	for _, Board in ipairs(Boardorder) do
		local List = Leaderboards:WaitForChild(Modelbyboard[Board]):WaitForChild("SurfaceGui"):WaitForChild("ScrollingFrame") :: ScrollingFrame
		local Template = List:WaitForChild("Template") :: GuiObject
		Template.Visible = false
		List.AutomaticCanvasSize = Enum.AutomaticSize.Y
		Displaybyboard[Board] = { List = List, Template = Template, Rows = {} }
	end

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
