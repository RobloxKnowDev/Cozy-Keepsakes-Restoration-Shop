local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Mutationconfig = require(Replicatedstorage.Shared.Config.Mutation)
local Objectconfig = require(Replicatedstorage.Shared.Config.Object)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Inventoryservice = {
	Name = "InventoryService",
	Priority = 7,
	Remotes = {
		GetIndexEntries = "Function",
		GetRestoredItems = "Function",
		IndexUpdated = "Event",
		SellAllRestoredItems = "Function",
		SellRestoredItem = "Function",
		RestoredItemsUpdated = "Event",
	},
}

type RestoredItem = {
	Id: number,
	ObjectKey: string,
	Name: string,
	ImageId: string,
	Rarity: string,
	Mutation: string,
	RestorationPercent: number,
	PurchasePrice: number,
	CurrentValue: number,
	MaxValue: number,
	MaxReputation: number,
	NetProfit: number,
	Reputation: number,
}

type IndexEntry = {
	ObjectKey: string,
	Name: string,
	ImageId: string,
	Rarity: string,
	Unlocked: { [string]: boolean },
}

local ItemsByPlayer: { [Player]: { RestoredItem } } = {}
local IndexByPlayer: { [Player]: { [string]: { [string]: boolean } } } = {}
local NextItemId = 0

local function CloneItem(Item: RestoredItem): RestoredItem
	return {
		Id = Item.Id,
		ObjectKey = Item.ObjectKey,
		Name = Item.Name,
		ImageId = Item.ImageId,
		Rarity = Item.Rarity,
		Mutation = Item.Mutation or "Normal",
		RestorationPercent = Item.RestorationPercent,
		PurchasePrice = Item.PurchasePrice,
		CurrentValue = Item.CurrentValue,
		MaxValue = Item.MaxValue,
		MaxReputation = Item.MaxReputation or Item.Reputation,
		Progress = Item.Progress,
		NetProfit = Item.NetProfit,
		Reputation = Item.Reputation,
	}
end

local function ApplySaleMultiplier(BaseValue: number, Multiplier: number): number
	return math.round(BaseValue * Multiplier * 100) / 100
end

local function Newindex(): { [string]: { [string]: boolean } }
	local Index = {}
	for _, Mutation in ipairs(Mutationconfig.Order) do
		Index[Mutation] = {}
	end
	return Index
end

local function Readsavedindex(Saved: any): { [string]: { [string]: boolean } }
	local Index = Newindex()
	if type(Saved) ~= "table" then
		return Index
	end
	for Key, Value in pairs(Saved) do
		if type(Value) == "table" then
			for Objectkey, Unlocked in pairs(Value) do
				if Index[Key] then
					Index[Key][tostring(Objectkey)] = Unlocked == true
				end
			end
		elseif Value == true then
			Index.Normal[tostring(Key)] = true
		end
	end
	return Index
end

function Inventoryservice:EnsurePlayer(Player: Player): { RestoredItem }
	local Items = ItemsByPlayer[Player]
	if not Items then
		Items = {}
		ItemsByPlayer[Player] = Items
	end

	if not IndexByPlayer[Player] then
		IndexByPlayer[Player] = Newindex()
	end

	return Items
end

function Inventoryservice:GetIndexEntries(Player: Player): { IndexEntry }
	self:EnsurePlayer(Player)
	local Index = IndexByPlayer[Player]
	local Entries = {}

	for ObjectKey, Definition in pairs(Objectconfig.Object) do
		local Unlocked = {}
		for _, Mutation in ipairs(Mutationconfig.Order) do
			Unlocked[Mutation] = Index[Mutation][ObjectKey] == true
		end
		table.insert(Entries, {
			ObjectKey = ObjectKey,
			Name = tostring(Definition.Name or ObjectKey),
			ImageId = tostring(Definition.IdImage or ""),
			Rarity = tostring(Definition.Rarity or Definition.Rarety or "Common"),
			Unlocked = Unlocked,
		})
	end

	table.sort(Entries, function(Left, Right)
		return Left.Name < Right.Name
	end)

	return Entries
end

function Inventoryservice:GetRestoredItems(Player: Player): { RestoredItem }
	local Multiplier = Core:GetService("MonetizationService"):GetSaleMultiplier(Player)
	if not Player.Parent then return {} end
	local Items = self:EnsurePlayer(Player)
	local Result = {}
	for Index, Item in ipairs(Items) do
		local DisplayItem = CloneItem(Item)
		DisplayItem.CurrentValue = ApplySaleMultiplier(Item.CurrentValue, Multiplier)
		DisplayItem.NetProfit = math.round((DisplayItem.CurrentValue - DisplayItem.PurchasePrice) * 100) / 100
		DisplayItem.Revealed = (tonumber(Item.RestorationPercent) or 0) / 100 >= Mutationconfig.RevealRatio
		if not DisplayItem.Revealed then
			DisplayItem.Mutation = nil
		end
		Result[Index] = DisplayItem
	end
	return Result
end

function Inventoryservice:PushItems(Player: Player)
	local Items = self:GetRestoredItems(Player)
	if not Player.Parent then return end
	Remotemanager:FireClient(self.Name, "RestoredItemsUpdated", Player, Items)
end

function Inventoryservice:PushIndex(Player: Player, Unlockedkey: string?, Mutation: string?)
	Remotemanager:FireClient(self.Name, "IndexUpdated", Player, self:GetIndexEntries(Player), Unlockedkey, Mutation)
end

function Inventoryservice:AddRestoredItem(Player: Player, Item: RestoredItem): RestoredItem
	local Items = self:EnsurePlayer(Player)
	NextItemId += 1

	local Stored = CloneItem(Item)
	Stored.Id = NextItemId
	table.insert(Items, 1, Stored)
	self:PushItems(Player)
	return CloneItem(Stored)
end

function Inventoryservice:AddPurchasedItem(Player: Player, ObjectKey: string, Maximums: any, PurchasePrice: number): RestoredItem
	local Definition = Objectconfig.Object[ObjectKey]
	return self:AddRestoredItem(Player, {
		Id = 0,
		ObjectKey = ObjectKey,
		Name = Definition.Name or ObjectKey,
		ImageId = tostring(Definition.IdImage or ""),
		Rarity = tostring(Definition.Rarity or "Common"),
		Mutation = Maximums.Mutation or "Normal",
		RestorationPercent = 0,
		PurchasePrice = PurchasePrice,
		CurrentValue = 0,
		MaxValue = Maximums.MaxValue,
		MaxReputation = Maximums.MaxReputation,
		NetProfit = -PurchasePrice,
		Reputation = 0,
	})
end

function Inventoryservice:GetRestoredItem(Player: Player, ItemId: number): RestoredItem?
	local Items = self:EnsurePlayer(Player)
	for _, Item in ipairs(Items) do
		if Item.Id == ItemId then
			return CloneItem(Item)
		end
	end
	return nil
end

function Inventoryservice:TakeRestoredItem(Player: Player, ItemId: number): RestoredItem?
	local Items = self:EnsurePlayer(Player)
	for Index, Item in ipairs(Items) do
		if Item.Id == ItemId then
			table.remove(Items, Index)
			self:PushItems(Player)
			return CloneItem(Item)
		end
	end
	return nil
end

function Inventoryservice:ReturnRestoredItem(Player: Player, Item: RestoredItem): RestoredItem
	local Items = self:EnsurePlayer(Player)
	local Stored = CloneItem(Item)
	table.insert(Items, 1, Stored)
	self:PushItems(Player)
	return CloneItem(Stored)
end

function Inventoryservice:UnlockIndexEntry(Player: Player, ObjectKey: string, Mutation: string): boolean
	self:EnsurePlayer(Player)

	local Page = IndexByPlayer[Player][tostring(Mutation)]
	if ObjectKey == "" or Objectconfig.Object[ObjectKey] == nil or not Page then
		return false
	end
	if Page[ObjectKey] == true then
		return false
	end

	Page[ObjectKey] = true
	self:PushIndex(Player, ObjectKey, Mutation)
	return true
end

function Inventoryservice:SellRestoredItem(Player: Player, ItemId: number)
	local Multiplier = Core:GetService("MonetizationService"):GetSaleMultiplier(Player)
	local Items = self:EnsurePlayer(Player)
	local Index = nil
	for CurrentIndex, Item in ipairs(Items) do
		if Item.Id == ItemId then
			Index = CurrentIndex
			break
		end
	end
	if not Index then
		return nil
	end

	local Item = table.remove(Items, Index)
	local SaleValue = ApplySaleMultiplier(Item.CurrentValue, Multiplier)
	Core:GetService("CashService"):AddCash(Player, SaleValue)
	Core:GetService("StatsService"):AddItemsSold(Player, 1)
	self:PushItems(Player)
	local SoldItem = CloneItem(Item)
	SoldItem.CurrentValue = SaleValue
	SoldItem.NetProfit = math.round((SaleValue - SoldItem.PurchasePrice) * 100) / 100
	return SoldItem
end

function Inventoryservice:SellAllRestoredItems(Player: Player)
	local Multiplier = Core:GetService("MonetizationService"):GetSaleMultiplier(Player)
	local Items = self:EnsurePlayer(Player)
	local SoldItems = {}
	local TotalValue = 0

	for Index = #Items, 1, -1 do
		local Item = table.remove(Items, Index)
		table.insert(SoldItems, 1, CloneItem(Item))
		TotalValue += ApplySaleMultiplier(Item.CurrentValue, Multiplier)
	end

	if #SoldItems > 0 then
		Core:GetService("CashService"):AddCash(Player, TotalValue)
		Core:GetService("StatsService"):AddItemsSold(Player, #SoldItems)
	end

	self:PushItems(Player)
	return {
		Items = SoldItems,
		Count = #SoldItems,
		TotalValue = TotalValue,
	}
end

function Inventoryservice:Init()
	Core:GetService("DataService"):Register("Inventory", {
		Load = function(Player, Saved)
			self:EnsurePlayer(Player)
			local Items = {}
			for _, Item in ipairs(if type(Saved.Items) == "table" then Saved.Items else {}) do
				local Stored = CloneItem(Item)
				Stored.Id = math.floor(tonumber(Item.Id) or 0)
				NextItemId = math.max(NextItemId, Stored.Id)
				table.insert(Items, Stored)
			end
			ItemsByPlayer[Player] = Items
			IndexByPlayer[Player] = Readsavedindex(Saved.Index)
			self:PushItems(Player)
			self:PushIndex(Player)
		end,
		Save = function(Player)
			local Items = table.clone(self:EnsurePlayer(Player))
			local Sessionitem = Core:GetService("RestorationService"):GetSessionItem(Player)
			if Sessionitem then
				table.insert(Items, 1, Sessionitem)
			end
			return { Items = Items, Index = IndexByPlayer[Player] }
		end,
		Clear = function(Player)
			ItemsByPlayer[Player] = nil
			IndexByPlayer[Player] = nil
		end,
	})
	for _, Player in ipairs(Players:GetPlayers()) do
		self:EnsurePlayer(Player)
	end

	Players.PlayerAdded:Connect(function(Player)
		self:EnsurePlayer(Player)
		task.defer(function()
			if Player.Parent then
				self:PushIndex(Player)
				self:PushItems(Player)
			end
		end)
	end)

	Remotemanager:OnServerInvoke(self.Name, "GetIndexEntries", function(Player)
		return self:GetIndexEntries(Player)
	end)

	Remotemanager:OnServerInvoke(self.Name, "GetRestoredItems", function(Player)
		return self:GetRestoredItems(Player)
	end)

	Remotemanager:OnServerInvoke(self.Name, "SellRestoredItem", function(Player, ItemId)
		return self:SellRestoredItem(Player, tonumber(ItemId) or 0)
	end)

	Remotemanager:OnServerInvoke(self.Name, "SellAllRestoredItems", function(Player)
		return self:SellAllRestoredItems(Player)
	end)
end

return Inventoryservice
