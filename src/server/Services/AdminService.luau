local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Dailytasksconfig = require(ReplicatedStorage.Shared.Config.DailyTasks)
local Monetizationconfig = require(ReplicatedStorage.Shared.Config.Monetization)
local Objectconfig = require(ReplicatedStorage.Shared.Config.Object)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Upgradesconfig = require(ReplicatedStorage.Shared.Config.Upgrades)

local Banstore = DataStoreService:GetDataStore("Bans_v1")
local Broadcasttopic = "AdminBroadcast"
local Resettopic = "AdminResetData"

local Adminservice = {
	Name = "AdminService",
	Priority = 2,
	Remotes = {
		GetCommands = "Function",
		RunCommand = "Function",
	},
}

local Adminuserids = { 2024462699, 2024446314 }

local function Isadmin(Player: Player): boolean
	if table.find(Adminuserids, Player.UserId) then
		return true
	end
	if RunService:IsStudio() then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and Player.UserId == game.CreatorId
end

local function Findplayer(Name: string?): Player?
	if not Name or Name == "" then
		return nil
	end
	local Lower = string.lower(Name)
	for _, Player in ipairs(Players:GetPlayers()) do
		if string.lower(Player.Name) == Lower or string.lower(Player.DisplayName) == Lower then
			return Player
		end
	end
	for _, Player in ipairs(Players:GetPlayers()) do
		if string.sub(string.lower(Player.Name), 1, #Lower) == Lower then
			return Player
		end
	end
	return nil
end

local function Findkey(Container: { [string]: any }, Name: string?): string?
	if not Name then
		return nil
	end
	local Lower = string.lower(Name)
	for Key in pairs(Container) do
		if string.lower(Key) == Lower then
			return Key
		end
	end
	return nil
end

local function Giveitem(Target: Player, Objectkey: string, Percent: number)
	local Definition = Objectconfig.Object[Objectkey]
	local Ratio = Percent / 100
	local Maximums = Core:GetService("RestorationService"):GenerateObjectMaximums(Objectkey)
	local Value = math.round(Maximums.MaxValue * Ratio * 100) / 100
	Core:GetService("InventoryService"):AddRestoredItem(Target, {
		Id = 0,
		ObjectKey = Objectkey,
		Name = Definition.Name or Objectkey,
		ImageId = tostring(Definition.IdImage or ""),
		Rarity = tostring(Definition.Rarity or "Common"),
		Mutation = Maximums.Mutation or "Normal",
		RestorationPercent = math.floor(Percent),
		PurchasePrice = 0,
		CurrentValue = Value,
		MaxValue = Maximums.MaxValue,
		MaxReputation = Maximums.MaxReputation,
		NetProfit = Value,
		Reputation = math.round(Maximums.MaxReputation * Ratio * 100) / 100,
	})
	if Ratio >= 0.5 then
		Core:GetService("InventoryService"):UnlockIndexEntry(Target, Objectkey, Maximums.Mutation)
	end
end

local function Setban(Userid: number, Entry: any): boolean
	local Success, Error = pcall(function()
		if Entry then
			Banstore:SetAsync(tostring(Userid), Entry)
		else
			Banstore:RemoveAsync(tostring(Userid))
		end
	end)
	if not Success then
		warn("AdminService: could not write the ban: " .. tostring(Error))
	end
	return Success
end

local function Getban(Userid: number): any
	local Success, Entry = pcall(function()
		return Banstore:GetAsync(tostring(Userid))
	end)
	if not Success then
		warn("AdminService: could not read the ban: " .. tostring(Entry))
		return nil
	end
	return Entry
end

local function Kickeveryone(Reason: string)
	for _, Player in ipairs(Players:GetPlayers()) do
		Player:Kick(Reason)
	end
end

local function Finduser(Text: string): (number, string)
	local Lower = string.lower(Text)
	for _, Player in ipairs(Players:GetPlayers()) do
		if string.lower(Player.Name) == Lower then
			return Player.UserId, Player.Name
		end
	end
	if not string.match(Text, "^%-?%d+$") then
		return Players:GetUserIdFromNameAsync(Text), Text
	end
	local Userid = tonumber(Text) :: number
	local Success, Name = pcall(function()
		return Players:GetNameFromUserIdAsync(Userid)
	end)
	return Userid, if Success then Name else "Unknown"
end

local function Wipeuser(Userid: number): (boolean, string)
	local Erased, Reason = Core:GetService("DataService"):Wipe(Userid)
	Core:GetService("TutorialService"):Wipe(Userid)
	Core:GetService("DailyRewardService"):Wipe(Userid)
	Core:GetService("LeaderboardService"):Wipe(Userid)
	local Target = Players:GetPlayerByUserId(Userid)
	if Target then
		task.defer(function()
			if Target.Parent then
				Target:Kick("Your data was reset. Please rejoin.")
			end
		end)
	end
	return Erased, Reason
end

local Commands = {
	{
		Name = "resetdata",
		Usage = "resetdata <username|userid>",
		Description = "Erase a whole save, even offline",
		Arguments = { "player" },
		Run = function(_Caller: Player, Arguments: { string }): string
			if #Arguments ~= 1 then
				return "Usage: resetdata <username|userid>"
			end
			local Userid, Name = Finduser(Arguments[1])
			local Online = Players:GetPlayerByUserId(Userid) ~= nil
			local Erased, Reason = Wipeuser(Userid)
			local Result = string.format("%s (%d): %s", Name, Userid, if Erased then Reason else "failed, " .. Reason)
			if Online then
				return Result
			end
			local Notified = pcall(function()
				MessagingService:PublishAsync(Resettopic, Userid)
			end)
			return if Notified then Result else Result .. ", broadcast failed"
		end,
	},
	{
		Name = "resettutorial",
		Usage = "resettutorial <player>",
		Description = "Play the tutorial again on next join",
		Arguments = { "player" },
		Run = function(_Caller: Player, Arguments: { string }): string
			local Target = Findplayer(Arguments[1])
			if not Target then
				return "Player not found: " .. tostring(Arguments[1])
			end
			Core:GetService("TutorialService"):Wipe(Target.UserId)
			return "Tutorial reset for " .. Target.Name
		end,
	},
	{
		Name = "cash",
		Usage = "cash <player> <amount>",
		Description = "Give (or take) money",
		Arguments = { "player", "number" },
		Run = function(_Caller: Player, Arguments: { string }): string
			local Target = Findplayer(Arguments[1])
			if not Target then
				return "Player not found: " .. tostring(Arguments[1])
			end
			local Amount = tonumber(Arguments[2])
			if not Amount then
				return "Invalid amount: " .. tostring(Arguments[2])
			end
			local Cashservice = Core:GetService("CashService")
			Cashservice:AddCash(Target, Amount)
			return string.format("%s now has %d", Target.Name, Cashservice:GetCash(Target))
		end,
	},
	{
		Name = "kick",
		Usage = "kick <player> [reason]",
		Description = "Disconnect a player",
		Arguments = { "player" },
		Run = function(_Caller: Player, Arguments: { string }): string
			local Target = Findplayer(Arguments[1])
			if not Target then
				return "Player not found: " .. tostring(Arguments[1])
			end
			local Name = Target.Name
			local Reason = table.concat(Arguments, " ", math.min(2, #Arguments + 1))
			Target:Kick(if Reason ~= "" then Reason else "You were kicked by an admin.")
			return "Kicked: " .. Name
		end,
	},
	{
		Name = "ban",
		Usage = "ban <player> [reason]",
		Description = "Permanently ban and disconnect",
		Arguments = { "player" },
		Run = function(Caller: Player, Arguments: { string }): string
			local Target = Findplayer(Arguments[1])
			if not Target then
				return "Player not found: " .. tostring(Arguments[1])
			end
			local Reason = table.concat(Arguments, " ", math.min(2, #Arguments + 1))
			if Reason == "" then
				Reason = "You were banned by an admin."
			end
			local Name = Target.Name
			local Userid = Target.UserId
			Setban(Userid, { Reason = Reason, By = Caller.Name, Time = os.time() })
			Target:Kick(Reason)
			return string.format("Banned: %s (%d)", Name, Userid)
		end,
	},
	{
		Name = "unban",
		Usage = "unban <userid>",
		Description = "Lift a ban",
		Run = function(_Caller: Player, Arguments: { string }): string
			local Userid = tonumber(Arguments[1])
			if not Userid then
				return "Invalid user id: " .. tostring(Arguments[1])
			end
			Setban(Userid, nil)
			return "Ban lifted: " .. Userid
		end,
	},
	{
		Name = "resetserver",
		Usage = "resetserver",
		Description = "Disconnect everyone from this server",
		Run = function(_Caller: Player, _Arguments: { string }): string
			task.defer(Kickeveryone, "The server is restarting. Please rejoin.")
			return "Server restarting"
		end,
	},
	{
		Name = "resetallservers",
		Usage = "resetallservers",
		Description = "Disconnect everyone from ALL servers",
		Run = function(_Caller: Player, _Arguments: { string }): string
			local Success, Error = pcall(function()
				MessagingService:PublishAsync(Broadcasttopic, "Shutdown")
			end)
			if not Success then
				return "Broadcast failed: " .. tostring(Error)
			end
			return "Restart requested on every server"
		end,
	},
	{
		Name = "giveitem",
		Usage = "giveitem <player> <object|all> [percent]",
		Description = "Add a restored item to the inventory, or one of every object with all",
		Arguments = { "player", "object", "number" },
		Run = function(_Caller: Player, Arguments: { string }): string
			local Target = Findplayer(Arguments[1])
			if not Target then
				return "Player not found: " .. tostring(Arguments[1])
			end
			local Percent = math.clamp(tonumber(Arguments[3]) or 100, 0, 100)
			if string.lower(tostring(Arguments[2])) == "all" then
				local Count = 0
				for Objectkey in pairs(Objectconfig.Object) do
					Giveitem(Target, Objectkey, Percent)
					Count += 1
				end
				return string.format("%s received all %d objects (%d%%)", Target.Name, Count, Percent)
			end
			local Objectkey = Findkey(Objectconfig.Object, Arguments[2])
			if not Objectkey then
				return "Unknown object: " .. tostring(Arguments[2])
			end
			Giveitem(Target, Objectkey, Percent)
			return string.format("%s received %s (%d%%)", Target.Name, Objectkey, Percent)
		end,
	},
	{
		Name = "upgrade",
		Usage = "upgrade <player> <upgrade> <level>",
		Description = "Set the level of an upgrade",
		Arguments = { "player", "upgrade", "number" },
		Run = function(_Caller: Player, Arguments: { string }): string
			local Target = Findplayer(Arguments[1])
			if not Target then
				return "Player not found: " .. tostring(Arguments[1])
			end
			local Upgradename = Findkey(Upgradesconfig, Arguments[2])
			if not Upgradename then
				return "Unknown upgrade: " .. tostring(Arguments[2])
			end
			local Level = math.floor(tonumber(Arguments[3]) or 0)
			local Upgradeservice = Core:GetService("UpgradeService")
			Upgradeservice:EnsurePlayer(Target).Levels[Upgradename] = math.max(Level, 0)
			Upgradeservice:PushUpgrades(Target)
			return string.format("%s: %s level %d", Target.Name, Upgradename, math.max(Level, 0))
		end,
	},
	{
		Name = "boost",
		Usage = "boost <player> <type> <value>",
		Description = "reputation/sale = seconds, serverluck = level (whole server)",
		Arguments = { "player", "boost", "number" },
		Run = function(_Caller: Player, Arguments: { string }): string
			local Target = Findplayer(Arguments[1])
			if not Target then
				return "Player not found: " .. tostring(Arguments[1])
			end
			local Kind = string.lower(tostring(Arguments[2]))
			local Value = math.max(tonumber(Arguments[3]) or 0, 0)
			if Kind == "reputation" then
				Core:GetService("MonetizationService"):GrantReputationBoost(Target, Value)
				return string.format("%s: double reputation for %d s", Target.Name, Value)
			end
			if Kind == "sale" then
				Core:GetService("DailyRewardService"):GrantSaleBoost(Target, Value)
				return string.format("%s: sale bonus for %d s", Target.Name, Value)
			end
			if Kind == "serverluck" then
				local Level = math.max(math.floor(Value), 1)
				local Monetizationservice = Core:GetService("MonetizationService")
				local Purchases = math.max(Level - Monetizationservice:GetServerLuckLevel(), 1)
				local Granted = Monetizationservice:GrantServerLuck(Level, Purchases)
				local Minutes = math.floor(Purchases * Monetizationconfig.ServerReputationLuck.DurationPerPurchaseSeconds / 60)
				return if Granted then string.format("Server luck enabled (level %d, +%d min)", Level, Minutes) else "Invalid level"
			end
			return "Unknown type: " .. Kind .. " (reputation, sale, serverluck)"
		end,
	},
	{
		Name = "dailytask",
		Usage = "dailytask <player> [task]",
		Description = "Reroll today's daily tasks, optionally forcing one",
		Arguments = { "player", "task" },
		Run = function(_Caller: Player, Arguments: { string }): string
			local Target = Findplayer(Arguments[1])
			if not Target then
				return "Player not found: " .. tostring(Arguments[1])
			end
			local Taskid = Findkey(Dailytasksconfig.Tasks, Arguments[2])
			if Arguments[2] and not Taskid then
				return "Unknown task: " .. tostring(Arguments[2])
			end
			Core:GetService("DailyTaskService"):Reroll(Target, Taskid)
			return "Daily tasks rerolled for " .. Target.Name
		end,
	},
	{
		Name = "save",
		Usage = "save <player>",
		Description = "Force an immediate save",
		Arguments = { "player" },
		Run = function(_Caller: Player, Arguments: { string }): string
			local Target = Findplayer(Arguments[1])
			if not Target then
				return "Player not found: " .. tostring(Arguments[1])
			end
			local Saved, Reason = Core:GetService("DataService"):Save(Target)
			return if Saved then "Saved: " .. Target.Name else "Failed: " .. tostring(Reason)
		end,
	},
}

local function Findcommand(Name: string)
	for _, Command in ipairs(Commands) do
		if Command.Name == Name then
			return Command
		end
	end
	return nil
end

function Adminservice:Init()
	local function Enforceban(Player: Player)
		local Entry = Getban(Player.UserId)
		if type(Entry) == "table" and Player.Parent then
			Player:Kick(tostring(Entry.Reason or "You are banned from this game."))
		end
	end
	Players.PlayerAdded:Connect(function(Player)
		task.spawn(Enforceban, Player)
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(Enforceban, Player)
	end

	task.spawn(function()
		local Subscribed = pcall(function()
			MessagingService:SubscribeAsync(Broadcasttopic, function()
				Kickeveryone("The server is restarting. Please rejoin.")
			end)
			MessagingService:SubscribeAsync(Resettopic, function(Message)
				if Players:GetPlayerByUserId(Message.Data) then
					Wipeuser(Message.Data)
				end
			end)
		end)
		if not Subscribed then
			warn("AdminService: cross-server broadcast unavailable")
		end
	end)

	Remotemanager:OnServerInvoke(self.Name, "GetCommands", function(Player)
		if not Isadmin(Player) then
			return {}
		end
		local List = {}
		for _, Command in ipairs(Commands) do
			table.insert(List, {
				Name = Command.Name,
				Usage = Command.Usage,
				Description = Command.Description,
				Arguments = Command.Arguments or {},
			})
		end
		local Objectkeys = {}
		for Key in pairs(Objectconfig.Object) do
			table.insert(Objectkeys, Key)
		end
		table.sort(Objectkeys)
		table.insert(Objectkeys, 1, "all")
		local Upgradekeys = {}
		for Key in pairs(Upgradesconfig) do
			table.insert(Upgradekeys, Key)
		end
		table.sort(Upgradekeys)
		local Taskkeys = {}
		for Key in pairs(Dailytasksconfig.Tasks) do
			table.insert(Taskkeys, Key)
		end
		table.sort(Taskkeys)
		return {
			Commands = List,
			Options = {
				object = Objectkeys,
				upgrade = Upgradekeys,
				boost = { "reputation", "sale", "serverluck" },
				task = Taskkeys,
			},
		}
	end)

	Remotemanager:OnServerInvoke(self.Name, "RunCommand", function(Player, Text)
		if not Isadmin(Player) then
			return "Access denied"
		end
		if type(Text) ~= "string" then
			return "Invalid command"
		end
		local Arguments = {}
		for Word in string.gmatch(Text, "%S+") do
			table.insert(Arguments, Word)
		end
		local Name = string.lower(table.remove(Arguments, 1) or "")
		local Command = Findcommand(Name)
		if not Command then
			return "Unknown command: " .. Name
		end
		local Success, Result = pcall(Command.Run, Player, Arguments)
		if not Success then
			return "Error: " .. tostring(Result)
		end
		return tostring(Result)
	end)
end

return Adminservice
