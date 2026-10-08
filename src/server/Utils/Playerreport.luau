local Replicatedstorage = game:GetService("ReplicatedStorage")

local Codesconfig = require(script.Parent.Parent.Config.Codes)
local Customerconfig = require(Replicatedstorage.Shared.Config.Customer)
local Dailyrewardsconfig = require(Replicatedstorage.Shared.Config.DailyRewards)
local Dailytasksconfig = require(Replicatedstorage.Shared.Config.DailyTasks)
local Dayclock = require(Replicatedstorage.Shared.Utils.DayClock)
local Formatcurrency = require(Replicatedstorage.Shared.Utils.CurrencyFormatter)
local Formatduration = require(Replicatedstorage.Shared.Utils.DurationFormatter)
local Freerewardconfig = require(Replicatedstorage.Shared.Config.FreeReward)
local Indexrewards = require(Replicatedstorage.Shared.Config.IndexRewards)
local Monetizationconfig = require(Replicatedstorage.Shared.Config.Monetization)
local Mutationconfig = require(Replicatedstorage.Shared.Config.Mutation)
local Objectconfig = require(Replicatedstorage.Shared.Config.Object)
local Rarityconfig = require(Replicatedstorage.Shared.Config.Rarity)
local Separatenumber = require(Replicatedstorage.Shared.Utils.NumberAbbreviator)
local Upgradesconfig = require(Replicatedstorage.Shared.Config.Upgrades)

local Playerreport = {}

local Linelimit = 80
local Maximumlines = 2000
local Previewlines = 6
local Daylength = 86400
local Indent = "    "
local Optionnames = {
	"inventory",
	"exposition",
	"upgrades",
	"index",
	"cash",
	"stats",
	"monetization",
	"dailytasks",
	"dailyrewards",
	"customer",
	"restoration",
	"tutorial",
	"freereward",
	"codes",
	"settings",
	"leaderboard",
	"ban",
	"save",
	"all",
	"raw",
}
local Detailorder = {
	"cash",
	"stats",
	"upgrades",
	"exposition",
	"index",
	"restoration",
	"customer",
	"monetization",
	"dailytasks",
	"dailyrewards",
	"tutorial",
	"freereward",
	"codes",
	"settings",
	"leaderboard",
	"ban",
}
local Claimedsections = {
	Cash = true,
	Stats = true,
	Upgrades = true,
	Inventory = true,
	Restoration = true,
	Exposition = true,
	Monetization = true,
	Settings = true,
	Leaderboard = true,
	Codes = true,
	DailyTasks = true,
	Customer = true,
	FreeReward = true,
}
local Knownfields = {
	Stats = { ItemsSold = true, Reputation = true, RankedReputation = true, RobuxDonated = true },
	Upgrades = { Levels = true, EstimatesUsed = true, EstimateDay = true },
	Inventory = { Items = true, Index = true },
	Restoration = { PendingCleanAll = true },
	Monetization = { PersonalReputationBoostEndsAt = true, PersonalReputationBoostDuration = true, StarterPackGranted = true },
	DailyTasks = { Day = true, Tasks = true },
	Customer = { PendingSkips = true, CommonStreak = true, OfferBags = true },
	FreeReward = { Claimed = true },
	Leaderboard = {},
}
local Needsbyview = {
	overview = { Tutorial = true, Dailyrewards = true, Ban = true, Passes = true, Leaderboard = true },
	all = { Tutorial = true, Dailyrewards = true, Ban = true, Passes = true, Leaderboard = true, Group = true },
	upgrades = { Tutorial = true },
	monetization = { Dailyrewards = true, Passes = true },
	dailyrewards = { Dailyrewards = true },
	tutorial = { Tutorial = true },
	freereward = { Group = true },
	leaderboard = { Leaderboard = true },
	ban = { Ban = true },
}
local Boardnames = {
	Reputation = "Reputation",
	ItemSold = "Items sold",
	Donation = "Robux donated",
}
local Settingorder = { "Graphism", "Effect", "MusicVolume", "SoundEffect" }
local Settingnames = {
	Graphism = "Graphics",
	Effect = "Effects",
	MusicVolume = "Music",
	SoundEffect = "Sound effects",
}
local Saleboostreward = Dailyrewardsconfig.Rewards[4]
local Revealpercent = Mutationconfig.RevealRatio * 100

local Objectkeys = {}
for Objectkey in pairs(Objectconfig.Object) do
	table.insert(Objectkeys, Objectkey)
end
table.sort(Objectkeys, function(Left: string, Right: string): boolean
	return Objectconfig.Object[Left].Name < Objectconfig.Object[Right].Name
end)
local Requiredentries = math.ceil(#Objectkeys * Indexrewards.Ratio)

local Upgradeorder = {}
for Name in pairs(Upgradesconfig) do
	table.insert(Upgradeorder, Name)
end
table.sort(Upgradeorder, function(Left: string, Right: string): boolean
	return Upgradesconfig[Left].DisplayName < Upgradesconfig[Right].DisplayName
end)

local Activecodes = {}
for Code in pairs(Codesconfig) do
	Activecodes[string.upper((string.gsub(Code, "%s", "")))] = true
end

local function Clean(Value: any): string
	return (string.gsub(tostring(Value), "%c", " "))
end

local function Number(Value: any): number
	return tonumber(Value) or 0
end

local function Money(Value: any): string
	return Formatcurrency(Number(Value))
end

local function Amount(Value: any): string
	return Separatenumber(Number(Value))
end

local function Plural(Count: number, Word: string): string
	return Separatenumber(Count) .. " " .. Word .. (if Count == 1 then "" else "s")
end

local function Span(Seconds: number): string
	local Whole = math.max(math.floor(Seconds), 0)
	if Whole >= Daylength then
		return string.format("%dd%02dh", Whole // Daylength, Whole % Daylength // 3600)
	end
	return Formatduration(Whole)
end

local function Date(Seconds: number): string
	return os.date("!%Y-%m-%d %H:%M UTC", math.floor(Seconds))
end

local function Calendarday(Seconds: number): string
	return os.date("!%Y-%m-%d", math.floor(Seconds))
end

local function Spaced(Name: string): string
	return (string.gsub(Name, "(%l)(%u)", "%1 %2"))
end

local function Showscalar(Value: any): string
	if type(Value) == "string" then
		local Escaped = string.gsub(Value, "%c", function(Character: string): string
			return "\\" .. string.byte(Character)
		end)
		return '"' .. Escaped .. '"'
	end
	if type(Value) == "number" and Value == math.floor(Value) and math.abs(Value) < 1e15 then
		return string.format("%d", Value)
	end
	if type(Value) == "number" then
		return string.format("%.10g", Value)
	end
	return tostring(Value)
end

local function Keyorder(Left: any, Right: any): boolean
	if type(Left) ~= type(Right) then
		return type(Left) < type(Right)
	end
	return Left < Right
end

local function Sortedkeys(Value: { [any]: any }): { any }
	local Keys = {}
	for Key in pairs(Value) do
		table.insert(Keys, Key)
	end
	table.sort(Keys, Keyorder)
	return Keys
end

local function Childpath(Path: string, Key: any): string
	if type(Key) == "number" then
		return Path .. "[" .. Key .. "]"
	end
	return Path .. "." .. Clean(Key)
end

local function Inline(Value: any, Room: number): string?
	if type(Value) ~= "table" then
		local Text = Showscalar(Value)
		return if #Text <= Room then Text else nil
	end
	local Keys = Sortedkeys(Value)
	if #Keys == 0 then
		return if Room >= 2 then "{}" else nil
	end
	local Array = #Keys == #Value
	local Parts = {}
	local Used = 4
	for _, Key in ipairs(Keys) do
		local Prefix = if Array then "" elseif type(Key) == "number" then "[" .. Key .. "] = " else Clean(Key) .. " = "
		local Part = Inline(Value[Key], Room - Used - #Prefix)
		if not Part then
			return nil
		end
		Used += #Prefix + #Part + 2
		table.insert(Parts, Prefix .. Part)
	end
	return "{ " .. table.concat(Parts, ", ") .. " }"
end

local function Dump(Lines: { string }, Path: string, Value: any)
	local Text = Inline(Value, Linelimit - #Path - 3)
	if Text then
		table.insert(Lines, Path .. " = " .. Text)
	elseif type(Value) == "table" then
		for _, Key in ipairs(Sortedkeys(Value)) do
			Dump(Lines, Childpath(Path, Key), Value[Key])
		end
	else
		table.insert(Lines, Path .. " = " .. Showscalar(Value))
	end
end

local function Addjoined(Lines: { string }, Head: string, Parts: { string }, Separator: string)
	local Mark = string.match(Separator, "^(.-)%s*$") or Separator
	local Line = Head
	for Index, Part in ipairs(Parts) do
		if Index == 1 then
			Line ..= Part
		elseif #Line + #Separator + #Part + (if Index < #Parts then #Mark else 0) > Linelimit then
			table.insert(Lines, Line .. Mark)
			Line = Indent .. Part
		else
			Line ..= Separator .. Part
		end
	end
	table.insert(Lines, Line)
end

local function Isknown(Section: string, Key: any): boolean
	if Section == "Exposition" then
		return tonumber(Key) ~= nil
	end
	local Known = Knownfields[Section]
	return Known == nil or Known[Key] == true
end

local function Leftovers(Lines: { string }, Context: any, Section: string)
	local Value = Context.Data[Section]
	if type(Value) ~= "table" then
		return
	end
	for _, Key in ipairs(Sortedkeys(Value)) do
		if not Isknown(Section, Key) then
			Dump(Lines, Section .. "." .. Clean(Key), Value[Key])
		end
	end
end

local function Missing(Context: any, ...: string): string?
	if not Context.Live then
		if not Context.Readok then
			return "save unreadable"
		end
		return if Context.Stored ~= nil and type(Context.Stored) ~= "table" then "saved value is not a table" else nil
	end
	for _, Section in ipairs({ ... }) do
		if Context.Meta.Problems[Section] and not Context.Fromstore[Section] then
			return "no live or saved " .. Section
		end
	end
	return nil
end

local function Addunknown(Lines: { string }, Format: string, Reason: string?): boolean
	if Reason then
		table.insert(Lines, string.format(Format, Reason))
	end
	return Reason ~= nil
end

local function Receiptcount(Context: any): string
	return if Missing(Context) then "unknown" else tostring(#Context.Receipts)
end

local function Objectname(Objectkey: any): string
	local Definition = Objectconfig.Object[Objectkey]
	return if Definition then Definition.Name else Clean(Objectkey) .. " (removed object)"
end

local function Itemname(Item: any): string
	local Name = Clean(Item.Name or Item.ObjectKey)
	return if Objectconfig.Object[Item.ObjectKey] then Name else Name .. " (removed object)"
end

local function Ishidden(Item: any): boolean
	return tostring(Item.Mutation or "Normal") ~= "Normal" and Number(Item.RestorationPercent) < Revealpercent
end

local function Rarityname(Item: any): string
	local Mutation = tostring(Item.Mutation or "Normal")
	if Mutation == "Normal" then
		return Clean(Item.Rarity)
	end
	return Clean(Item.Rarity) .. " " .. Clean(Mutation) .. (if Ishidden(Item) then "?" else "")
end

local function Itemline(Item: any): string
	return string.format(
		"%s | %s | %d%% | %s | rep %s",
		Itemname(Item),
		Rarityname(Item),
		math.floor(Number(Item.RestorationPercent)),
		Money(Item.CurrentValue),
		Amount(Item.Reputation)
	)
end

local function Hiddenlegend(Lines: { string })
	table.insert(Lines, string.format("? = mutation the player cannot see yet (under %d%%)", Revealpercent))
end

local function Maxlevel(Name: string, Levels: { [string]: any }): number?
	local Definition = Upgradesconfig[Name]
	if Definition.MaxLevel then
		return math.max(math.floor(Definition.MaxLevel), Definition.DefaultLevel)
	end
	if Name == "PurchaseDiscount" then
		return math.max(math.floor(Definition.MaxPercent), Definition.DefaultLevel)
	end
	if Name == "PriceEstimation" then
		local Daily = Upgradesconfig.DailyCustomers
		return math.max(math.floor(tonumber(Levels.DailyCustomers) or Daily.DefaultLevel), Daily.DefaultLevel)
	end
	return nil
end

local function Upgradelevel(Name: string, Levels: { [string]: any }): (number, number?, number?)
	local Definition = Upgradesconfig[Name]
	local Stored = tonumber(Levels[Name])
	local Level = math.max(math.floor(Stored or Definition.DefaultLevel), Definition.DefaultLevel)
	local Maximum = Maxlevel(Name, Levels)
	if Maximum then
		Level = math.min(Level, Maximum)
	end
	return Level, Maximum, Stored
end

local function Savedlevels(Context: any): { [string]: any }
	local Upgrades = Context.Data.Upgrades
	return if Upgrades ~= nil and type(Upgrades.Levels) == "table" then Upgrades.Levels else {}
end

local function Upgradename(Name: string, Levels: { [string]: any }): string
	local Level, Maximum, Stored = Upgradelevel(Name, Levels)
	local Text = Upgradesconfig[Name].DisplayName .. " " .. Level .. (if Maximum then "/" .. Maximum else "")
	if Stored and math.floor(Stored) ~= Level then
		Text ..= " (stored " .. math.floor(Stored) .. ")"
	end
	return Text
end

local Upgradeeffects = {
	CooldownReduction = function(Level: number): string
		return "a customer every " .. Formatduration(Customerconfig.GetInterval(Level))
	end,
	DailyCustomers = function(Level: number): string
		return Plural(Level, "customer") .. " a day"
	end,
	DisplaySpace = function(Level: number): string
		return Plural(Level, "shelf slot")
	end,
	PriceEstimation = function(Level: number): string
		return Plural(Level, "estimate") .. " a day"
	end,
	PurchaseDiscount = function(Level: number): string
		return string.format("%d%% off customer prices", Level)
	end,
}

local function Workbenchitem(Context: any): any
	return if Context.Runtime then Context.Runtime.Workbench else nil
end

local function Inventoryentries(Context: any): { any }
	local Inventory = Context.Data.Inventory
	local Items = if Inventory ~= nil and type(Inventory.Items) == "table" then Inventory.Items else {}
	local Workbench = if Context.Fromstore.Inventory then nil else Workbenchitem(Context)
	local Entries = {}
	local Skipped = false
	for Index, Item in ipairs(Items) do
		if Workbench and not Skipped and Item.Id == Workbench.Id then
			Skipped = true
		else
			table.insert(Entries, { Item = Item, Index = Index })
		end
	end
	return Entries
end

local function Sortentries(Entries: { any }, Byid: boolean)
	table.sort(Entries, function(Left: any, Right: any): boolean
		local Leftpercent = math.clamp(Number(Left.Item.RestorationPercent), 0, 100)
		local Rightpercent = math.clamp(Number(Right.Item.RestorationPercent), 0, 100)
		local Leftdone = Leftpercent >= 100
		local Rightdone = Rightpercent >= 100
		if Leftdone ~= Rightdone then
			return Rightdone
		end
		if Leftdone then
			local Leftvalue = Number(Left.Item.CurrentValue)
			local Rightvalue = Number(Right.Item.CurrentValue)
			if Leftvalue ~= Rightvalue then
				return Leftvalue > Rightvalue
			end
		elseif Leftpercent ~= Rightpercent then
			return Leftpercent < Rightpercent
		end
		if Byid then
			local Leftid = Number(Left.Item.Id)
			local Rightid = Number(Right.Item.Id)
			if Leftid ~= Rightid then
				return Leftid > Rightid
			end
		end
		return Left.Index < Right.Index
	end)
end

local function Countparts(Counts: { [string]: number }, Order: { string }): { string }
	local Parts = {}
	for _, Name in ipairs(Order) do
		if Counts[Name] then
			table.insert(Parts, Name .. " " .. Counts[Name])
		end
	end
	for _, Name in ipairs(Sortedkeys(Counts)) do
		if not table.find(Order, Name) then
			table.insert(Parts, Name .. " " .. Counts[Name])
		end
	end
	return Parts
end

local function Readindex(Saved: any): ({ [string]: { [string]: boolean } }, { string })
	local Pages = {}
	for _, Mutation in ipairs(Mutationconfig.Order) do
		Pages[Mutation] = {}
	end
	local Ignored = {}
	if type(Saved) ~= "table" then
		return Pages, Ignored
	end
	for Key, Value in pairs(Saved) do
		if type(Value) == "table" and Pages[Key] then
			for Objectkey, Unlocked in pairs(Value) do
				Pages[Key][tostring(Objectkey)] = Unlocked == true
			end
		elseif type(Value) == "table" then
			table.insert(Ignored, Clean(Key))
		elseif Value == true then
			Pages.Normal[tostring(Key)] = true
		end
	end
	table.sort(Ignored)
	return Pages, Ignored
end

local function Pagecount(Page: { [string]: boolean }): number
	local Count = 0
	for _, Objectkey in ipairs(Objectkeys) do
		if Page[Objectkey] == true then
			Count += 1
		end
	end
	return Count
end

local function Indexpages(Context: any): ({ [string]: { [string]: boolean } }, number, { string })
	local Inventory = Context.Data.Inventory
	local Pages, Ignored = Readindex(if Inventory ~= nil then Inventory.Index else nil)
	local Complete = 0
	for _, Mutation in ipairs(Mutationconfig.Order) do
		if Pagecount(Pages[Mutation]) >= Requiredentries then
			Complete += 1
		end
	end
	return Pages, Complete, Ignored
end

local function Shelf(Context: any): (number, { [number]: any }, number, number)
	local Unlocked = Upgradelevel("DisplaySpace", Savedlevels(Context))
	local Saved = Context.Data.Exposition
	local Slots = {}
	local Highest = 0
	local Used = 0
	for Key, Item in pairs(if type(Saved) == "table" then Saved else {}) do
		local Slot = tonumber(Key)
		if Slot then
			Slots[Slot] = Item
			Highest = math.max(Highest, Slot)
			Used += 1
		end
	end
	return Unlocked, Slots, Highest, Used
end

local function Passowned(Context: any, Name: string): boolean?
	for _, Pass in ipairs(Context.Passes or {}) do
		if Pass.Name == Name then
			return Pass.Owned
		end
	end
	return nil
end

local function Passfactor(Context: any, Name: string, Factor: number): number?
	local Owned = Passowned(Context, Name)
	if Owned == nil then
		return nil
	end
	return if Owned then Factor else 1
end

local function Reputationboost(Context: any): (number, number)
	local Monetization = Context.Data.Monetization
	if Monetization == nil then
		return 0, 0
	end
	return math.max(Number(Monetization.PersonalReputationBoostEndsAt) - Context.Now, 0), Number(Monetization.PersonalReputationBoostDuration)
end

local function Saleboost(Context: any): number?
	local Rewards = Context.Dailyrewards
	if Rewards == nil or not Rewards.Ok then
		return nil
	end
	if Rewards.Value == nil then
		return 0
	end
	return math.max(Number(Rewards.Value.SaleBoostEndsAt) - Context.Now, 0)
end

local function Serverluck(Context: any): (number, number, number)
	local Runtime = Context.Runtime
	if not Runtime or Runtime.Serverluck <= 0 then
		return 0, 1, 0
	end
	local Level = Monetizationconfig.ServerReputationLuck.Levels[Runtime.Serverluck]
	return Runtime.Serverluck, Level.Multiplier, math.max(Runtime.Serverluckendsat - Context.Now, 0)
end

local function Starterpack(Context: any): string
	local Monetization = Context.Data.Monetization
	local Granted = if Monetization ~= nil then Monetization.StarterPackGranted else nil
	if Granted == true then
		return "given"
	end
	if Granted == false then
		return "not given"
	end
	return "not checked yet"
end

local function Rewardstatus(Value: any, Now: number): string
	local Count = #Dailyrewardsconfig.Rewards
	local Claimed = math.clamp(math.floor(Number(Value.ClaimedDays)), 0, Count)
	local Nextclaim = Number(Value.NextClaimAt)
	if Claimed >= Count and Nextclaim > 0 and Now >= Nextclaim then
		Claimed = 0
	end
	if Claimed >= Count then
		return string.format("%d/%d claimed, new cycle in %s", Claimed, Count, Span(Nextclaim - Now))
	end
	local Next = string.format("day %d (%s)", Claimed + 1, Dailyrewardsconfig.Rewards[Claimed + 1].ValueText)
	if Claimed == 0 or Now >= Nextclaim then
		return string.format("%d/%d claimed, %s ready", Claimed, Count, Next)
	end
	return string.format("%d/%d claimed, %s in %s", Claimed, Count, Next, Span(Nextclaim - Now))
end

local function Tutorialdone(Value: any): boolean
	return Value == true or type(Value) == "table" and Value.Completed == true
end

local function Tutorialstatus(Tutorial: any): string
	if Tutorial == nil then
		return "unknown"
	end
	if not Tutorial.Ok then
		return "unknown (read failed: " .. Clean(Tutorial.Value) .. ")"
	end
	local Value = Tutorial.Value
	if Value == nil then
		return "nothing saved (first session still running, or reset)"
	end
	if Tutorialdone(Value) then
		return "done"
	end
	if type(Value) == "table" then
		return "in progress, step " .. Amount(Value.Step) .. " reached"
	end
	return "in progress, step 1"
end

local function Banstatus(Ban: any): (string, string?)
	if Ban == nil then
		return "ban unknown", nil
	end
	if not Ban.Ok then
		return "ban unknown (read failed)", "Ban read failed: " .. Clean(Ban.Value)
	end
	if Ban.Value == nil then
		return "not banned", nil
	end
	if type(Ban.Value) ~= "table" then
		return "ban entry " .. Showscalar(Ban.Value), nil
	end
	return "banned",
		string.format("Banned %s by %s: %s", Date(Number(Ban.Value.Time)), Clean(Ban.Value.By), Clean(Ban.Value.Reason))
end

local function Taskamount(Definition: any, Value: any): string
	if Definition and Definition.Currency then
		return Formatcurrency(math.floor(Number(Value)))
	end
	return Separatenumber(Number(Value))
end

local function Tasktext(Task: any): string
	local Definition = Dailytasksconfig.Tasks[Task.Id]
	if not Definition then
		return Clean(Task.Id) .. " (removed task)"
	end
	return string.format(Definition.Text, Taskamount(Definition, Task.Goal))
end

local function Tasksdone(Tasks: { any }): number
	local Done = 0
	for _, Task in ipairs(Tasks) do
		if Task.Completed == true then
			Done += 1
		end
	end
	return Done
end

local function Settingparts(Settings: { [string]: any }, Lower: boolean): { string }
	local Names = {}
	for _, Name in ipairs(Settingorder) do
		if Settings[Name] ~= nil then
			table.insert(Names, Name)
		end
	end
	for _, Name in ipairs(Sortedkeys(Settings)) do
		if not table.find(Settingorder, Name) then
			table.insert(Names, Name)
		end
	end
	local Parts = {}
	for _, Name in ipairs(Names) do
		local Value = Settings[Name]
		local Label = Settingnames[Name] or Spaced(Clean(Name))
		local Text
		if Name == "Graphism" then
			Text = if Value == true then "high" else "low"
		elseif type(Value) == "boolean" then
			Text = if Value then "on" else "off"
		elseif Name == "MusicVolume" or Name == "SoundEffect" then
			Text = string.format("%d%%", math.round(Number(Value) * 100))
		else
			Text = Showscalar(Value)
		end
		table.insert(Parts, (if Lower then string.lower(Label) else Label) .. " " .. Text)
	end
	return Parts
end

local function Unclaimed(Context: any): { string }
	local Keys = {}
	for _, Key in ipairs(Sortedkeys(Context.Data)) do
		if not Claimedsections[Key] then
			table.insert(Keys, Key)
		end
	end
	return Keys
end

local function Finddatakey(Context: any, Text: string): string?
	local Lower = string.lower(Text)
	for Key in pairs(Context.Data) do
		if string.lower(tostring(Key)) == Lower then
			return Key
		end
	end
	for _, Name in ipairs(Context.Sectionorder) do
		if string.lower(Name) == Lower and not Claimedsections[Name] then
			return Name
		end
	end
	return nil
end

local function Prepare(Context: any)
	local Stored = if Context.Readok and type(Context.Stored) == "table" then Context.Stored else {}
	local Data = {}
	local Fromstore = {}
	local Internal = {}
	if Context.Live then
		for Key, Value in pairs(Context.Live) do
			Data[Key] = Value
		end
	end
	for Key, Value in pairs(Stored) do
		local Name = tostring(Key)
		if string.sub(Name, 1, 1) == "_" then
			Internal[Name] = Value
		elseif not Context.Live then
			Data[Name] = Value
		elseif Data[Name] == nil and (Context.Meta.Problems[Name] or not table.find(Context.Sectionorder, Name)) then
			Data[Name] = Value
			Fromstore[Name] = true
		end
	end
	Context.Data = Data
	Context.Fromstore = Fromstore
	Context.Internal = Internal
	Context.Receipts = if Context.Meta then Context.Meta.Purchases elseif type(Internal._Purchases) == "table" then Internal._Purchases else {}
	Context.Hint = if Context.Name == "Unknown" then tostring(Context.Userid) else Clean(Context.Name)
end

local function Header(Lines: { string }, Context: any)
	local Info = Context.Info
	local Session = if Info then Info.Session else nil
	local Where
	if Context.Here then
		local Shop = if Context.Runtime then Context.Runtime.Shop else nil
		Where = if Shop then "online here in " .. Clean(Shop) else "online here"
	elseif not Context.Readok then
		Where = "location unknown"
	elseif Session and Session.Active then
		Where = if Session.Studio
			then "online in a Studio test"
			elseif Session.Thisserver then "joining or leaving this server"
			else "online in another server (" .. string.sub(Session.Job, 1, 8) .. ")"
	elseif Session then
		Where = if Session.Thisserver then "offline (lock left by this server)" else "offline (lock left by a stopped server)"
	else
		Where = "offline"
	end
	table.insert(Lines, string.format("%s (%d) | %s", Clean(Context.Name), Context.Userid, Where))

	local Saved = Context.Readok and Context.Stored ~= nil and Info ~= nil
	if Context.Live then
		if not Context.Readok then
			table.insert(Lines, "Live data | saved copy unreadable: " .. Clean(Context.Stored))
		elseif Saved then
			table.insert(Lines, string.format("Live data | last save %s ago | first save %s", Span(Context.Clock - Info.Updated / 1000), Calendarday(Info.Created / 1000)))
		else
			table.insert(Lines, "Live data | not saved yet")
		end
	elseif not Context.Readok then
		table.insert(Lines, "Saved data unreadable: " .. Clean(Context.Stored))
	elseif Saved then
		table.insert(Lines, string.format("Saved data from %s (%s ago) | first save %s", Date(Info.Updated / 1000), Span(Context.Clock - Info.Updated / 1000), Calendarday(Info.Created / 1000)))
	else
		table.insert(Lines, "No save found (never played, or data reset)")
	end
	if Context.Liveerror then
		table.insert(Lines, "Live data unavailable (" .. Clean(Context.Liveerror) .. ")" .. (if Saved then ", saved copy shown" else ""))
	end
	if Context.Readok and Context.Stored ~= nil and type(Context.Stored) ~= "table" then
		table.insert(Lines, "Saved value is a " .. type(Context.Stored) .. ", not a table: " .. Showscalar(Context.Stored))
	elseif Saved and not Context.Live and next(Context.Data) == nil then
		table.insert(Lines, "Profile created, nothing saved yet")
	end
	if Context.Meta and Context.Meta.Unsaved then
		table.insert(Lines, "Warning: this session does not save (" .. Clean(Context.Meta.Unsaved) .. ")")
	end
	if Context.Meta then
		for _, Name in ipairs(Sortedkeys(Context.Meta.Problems)) do
			table.insert(Lines, string.format("Warning: %s %s, %s", Name, Clean(Context.Meta.Problems[Name]), if Context.Fromstore[Name] then "saved copy shown" else "no saved copy"))
		end
	end
end

local function Moneysummary(Lines: { string }, Context: any)
	if Addunknown(Lines, "Cash and stats unknown (%s)", Missing(Context, "Cash", "Stats")) then
		return
	end
	local Parts = {}
	if Context.Data.Cash ~= nil then
		table.insert(Parts, "Cash " .. Money(Context.Data.Cash))
	end
	local Stats = Context.Data.Stats
	if Stats ~= nil then
		table.insert(Parts, "reputation " .. Amount(Stats.Reputation))
		table.insert(Parts, "sold " .. Amount(Stats.ItemsSold))
		table.insert(Parts, "donated R$" .. Amount(Stats.RobuxDonated))
	end
	if #Parts > 0 then
		Addjoined(Lines, "", Parts, " | ")
	end
end

local function Offertext(Offer: any): string
	local Mutation = tostring(Offer.Mutation or "Normal")
	return string.format(
		"%s %s (base %s)%s, max value %s",
		Objectname(Offer.ObjectKey),
		Money(Offer.Price),
		Money(Offer.BasePrice),
		if Mutation == "Normal" then "" else ", " .. Clean(Mutation),
		Money(Offer.MaxValue)
	)
end

local function Todaysummary(Lines: { string }, Context: any)
	local Runtime = Context.Runtime
	if not Runtime then
		return
	end
	local Parts = {}
	if Runtime.Day then
		local Hour = math.floor(Runtime.Clocktime)
		local Minute = math.floor((Runtime.Clocktime - Hour) * 60)
		table.insert(Parts, string.format("Game day %s, %02d:%02d%s", Amount(Runtime.Day), Hour, Minute, if Dayclock.IsBusinessHours(Runtime.Clocktime) then "" else " (night)"))
	end
	if Runtime.Customerstoday and Runtime.Maxcustomers then
		table.insert(Parts, string.format("customers %s/%s", Amount(Runtime.Customerstoday), Amount(Runtime.Maxcustomers)))
	end
	if Runtime.Customersdone then
		table.insert(Parts, "quota reached")
	elseif Runtime.Offer then
		table.insert(Parts, "customer waiting")
	elseif Number(Runtime.Nextcustomerat) > Context.Now then
		table.insert(Parts, "next customer in " .. Span(Runtime.Nextcustomerat - Context.Now))
	else
		table.insert(Parts, "no customer coming")
	end
	table.insert(Parts, "profit today " .. Money(Runtime.Profittoday))
	Addjoined(Lines, "", Parts, " | ")
	if Runtime.Offer then
		table.insert(Lines, "Offer: " .. Offertext(Runtime.Offer))
	end
end

local function Upgradesummary(Lines: { string }, Context: any)
	if Addunknown(Lines, "Upgrades unknown (%s)", Missing(Context, "Upgrades")) then
		return
	end
	local Upgrades = Context.Data.Upgrades
	if Upgrades == nil then
		return
	end
	local Levels = Savedlevels(Context)
	local Parts = {}
	for _, Name in ipairs(Upgradeorder) do
		table.insert(Parts, Upgradename(Name, Levels))
	end
	for _, Name in ipairs(Sortedkeys(Levels)) do
		if Upgradesconfig[Name] == nil then
			table.insert(Parts, Clean(Name) .. " " .. Showscalar(Levels[Name]) .. " (not in config)")
		end
	end
	Addjoined(Lines, "Upgrades: ", Parts, ", ")
end

local function Expositionsummary(Lines: { string }, Context: any)
	if Addunknown(Lines, "Exposition unknown (%s)", Missing(Context, "Exposition", "Upgrades")) then
		return
	end
	if Context.Data.Exposition == nil and Context.Data.Upgrades == nil then
		return
	end
	local Unlocked, Slots, Highest, Used = Shelf(Context)
	local Last = math.max(Unlocked, Highest)
	if Last == 0 then
		table.insert(Lines, "Exposition: no slot unlocked yet")
		return
	end
	local Parts = {}
	local Slot = 1
	while Slot <= Last do
		local Item = Slots[Slot]
		local Locked = Slot > Unlocked
		local First = Slot
		local Text
		if Item then
			Text = Slot .. " " .. Itemname(Item)
			if tostring(Item.Mutation or "Normal") ~= "Normal" then
				Text ..= " (" .. Clean(Item.Mutation) .. ")"
			end
		else
			while Slot < Last and not Slots[Slot + 1] and (Slot + 1 > Unlocked) == Locked do
				Slot += 1
			end
			Text = (if First == Slot then tostring(First) else First .. "-" .. Slot) .. " empty"
		end
		table.insert(Parts, Text .. (if Locked then " (locked)" else ""))
		Slot += 1
	end
	Addjoined(Lines, string.format("Exposition %d/%d slots: ", Used, Unlocked), Parts, ", ")
end

local function Inventorysummary(Lines: { string }, Context: any)
	local Workbench = Workbenchitem(Context)
	local Reason = Missing(Context, "Inventory")
	if Reason then
		table.insert(Lines, "Inventory unknown (" .. Reason .. ")")
	elseif Context.Data.Inventory ~= nil then
		local Entries = Inventoryentries(Context)
		if #Entries == 0 then
			table.insert(Lines, "Inventory empty")
		else
			local Worth = 0
			local Restored = 0
			local Rarities = {}
			local Mutations = {}
			for _, Entry in ipairs(Entries) do
				local Item = Entry.Item
				Worth += Number(Item.CurrentValue)
				if Number(Item.RestorationPercent) >= 100 then
					Restored += 1
				end
				local Rarity = Clean(Item.Rarity)
				Rarities[Rarity] = (Rarities[Rarity] or 0) + 1
				local Mutation = Clean(Item.Mutation or "Normal")
				if Mutation ~= "Normal" then
					Mutations[Mutation] = (Mutations[Mutation] or 0) + 1
				end
			end
			table.insert(Lines, string.format("Inventory %s worth %s | %d restored, %d to clean", Plural(#Entries, "item"), Money(Worth), Restored, #Entries - Restored))
			local Groups = { table.concat(Countparts(Rarities, Rarityconfig.Order), ", ") }
			local Mutationparts = Countparts(Mutations, Mutationconfig.Order)
			if #Mutationparts > 0 then
				table.insert(Groups, table.concat(Mutationparts, ", "))
			end
			Addjoined(Lines, Indent, Groups, " | ")
		end
	end
	if Workbench then
		table.insert(Lines, "Workbench: " .. Itemline(Workbench))
	end
end

local function Indexsummary(Lines: { string }, Context: any)
	if Addunknown(Lines, "Index unknown (%s)", Missing(Context, "Inventory")) then
		return
	end
	if Context.Data.Inventory == nil then
		return
	end
	local Pages = Indexpages(Context)
	local Parts = {}
	for _, Mutation in ipairs(Mutationconfig.Order) do
		local Count = Pagecount(Pages[Mutation])
		table.insert(Parts, string.format("%s %d/%d%s", Mutation, Count, #Objectkeys, if Count >= Requiredentries then string.format(" (+%d%%)", Indexrewards.SellPercent) else ""))
	end
	Addjoined(Lines, "Index: ", Parts, ", ")
end

local function Savedsummary(Lines: { string }, Context: any)
	if Addunknown(Lines, "Saved for later unknown (%s)", Missing(Context, "Restoration", "Customer")) then
		return
	end
	local Restoration = Context.Data.Restoration
	local Customer = Context.Data.Customer
	if Restoration == nil and Customer == nil then
		return
	end
	table.insert(Lines, string.format(
		"Saved for later: Clean All %s, cooldown skips %s | common streak %s/%d",
		Amount(if Restoration ~= nil then Restoration.PendingCleanAll else 0),
		Amount(if Customer ~= nil then Customer.PendingSkips else 0),
		Amount(if Customer ~= nil then Customer.CommonStreak else 0),
		Rarityconfig.MaxCommonStreak
	))
end

local function Monetizationsummary(Lines: { string }, Context: any)
	local Reason = Missing(Context, "Monetization")
	if Context.Passes then
		local Owned = {}
		local Unknown = {}
		for _, Pass in ipairs(Context.Passes) do
			if Pass.Owned == true then
				table.insert(Owned, Spaced(Pass.Name))
			elseif Pass.Owned == nil then
				table.insert(Unknown, Spaced(Pass.Name))
			end
		end
		local Text = if #Owned > 0 then table.concat(Owned, ", ") else "none"
		if #Unknown > 0 then
			Text ..= " (unknown: " .. table.concat(Unknown, ", ") .. ")"
		end
		Addjoined(Lines, "", { "Passes: " .. Text, "starter pack reward " .. (if Reason then "unknown" else Starterpack(Context)) }, " | ")
	end
	local Parts = {}
	local Reputationleft = Reputationboost(Context)
	if Reason then
		table.insert(Parts, "reputation unknown")
	elseif Reputationleft > 0 then
		table.insert(Parts, string.format("reputation x%s %s", Separatenumber(Monetizationconfig.StarterPack.ReputationMultiplier), Span(Reputationleft)))
	end
	local Saleleft = Saleboost(Context)
	if Saleleft == nil then
		table.insert(Parts, "sell unknown")
	elseif Saleleft > 0 then
		table.insert(Parts, string.format("sell +%d%% %s", Saleboostreward.Percent, Span(Saleleft)))
	end
	local Lucklevel, Luckmultiplier, Luckleft = Serverluck(Context)
	if Lucklevel > 0 then
		table.insert(Parts, string.format("server luck x%s %s", Separatenumber(Luckmultiplier), Span(Luckleft)))
	end
	if #Parts == 0 then
		table.insert(Parts, "none")
	end
	Addjoined(Lines, "Boosts: ", Parts, " | ")
end

local function Dailysummary(Lines: { string }, Context: any)
	local Reason = Missing(Context, "DailyTasks")
	local Tasks = Context.Data.DailyTasks
	if Reason then
		table.insert(Lines, "Daily tasks unknown (" .. Reason .. ")")
	elseif Tasks ~= nil then
		local Day = Number(Tasks.Day)
		local List = Tasks.Tasks or {}
		if Day == math.floor(Context.Now / Daylength) then
			table.insert(Lines, string.format("Daily tasks %d/%d done, new ones in %s", Tasksdone(List), #List, Span((Day + 1) * Daylength - Context.Now)))
		else
			table.insert(Lines, "Daily tasks expired (from " .. Calendarday(Day * Daylength) .. "), new ones at next join")
		end
	end
	local Rewards = Context.Dailyrewards
	if Rewards and not Rewards.Ok then
		table.insert(Lines, "Daily reward unknown (read failed)")
	elseif Rewards and Rewards.Value == nil then
		table.insert(Lines, "Daily reward: nothing saved yet")
	elseif Rewards then
		table.insert(Lines, "Daily reward " .. Rewardstatus(Rewards.Value, Context.Now))
	end
end

local function Statussummary(Lines: { string }, Context: any)
	local Parts = {}
	if Context.Tutorial then
		table.insert(Parts, "Tutorial: " .. Tutorialstatus(Context.Tutorial))
	end
	local Freereward = Context.Data.FreeReward
	table.insert(Parts, "free reward " .. (if Missing(Context, "FreeReward") then "unknown" elseif Freereward ~= nil and Freereward.Claimed == true then "claimed" else "not claimed"))
	local Short, Detail = Banstatus(Context.Ban)
	table.insert(Parts, Short)
	Addjoined(Lines, "", Parts, " | ")
	if Detail then
		table.insert(Lines, Detail)
	end
end

local function Codessummary(Lines: { string }, Context: any)
	if Addunknown(Lines, "Codes unknown (%s)", Missing(Context, "Codes")) then
		return
	end
	local Codes = Context.Data.Codes
	if Codes == nil then
		return
	end
	local Parts = {}
	for _, Code in ipairs(Sortedkeys(Codes)) do
		table.insert(Parts, Clean(Code))
	end
	if #Parts == 0 then
		table.insert(Lines, "Codes: none")
		return
	end
	Addjoined(Lines, "Codes: ", Parts, ", ")
end

local function Settingssummary(Lines: { string }, Context: any)
	if Addunknown(Lines, "Settings unknown (%s)", Missing(Context, "Settings")) then
		return
	end
	local Settings = Context.Data.Settings
	if Settings == nil then
		return
	end
	Addjoined(Lines, "Settings: ", Settingparts(Settings, true), ", ")
end

local function Leaderboardsummary(Lines: { string }, Context: any)
	if not Context.Leaderboard then
		return
	end
	local Parts = {}
	for _, Entry in ipairs(Context.Leaderboard) do
		local Name = string.lower(Boardnames[Entry.Board] or Spaced(Entry.Board))
		if not Entry.Ok then
			table.insert(Parts, Name .. " unknown")
		elseif Entry.Value == nil then
			table.insert(Parts, Name .. " no entry")
		else
			table.insert(Parts, Name .. " " .. Amount(Entry.Value) .. (if Entry.Rank then " (#" .. Entry.Rank .. ")" else ""))
		end
	end
	if #Parts > 0 then
		Addjoined(Lines, "Leaderboards: ", Parts, " | ")
	end
end

local function Othersummary(Lines: { string }, Context: any)
	local Output = {}
	for _, Key in ipairs(Unclaimed(Context)) do
		local Block = {}
		Dump(Block, Clean(Key), Context.Data[Key])
		table.move(Block, 1, math.min(#Block, Previewlines), #Output + 1, Output)
		if #Block > Previewlines then
			table.insert(Output, string.format("%s... %d more: inspect %s %s", Indent, #Block - Previewlines, Context.Hint, string.lower(Clean(Key))))
		end
	end
	for _, Section in ipairs(Sortedkeys(Claimedsections)) do
		Leftovers(Output, Context, Section)
	end
	if #Output > 0 then
		table.insert(Lines, "== Other saved data ==")
		table.move(Output, 1, #Output, #Lines + 1, Lines)
	end
end

local function Cashview(Lines: { string }, Context: any)
	table.insert(Lines, "== Cash ==")
	local Reason = Missing(Context, "Cash")
	table.insert(Lines, if Reason then "Cash unknown (" .. Reason .. ")" elseif Context.Data.Cash ~= nil then "Cash " .. Money(Context.Data.Cash) else "No saved cash")
	if Context.Runtime then
		table.insert(Lines, "Profit today " .. Money(Context.Runtime.Profittoday) .. " (this game day, not saved)")
	end
end

local function Statsview(Lines: { string }, Context: any)
	if Addunknown(Lines, "== Stats: unknown (%s) ==", Missing(Context, "Stats")) then
		return
	end
	table.insert(Lines, "== Stats ==")
	local Stats = Context.Data.Stats
	if Stats == nil then
		table.insert(Lines, "No saved stats")
		return
	end
	table.insert(Lines, "Reputation " .. Amount(Stats.Reputation) .. " (shelf items with boosts)")
	table.insert(
		Lines,
		if Stats.RankedReputation == nil
			then "Leaderboard reputation not computed yet (next session)"
			else "Leaderboard reputation " .. Amount(Stats.RankedReputation) .. " (no boosts, 2x pass counts)"
	)
	table.insert(Lines, "Items sold " .. Amount(Stats.ItemsSold) .. " (sold at 1% or more)")
	table.insert(Lines, "Robux donated R$" .. Amount(Stats.RobuxDonated))
	Leftovers(Lines, Context, "Stats")
end

local function Upgradesview(Lines: { string }, Context: any)
	if Addunknown(Lines, "== Upgrades: unknown (%s) ==", Missing(Context, "Upgrades")) then
		return
	end
	table.insert(Lines, "== Upgrades ==")
	local Upgrades = Context.Data.Upgrades
	if Upgrades == nil then
		table.insert(Lines, "No saved upgrades (every upgrade at its default level)")
	end
	local Tutorial = Context.Tutorial
	local Intutorial = Tutorial ~= nil and Tutorial.Ok and not Tutorialdone(Tutorial.Value)
	local Levels = Savedlevels(Context)
	for _, Name in ipairs(Upgradeorder) do
		local Level, Maximum = Upgradelevel(Name, Levels)
		local Definition = Upgradesconfig[Name]
		local Price = if Maximum and Level >= Maximum
			then "max level"
			elseif Intutorial and Definition.TutorialFree and Level == Definition.DefaultLevel then "next free (tutorial)"
			else "next " .. Money(math.round(Definition.CashPriceLevel1 * Definition.PriceGrowth ^ Level)) .. (if Intutorial then " after the tutorial" else "")
		local Effect = Upgradeeffects[Name]
		local Parts = { Upgradename(Name, Levels) }
		if Effect then
			table.insert(Parts, Effect(Level))
		end
		table.insert(Parts, Price)
		Addjoined(Lines, "", Parts, " | ")
	end
	for _, Name in ipairs(Sortedkeys(Levels)) do
		if Upgradesconfig[Name] == nil then
			table.insert(Lines, Clean(Name) .. " level " .. Showscalar(Levels[Name]) .. " (not in the config)")
		end
	end
	if Upgrades ~= nil then
		local Estimates = Upgradelevel("PriceEstimation", Levels)
		table.insert(Lines, string.format("Price estimates used: %s of %d on game day %s", Amount(Upgrades.EstimatesUsed), Estimates, Amount(Upgrades.EstimateDay)))
	end
	if Tutorial == nil or not Tutorial.Ok then
		table.insert(Lines, "Tutorial unknown: prices assume it is done")
	end
	Leftovers(Lines, Context, "Upgrades")
end

local function Expositionview(Lines: { string }, Context: any)
	if Addunknown(Lines, "== Exposition: unknown (%s) ==", Missing(Context, "Exposition", "Upgrades")) then
		return
	end
	local Unlocked, Slots, Highest, Used = Shelf(Context)
	local Maximum = Upgradesconfig.DisplaySpace.MaxLevel
	table.insert(Lines, string.format("== Exposition: %s, %d of %d slots unlocked ==", Plural(Used, "item"), Unlocked, Maximum))
	local Last = math.max(Unlocked, Highest)
	local Reputation = 0
	local Hidden = false
	for Slot = 1, Last do
		local Item = Slots[Slot]
		local Label = if Slot > Unlocked then string.format("Slot %d (locked)", Slot) else "Slot " .. Slot
		if Item then
			Reputation += Number(Item.Reputation)
			Hidden = Hidden or Ishidden(Item)
			table.insert(Lines, Label .. ": " .. Itemline(Item))
		else
			table.insert(Lines, Label .. ": empty")
		end
	end
	if Last + 1 == Maximum then
		table.insert(Lines, string.format("Slot %d: locked", Maximum))
	elseif Last < Maximum then
		table.insert(Lines, string.format("Slots %d-%d: locked", Last + 1, Maximum))
	end
	if Used > 0 then
		table.insert(Lines, "Shelf reputation " .. Amount(Reputation) .. " before boosts")
	end
	if Hidden then
		Hiddenlegend(Lines)
	end
	Leftovers(Lines, Context, "Exposition")
end

local function Inventoryview(Lines: { string }, Context: any)
	if Addunknown(Lines, "== Inventory: unknown (%s) ==", Missing(Context, "Inventory")) then
		return
	end
	if Context.Data.Inventory == nil then
		table.insert(Lines, "== Inventory: nothing saved ==")
		return
	end
	local Entries = Inventoryentries(Context)
	local Worth = 0
	for _, Entry in ipairs(Entries) do
		Worth += Number(Entry.Item.CurrentValue)
	end
	if #Entries == 0 then
		table.insert(Lines, "== Inventory: empty ==")
	else
		table.insert(Lines, string.format("== Inventory: %s, worth %s before sale bonuses ==", Plural(#Entries, "item"), Money(Worth)))
	end
	local Workbench = Workbenchitem(Context)
	local Hidden = false
	if Workbench then
		Hidden = Ishidden(Workbench)
		table.insert(Lines, "Workbench: " .. Itemline(Workbench))
	end
	Sortentries(Entries, Context.Live ~= nil and not Context.Fromstore.Inventory)
	for Rank, Entry in ipairs(Entries) do
		Hidden = Hidden or Ishidden(Entry.Item)
		table.insert(Lines, string.format("%d. %s", Rank, Itemline(Entry.Item)))
	end
	if Hidden then
		Hiddenlegend(Lines)
	end
	Leftovers(Lines, Context, "Inventory")
end

local function Indexview(Lines: { string }, Context: any)
	if Addunknown(Lines, "== Index: unknown (%s) ==", Missing(Context, "Inventory")) then
		return
	end
	local Pages, Complete, Ignored = Indexpages(Context)
	table.insert(Lines, string.format("== Index: %d of %d pages complete, sale bonus +%d%% ==", Complete, #Mutationconfig.Order, Complete * Indexrewards.SellPercent))
	table.insert(Lines, string.format("A page gives +%d%% once %d of its %d objects are unlocked", Indexrewards.SellPercent, Requiredentries, #Objectkeys))
	for _, Mutation in ipairs(Mutationconfig.Order) do
		local Page = Pages[Mutation]
		local Count = Pagecount(Page)
		local Missing = Count * 2 > #Objectkeys
		local Names = {}
		for _, Objectkey in ipairs(Objectkeys) do
			if (Page[Objectkey] == true) ~= Missing then
				table.insert(Names, Objectconfig.Object[Objectkey].Name)
			end
		end
		local Head = string.format("%s %d/%d%s", Mutation, Count, #Objectkeys, if Count >= Requiredentries then string.format(" (+%d%%)", Indexrewards.SellPercent) else "")
		if #Names == 0 then
			table.insert(Lines, Head .. (if Missing then ", complete" else ""))
		else
			Addjoined(Lines, Head .. (if Missing then ", missing: " else ", unlocked: "), Names, ", ")
		end
		local Removed = {}
		for _, Objectkey in ipairs(Sortedkeys(Page)) do
			if Page[Objectkey] == true and not Objectconfig.Object[Objectkey] then
				table.insert(Removed, Clean(Objectkey))
			end
		end
		if #Removed > 0 then
			Addjoined(Lines, Indent .. "removed objects also unlocked: ", Removed, ", ")
		end
	end
	if #Ignored > 0 then
		Addjoined(Lines, "Unknown pages (ignored by the game): ", Ignored, ", ")
	end
end

local function Progressline(Progress: any): string
	return string.format(
		"%scleaned: dirt %s%s, ink %s, scratch %s, sticker %s | dirt layout v%s",
		Indent,
		Amount(Progress.Dirt),
		if Progress.DirtTotal ~= nil then " of " .. Amount(Progress.DirtTotal) else "",
		Amount(Progress.Ink),
		Amount(Progress.Scratch),
		Amount(Progress.Sticker),
		Clean(Progress.DirtVersion or "?")
	)
end

local function Restorationview(Lines: { string }, Context: any)
	table.insert(Lines, "== Restoration ==")
	local Restoration = Context.Data.Restoration
	local Reason = Missing(Context, "Restoration")
	if Reason then
		table.insert(Lines, "Clean All saved: unknown (" .. Reason .. ")")
	elseif Restoration == nil then
		table.insert(Lines, "Clean All saved: 0 (nothing saved)")
	else
		table.insert(Lines, "Clean All saved: " .. Amount(Restoration.PendingCleanAll) .. " (used when the player presses Clean All, no Robux)")
	end
	local Workbench = Workbenchitem(Context)
	if Workbench then
		table.insert(Lines, "Workbench: " .. Itemline(Workbench))
		if Workbench.Progress ~= nil then
			table.insert(Lines, Progressline(Workbench.Progress))
		end
		if Ishidden(Workbench) then
			Hiddenlegend(Lines)
		end
	elseif Context.Runtime then
		table.insert(Lines, "Workbench: empty")
	end
	Leftovers(Lines, Context, "Restoration")
end

local function Customerview(Lines: { string }, Context: any)
	table.insert(Lines, "== Customer ==")
	local Customer = Context.Data.Customer
	local Reason = Missing(Context, "Customer")
	if Reason then
		table.insert(Lines, "Saved customer data unknown (" .. Reason .. ")")
	elseif Customer == nil then
		table.insert(Lines, "Nothing saved (no skip, streak 0, offers freshly shuffled)")
	else
		table.insert(Lines, "Cooldown skips saved: " .. Amount(Customer.PendingSkips))
		table.insert(Lines, string.format("Common streak: %s/%d (at %d the next offer is Rare or better)", Amount(Customer.CommonStreak), Rarityconfig.MaxCommonStreak, Rarityconfig.MaxCommonStreak))
		local Bags = Customer.OfferBags or {}
		local Parts = {}
		for _, Rarity in ipairs(Rarityconfig.Order) do
			local Bag = Bags[Rarity]
			if Bag ~= nil and #Bag > 0 then
				table.insert(Parts, string.format("%s %s (%d left)", Rarity, Objectname(Bag[#Bag]), #Bag))
			else
				table.insert(Parts, Rarity .. " new shuffle")
			end
		end
		Addjoined(Lines, "Next offer per rarity: ", Parts, ", ")
	end
	Todaysummary(Lines, Context)
	Leftovers(Lines, Context, "Customer")
end

local function Factorline(Lines: { string }, Label: string, Factors: { { Name: string, Value: number? } })
	local Total = 1
	local Parts = {}
	local Known = true
	for _, Factor in ipairs(Factors) do
		if Factor.Value == nil then
			Known = false
			table.insert(Parts, Factor.Name .. " unknown")
		elseif Factor.Value ~= 1 then
			Total *= Factor.Value
			table.insert(Parts, Factor.Name .. " x" .. Separatenumber(Factor.Value))
		end
	end
	if #Parts == 0 then
		table.insert(Lines, Label .. ": x1")
	else
		Addjoined(Lines, Label .. (if Known then " x" .. Separatenumber(Total) else " unknown") .. ": ", Parts, ", ")
	end
end

local function Monetizationview(Lines: { string }, Context: any)
	table.insert(Lines, "== Monetization ==")
	local Passparts = {}
	for _, Pass in ipairs(Context.Passes or {}) do
		table.insert(Passparts, Spaced(Pass.Name) .. " " .. (if Pass.Owned == true then "yes" elseif Pass.Owned == false then "no" else "unknown"))
	end
	if #Passparts > 0 then
		Addjoined(Lines, "Passes: ", Passparts, ", ")
	end
	local Reason = Missing(Context, "Monetization")
	table.insert(Lines, "Starter pack reward: " .. (if Reason then "unknown (" .. Reason .. ")" else Starterpack(Context)))
	local Reputationleft, Reputationduration = Reputationboost(Context)
	local Reputationmultiplier = Monetizationconfig.StarterPack.ReputationMultiplier
	if Reason then
		table.insert(Lines, "Reputation boost: unknown (" .. Reason .. ")")
	elseif Reputationleft > 0 then
		table.insert(Lines, string.format("Reputation boost x%s: %s left (of %s)", Separatenumber(Reputationmultiplier), Span(Reputationleft), Span(Reputationduration)))
	else
		table.insert(Lines, "Reputation boost: none")
	end
	local Saleleft = Saleboost(Context)
	if Saleleft == nil then
		table.insert(Lines, "Sell boost: unknown (daily rewards unreadable)")
	elseif Saleleft > 0 then
		table.insert(Lines, string.format("Sell boost +%d%%: %s left", Saleboostreward.Percent, Span(Saleleft)))
	else
		table.insert(Lines, "Sell boost: none")
	end
	local Lucklevel, Luckmultiplier, Luckleft = Serverluck(Context)
	if Lucklevel > 0 then
		table.insert(Lines, string.format("Server luck (this server): level %d, x%s, %s left", Lucklevel, Separatenumber(Luckmultiplier), Span(Luckleft)))
	elseif Context.Runtime then
		table.insert(Lines, "Server luck (this server): none")
	end

	local Indexfactor = nil
	if not Missing(Context, "Inventory") then
		local _, Complete = Indexpages(Context)
		Indexfactor = 1 + Complete * Indexrewards.SellPercent / 100
	end
	Factorline(Lines, "Sale multiplier", {
		{ Name = "Double Money", Value = Passfactor(Context, "DoubleMoney", 2) },
		{ Name = "VIP", Value = Passfactor(Context, "VIP", 1 + Monetizationconfig.VIP.SaleBonusPercent / 100) },
		{ Name = "sell boost", Value = if Saleleft == nil then nil elseif Saleleft > 0 then 1 + Saleboostreward.Percent / 100 else 1 },
		{ Name = "index", Value = Indexfactor },
	})
	Factorline(Lines, "Reputation multiplier", {
		{ Name = "boost", Value = if Reason then nil elseif Reputationleft > 0 then Reputationmultiplier else 1 },
		{ Name = "server luck", Value = Luckmultiplier },
		{ Name = "Double Reputation", Value = Passfactor(Context, "DoubleReputation", 2) },
	})
	local Rewards = Context.Dailyrewards
	local Skips = if Rewards == nil or not Rewards.Ok then "unknown" elseif Rewards.Value == nil then "0" else tostring(#(Rewards.Value.ProcessedPurchases or {}))
	table.insert(Lines, string.format("Purchase receipts logged: %s | daily reward skips: %s", Receiptcount(Context), Skips))
	Leftovers(Lines, Context, "Monetization")
end

local function Dailytasksview(Lines: { string }, Context: any)
	if Addunknown(Lines, "== Daily tasks: unknown (%s) ==", Missing(Context, "DailyTasks")) then
		return
	end
	local Tasks = Context.Data.DailyTasks
	if Tasks == nil then
		table.insert(Lines, "== Daily tasks: nothing saved (new ones at next join) ==")
		return
	end
	local Day = Number(Tasks.Day)
	if Day == math.floor(Context.Now / Daylength) then
		table.insert(Lines, string.format("== Daily tasks (UTC %s, new ones in %s) ==", Calendarday(Day * Daylength), Span((Day + 1) * Daylength - Context.Now)))
	else
		table.insert(Lines, string.format("== Daily tasks from UTC %s (expired, new ones at next join) ==", Calendarday(Day * Daylength)))
	end
	for _, Task in ipairs(Tasks.Tasks or {}) do
		local Definition = Dailytasksconfig.Tasks[Task.Id]
		table.insert(Lines, string.format(
			"%s: %s/%s | reward %s%s",
			Tasktext(Task),
			Taskamount(Definition, Task.Progress),
			Taskamount(Definition, Task.Goal),
			Money(Task.Reward),
			if Task.Completed == true then " | done" else ""
		))
	end
	Leftovers(Lines, Context, "DailyTasks")
end

local function Dailyrewardsview(Lines: { string }, Context: any)
	table.insert(Lines, "== Daily rewards ==")
	local Rewards = Context.Dailyrewards
	if not Rewards.Ok then
		table.insert(Lines, "Unknown, read failed: " .. Clean(Rewards.Value))
		return
	end
	local Value = Rewards.Value
	if Value == nil then
		table.insert(Lines, "Nothing saved (first session still running, or reset)")
		return
	end
	table.insert(Lines, Rewardstatus(Value, Context.Now))
	local Nextclaim = Number(Value.NextClaimAt)
	if Nextclaim > 0 then
		table.insert(Lines, "Last claim " .. Date(Nextclaim - Dailyrewardsconfig.ClaimIntervalSeconds))
	end
	local Saleleft = math.max(Number(Value.SaleBoostEndsAt) - Context.Now, 0)
	table.insert(Lines, if Saleleft > 0 then string.format("Sell boost +%d%%: %s left", Saleboostreward.Percent, Span(Saleleft)) else "Sell boost: none")
	table.insert(Lines, "Skip purchases processed: " .. #(Value.ProcessedPurchases or {}))
end

local function Tutorialview(Lines: { string }, Context: any)
	table.insert(Lines, "== Tutorial ==")
	table.insert(Lines, "Tutorial: " .. Tutorialstatus(Context.Tutorial) .. (if Context.Tutorial.Live then " (live)" else ""))
end

local function Freerewardview(Lines: { string }, Context: any)
	table.insert(Lines, "== Free reward ==")
	local Freereward = Context.Data.FreeReward
	local Claimed = Freereward ~= nil and Freereward.Claimed == true
	local Reason = Missing(Context, "FreeReward")
	local Status = if Reason then "Claim status unknown, " .. Reason elseif Claimed then "Claimed" else "Not claimed"
	table.insert(Lines, string.format("%s (%s for joining group %d)", Status, Money(Freerewardconfig.Cash), Freerewardconfig.GroupId))
	local Group = Context.Group
	if Group then
		table.insert(Lines, "Group member: " .. (if not Group.Ok then "unknown (" .. Clean(Group.Value) .. ")" elseif Group.Value then "yes" else "no"))
	end
	Leftovers(Lines, Context, "FreeReward")
end

local function Codesview(Lines: { string }, Context: any)
	if Addunknown(Lines, "== Codes: unknown (%s) ==", Missing(Context, "Codes")) then
		return
	end
	local Codes = Context.Data.Codes or {}
	local Keys = Sortedkeys(Codes)
	table.insert(Lines, string.format("== Codes (%d) ==", #Keys))
	if #Keys == 0 then
		table.insert(Lines, "No code redeemed")
	end
	for _, Code in ipairs(Keys) do
		local Notes = {}
		if not Activecodes[Code] then
			table.insert(Notes, "not in the config anymore")
		end
		if Codes[Code] ~= true then
			table.insert(Notes, "stored as " .. Showscalar(Codes[Code]))
		end
		table.insert(Lines, Clean(Code) .. (if #Notes > 0 then " (" .. table.concat(Notes, ", ") .. ")" else ""))
	end
end

local function Settingsview(Lines: { string }, Context: any)
	if Addunknown(Lines, "== Settings: unknown (%s) ==", Missing(Context, "Settings")) then
		return
	end
	table.insert(Lines, "== Settings ==")
	local Settings = Context.Data.Settings
	if Settings == nil then
		table.insert(Lines, "Nothing saved (defaults)")
		return
	end
	for _, Part in ipairs(Settingparts(Settings, false)) do
		table.insert(Lines, Part)
	end
end

local function Leaderboardview(Lines: { string }, Context: any)
	table.insert(Lines, "== Leaderboards (stored scores, rank in the top 100) ==")
	for _, Entry in ipairs(Context.Leaderboard) do
		local Name = Boardnames[Entry.Board] or Spaced(Entry.Board)
		if not Entry.Ok then
			table.insert(Lines, Name .. ": unknown (" .. Clean(Entry.Value) .. ")")
		elseif Entry.Value == nil then
			table.insert(Lines, Name .. ": no entry")
		else
			table.insert(Lines, Name .. ": " .. Amount(Entry.Value) .. (if Entry.Rank then " (#" .. Entry.Rank .. ")" else " (not in the top 100)"))
		end
	end
	Leftovers(Lines, Context, "Leaderboard")
end

local function Banview(Lines: { string }, Context: any)
	table.insert(Lines, "== Ban ==")
	local Short, Detail = Banstatus(Context.Ban)
	table.insert(Lines, Detail or (string.upper(string.sub(Short, 1, 1)) .. string.sub(Short, 2)))
end

local function Saveview(Lines: { string }, Context: any)
	table.insert(Lines, string.format("== Save (PlayerData_v1, key %d) ==", Context.Userid))
	local Info = Context.Info
	if not Context.Readok then
		table.insert(Lines, "Saved copy unreadable: " .. Clean(Context.Stored))
	elseif Context.Stored == nil or Info == nil then
		table.insert(Lines, "No saved copy")
	else
		table.insert(Lines, string.format("Created %s | updated %s", Date(Info.Created / 1000), Date(Info.Updated / 1000)))
		table.insert(Lines, "Version " .. Clean(Info.Version))
		local Session = Info.Session
		if Session then
			table.insert(Lines, string.format(
				"Session lock: %s, save #%d, %s old (%s)",
				if Session.Studio then "Studio" elseif Session.Thisserver then "this server" else "server " .. string.sub(Session.Job, 1, 8),
				Session.Seq,
				Span(Context.Clock - Session.Time),
				if Session.Active then "active" else "expired"
			))
		else
			table.insert(Lines, "Session lock: none (released)")
		end
	end
	if Context.Meta then
		local Problems = Sortedkeys(Context.Meta.Problems)
		table.insert(Lines, string.format(
			"This server: save #%d | new player %s | not saving: %s",
			Context.Meta.Seq,
			if Context.Meta.New then "yes" else "no",
			if Context.Meta.Unsaved then "everything" elseif #Problems > 0 then table.concat(Problems, ", ") else "none"
		))
	end
	table.insert(Lines, "Purchase receipts logged: " .. Receiptcount(Context))
	for _, Key in ipairs(Sortedkeys(Context.Internal)) do
		if Key ~= "_Session" and Key ~= "_Purchases" then
			Dump(Lines, Key, Context.Internal[Key])
		end
	end
end

local function Rawview(Lines: { string }, Context: any)
	table.insert(Lines, if Context.Live then "== Raw data (live sections, then stored internal keys) ==" else "== Raw saved data ==")
	for _, Key in ipairs(Sortedkeys(Context.Data)) do
		Dump(Lines, Clean(Key), Context.Data[Key])
	end
	for _, Key in ipairs(Sortedkeys(Context.Internal)) do
		Dump(Lines, Key, Context.Internal[Key])
	end
end

local Overview = {
	{ Title = "Money", Sections = { "Cash", "Stats" }, Run = Moneysummary },
	{ Title = "Today", Sections = {}, Run = Todaysummary },
	{ Title = "Upgrades", Sections = { "Upgrades" }, Run = Upgradesummary },
	{ Title = "Exposition", Sections = { "Exposition" }, Run = Expositionsummary },
	{ Title = "Inventory", Sections = { "Inventory" }, Run = Inventorysummary },
	{ Title = "Index", Sections = {}, Run = Indexsummary },
	{ Title = "Saved for later", Sections = { "Restoration", "Customer" }, Run = Savedsummary },
	{ Title = "Monetization", Sections = { "Monetization" }, Run = Monetizationsummary },
	{ Title = "Daily", Sections = { "DailyTasks" }, Run = Dailysummary },
	{ Title = "Status", Sections = { "FreeReward" }, Run = Statussummary },
	{ Title = "Codes", Sections = { "Codes" }, Run = Codessummary },
	{ Title = "Settings", Sections = { "Settings" }, Run = Settingssummary },
	{ Title = "Leaderboards", Sections = {}, Run = Leaderboardsummary },
	{ Title = "Other data", Sections = {}, Run = Othersummary },
}

local Views = {
	cash = { Title = "Cash", Sections = { "Cash" }, Run = Cashview },
	stats = { Title = "Stats", Sections = { "Stats" }, Run = Statsview },
	upgrades = { Title = "Upgrades", Sections = { "Upgrades" }, Run = Upgradesview },
	exposition = { Title = "Exposition", Sections = { "Exposition" }, Run = Expositionview },
	inventory = { Title = "Inventory", Sections = { "Inventory" }, Run = Inventoryview },
	index = { Title = "Index", Sections = {}, Run = Indexview },
	restoration = { Title = "Restoration", Sections = { "Restoration" }, Run = Restorationview },
	customer = { Title = "Customer", Sections = { "Customer" }, Run = Customerview },
	monetization = { Title = "Monetization", Sections = { "Monetization" }, Run = Monetizationview },
	dailytasks = { Title = "Daily tasks", Sections = { "DailyTasks" }, Run = Dailytasksview },
	dailyrewards = { Title = "Daily rewards", Sections = {}, Run = Dailyrewardsview },
	tutorial = { Title = "Tutorial", Sections = {}, Run = Tutorialview },
	freereward = { Title = "Free reward", Sections = { "FreeReward" }, Run = Freerewardview },
	codes = { Title = "Codes", Sections = { "Codes" }, Run = Codesview },
	settings = { Title = "Settings", Sections = { "Settings" }, Run = Settingsview },
	leaderboard = { Title = "Leaderboards", Sections = {}, Run = Leaderboardview },
	ban = { Title = "Ban", Sections = {}, Run = Banview },
	save = { Title = "Save", Sections = {}, Run = Saveview },
}

local function Run(Lines: { string }, Part: any, Context: any)
	local Output = {}
	local Success, Error = pcall(Part.Run, Output, Context)
	if Success then
		table.move(Output, 1, #Output, #Lines + 1, Lines)
		return
	end
	table.insert(Lines, "== " .. Part.Title .. ": could not be formatted ==")
	table.insert(Lines, "Error " .. (string.gsub(Clean(Error), "^.-:(%d+): ", "line %1: ")))
	for _, Section in ipairs(Part.Sections) do
		if Context.Data[Section] ~= nil then
			Dump(Lines, Section, Context.Data[Section])
		end
	end
end

local function Generic(Lines: { string }, Context: any, Key: string)
	local Reason = Missing(Context, Key)
	if Reason then
		table.insert(Lines, "== " .. Clean(Key) .. ": unknown (" .. Reason .. ") ==")
		return
	end
	table.insert(Lines, "== " .. Clean(Key) .. (if Context.Fromstore[Key] then " (saved copy) ==" else " =="))
	if Context.Data[Key] == nil then
		table.insert(Lines, "No saved data")
		return
	end
	Dump(Lines, Clean(Key), Context.Data[Key])
end

local function Fit(Lines: { string }): { string }
	local Fitted = {}
	for _, Line in ipairs(Lines) do
		if #Line <= Linelimit then
			table.insert(Fitted, Line)
		else
			local Margin = string.match(Line, "^%s*") or ""
			Addjoined(Fitted, Margin, string.split(string.sub(Line, #Margin + 1), " "), " ")
		end
	end
	return Fitted
end

local function Cap(Lines: { string }): { string }
	if #Lines <= Maximumlines then
		return Lines
	end
	local Kept = table.move(Lines, 1, Maximumlines - 1, 1, {})
	table.insert(Kept, string.format("... %d more lines not shown", #Lines - #Kept))
	return Kept
end

function Playerreport.Sections(Sectionorder: { string }): { string }
	local Names = table.clone(Optionnames)
	for _, Name in ipairs(Sectionorder) do
		if not Claimedsections[Name] then
			table.insert(Names, string.lower(Name))
		end
	end
	return Names
end

function Playerreport.Resolve(Names: { string }, Text: string): string?
	local Lower = string.lower(Text)
	for _, Name in ipairs(Names) do
		if Name == Lower then
			return Name
		end
	end
	for _, Name in ipairs(Names) do
		if string.sub(Name, 1, #Lower) == Lower then
			return Name
		end
	end
	return nil
end

function Playerreport.Needs(View: string): { [string]: boolean }
	return Needsbyview[View] or {}
end

function Playerreport.Build(Context: any, View: string): { string }
	Prepare(Context)
	local Datakey = nil
	if not Views[View] and View ~= "overview" and View ~= "all" and View ~= "raw" then
		Datakey = Finddatakey(Context, View)
		if not Datakey then
			local Lines = { "Unknown section: " .. Clean(View) }
			Addjoined(Lines, "Sections: ", Playerreport.Sections(Context.Sectionorder), ", ")
			return Fit(Lines)
		end
	end
	local Lines = {}
	Header(Lines, Context)
	if View == "overview" then
		for _, Part in ipairs(Overview) do
			Run(Lines, Part, Context)
		end
		table.insert(Lines, string.format("Details: inspect %s <section>, e.g. inventory or all", Context.Hint))
	elseif View == "all" then
		for _, Name in ipairs(Detailorder) do
			Run(Lines, Views[Name], Context)
		end
		for _, Key in ipairs(Unclaimed(Context)) do
			Generic(Lines, Context, Key)
		end
		Run(Lines, Views.save, Context)
		Run(Lines, Views.inventory, Context)
	elseif View == "raw" then
		Rawview(Lines, Context)
	elseif Datakey then
		Generic(Lines, Context, Datakey)
	else
		Run(Lines, Views[View], Context)
	end
	return Cap(Fit(Lines))
end

return Playerreport
