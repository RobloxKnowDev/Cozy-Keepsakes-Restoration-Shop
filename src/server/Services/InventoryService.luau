local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
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
	Name: string,
	ImageId: string,
	Rarity: string,
	RestorationPercent: number,
	PurchasePrice: number,
	CurrentValue: number,
	MaxValue: number,
	NetProfit: number,
}

type IndexEntry = {
	ObjectKey: string,
	Name: string,
	ImageId: string,
	Rarity: string,
	Unlocked: boolean,
}

local ItemsByPlayer: { [Player]: { RestoredItem } } = {}
local IndexByPlayer: { [Player]: { [string]: boolean } } = {}
local NextItemId = 0

local function CloneItem(Item: RestoredItem): RestoredItem
	return {
		Id = Item.Id,
		Name = Item.Name,
		ImageId = Item.ImageId,
		Rarity = Item.Rarity,
		RestorationPercent = Item.RestorationPercent,
		PurchasePrice = Item.PurchasePrice,
		CurrentValue = Item.CurrentValue,
		MaxValue = Item.MaxValue,
		NetProfit = Item.NetProfit,
	}
end

function Inventoryservice:EnsurePlayer(Player: Player): { RestoredItem }
	local Items = ItemsByPlayer[Player]
	if not Items then
		Items = {}
		ItemsByPlayer[Player] = Items
	end

	if not IndexByPlayer[Player] then
		IndexByPlayer[Player] = {}
	end

	return Items
end

function Inventoryservice:GetIndexEntries(Player: Player): { IndexEntry }
	self:EnsurePlayer(Player)
	local Unlockedbyobject = IndexByPlayer[Player] or {}
	local Entries = {}

	for ObjectKey, Definition in pairs(Objectconfig.Object) do
		table.insert(Entries, {
			ObjectKey = ObjectKey,
			Name = tostring(Definition.Name or ObjectKey),
			ImageId = tostring(Definition.IdImage or ""),
			Rarity = tostring(Definition.Rarity or Definition.Rarety or "Common"),
			Unlocked = Unlockedbyobject[ObjectKey] == true,
		})
	end

	table.sort(Entries, function(Left, Right)
		return Left.Name < Right.Name
	end)

	return Entries
end

function Inventoryservice:GetRestoredItems(Player: Player): { RestoredItem }
	local Items = self:EnsurePlayer(Player)
	local Result = {}
	for Index, Item in ipairs(Items) do
		Result[Index] = CloneItem(Item)
	end
	return Result
end

function Inventoryservice:PushItems(Player: Player)
	Remotemanager:FireClient(self.Name, "RestoredItemsUpdated", Player, self:GetRestoredItems(Player))
end

function Inventoryservice:PushIndex(Player: Player)
	Remotemanager:FireClient(self.Name, "IndexUpdated", Player, self:GetIndexEntries(Player))
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

function Inventoryservice:UnlockIndexEntry(Player: Player, ObjectKey: string): boolean
	self:EnsurePlayer(Player)

	if ObjectKey == "" or Objectconfig.Object[ObjectKey] == nil then
		return false
	end

	local Unlockedbyobject = IndexByPlayer[Player]
	if Unlockedbyobject[ObjectKey] == true then
		return false
	end

	Unlockedbyobject[ObjectKey] = true
	self:PushIndex(Player)
	return true
end

function Inventoryservice:SellRestoredItem(Player: Player, ItemId: number)
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
	Core:GetService("CashService"):AddCash(Player, Item.CurrentValue)
	Core:GetService("StatsService"):AddItemsSold(Player, 1)
	self:PushItems(Player)
	return CloneItem(Item)
end

function Inventoryservice:SellAllRestoredItems(Player: Player)
	local Items = self:EnsurePlayer(Player)
	local SoldItems = {}
	local TotalValue = 0

	for Index = #Items, 1, -1 do
		local Item = table.remove(Items, Index)
		table.insert(SoldItems, 1, CloneItem(Item))
		TotalValue += Item.CurrentValue
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

	Players.PlayerRemoving:Connect(function(Player)
		ItemsByPlayer[Player] = nil
		IndexByPlayer[Player] = nil
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
