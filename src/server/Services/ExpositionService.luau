local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Expositionservice = {
	Name = "ExpositionService",
	Priority = 8,
	Remotes = {
		GetDisplayItems = "Function",
		PlaceDisplayItem = "Function",
		RemoveDisplayItem = "Function",
		DisplayItemsUpdated = "Event",
	},
}

type DisplayObject = Model | BasePart

type DisplayPlacement = {
	Player: Player,
	Object: DisplayObject,
	Item: any,
	ReputationContribution: number,
}

type DisplayEntry = {
	SlotIndex: number,
	OwnerUserId: number,
}

type DisplaySnapshot = {
	Revision: number,
	Items: { DisplayEntry },
}

local Slotattachments: { [number]: Attachment } = {}
local Occupiedslots: { [number]: DisplayPlacement } = {}
local Reservedslots: { [number]: Player } = {}
local Busyplayers: { [Player]: boolean } = {}
local Displayrevision = 0
local Displayedobjects: Folder
local Objecttemplates: Folder

local function Ispositiveinteger(Value: any): boolean
	return type(Value) == "number"
		and Value == Value
		and Value >= 1
		and Value < math.huge
		and Value == math.floor(Value)
end

local function Anchordisplayobject(Object: DisplayObject)
	if Object:IsA("BasePart") then
		Object.Anchored = true
		return
	end
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("BasePart") then
			Descendant.Anchored = true
		end
	end
end

local function Pivotdisplayobject(Object: DisplayObject, Pivot: CFrame)
	if Object:IsA("Model") then
		Object:PivotTo(Pivot)
	else
		Object.CFrame = Pivot
	end

	local Boundscframe, Boundssize
	if Object:IsA("Model") then
		Boundscframe, Boundssize = Object:GetBoundingBox()
	else
		Boundscframe, Boundssize = Object.CFrame, Object.Size
	end
	local Bottomy = Boundscframe.Position.Y - Boundssize.Y * 0.5
	local Heightoffset = Pivot.Position.Y - Bottomy
	if Object:IsA("Model") then
		Object:PivotTo(Object:GetPivot() + Vector3.new(0, Heightoffset, 0))
	else
		Object.CFrame += Vector3.new(0, Heightoffset, 0)
	end
end

local function Releasereservation(Player: Player, Slotindex: number)
	Busyplayers[Player] = nil
	if Reservedslots[Slotindex] == Player then
		Reservedslots[Slotindex] = nil
	end
end

local function Getdisplayreputation(Player: Player): number
	local Reputation = 0
	for _, Placement in pairs(Occupiedslots) do
		if Placement.Player == Player then
			Reputation += Placement.ReputationContribution
		end
	end
	return Reputation
end

local function Refreshdisplayreputation(Player: Player): number
	return Core:GetService("StatsService"):SetReputation(Player, Getdisplayreputation(Player))
end

local function Builddisplayitems(): { DisplayEntry }
	local Items = {}
	for Slotindex = 1, 9 do
		local Placement = Occupiedslots[Slotindex]
		if Placement then
			table.insert(Items, {
				SlotIndex = Slotindex,
				OwnerUserId = Placement.Player.UserId,
			})
		end
	end
	return Items
end

local function Buildsnapshot(): DisplaySnapshot
	return {
		Revision = Displayrevision,
		Items = Builddisplayitems(),
	}
end

local function Commitdisplaychange(): DisplaySnapshot
	Displayrevision += 1
	local Snapshot = Buildsnapshot()
	Remotemanager:FireAllClients(Expositionservice.Name, "DisplayItemsUpdated", Snapshot)
	return Snapshot
end

local function Cleanupplayer(Player: Player)
	local Changed = false
	Busyplayers[Player] = nil
	for Slotindex, Reservedplayer in pairs(Reservedslots) do
		if Reservedplayer == Player then
			Reservedslots[Slotindex] = nil
		end
	end
	for Slotindex, Placement in pairs(Occupiedslots) do
		if Placement.Player == Player then
			if Placement.Object.Parent then
				Placement.Object:Destroy()
			end
			Occupiedslots[Slotindex] = nil
			Changed = true
		end
	end
	if Changed then Commitdisplaychange() end
end

function Expositionservice:GetDisplayItems(): DisplaySnapshot
	return Buildsnapshot()
end

function Expositionservice:PlaceDisplayItem(Player: Player, Slotindex: any, Itemid: any)
	if not Ispositiveinteger(Slotindex) or Slotindex > 9 then
		return { Success = false, Reason = "InvalidSlot" }
	end
	if not Ispositiveinteger(Itemid) then
		return { Success = false, Reason = "InvalidItem" }
	end
	if Busyplayers[Player] then
		return { Success = false, Reason = "Busy" }
	end

	local Displayspace = math.max(math.floor(Core:GetService("UpgradeService"):GetValue(Player, "DisplaySpace")), 0)
	if Slotindex > Displayspace then
		return { Success = false, Reason = "SlotLocked" }
	end
	if Occupiedslots[Slotindex] or Reservedslots[Slotindex] then
		return { Success = false, Reason = "SlotOccupied" }
	end

	local Inventoryservice = Core:GetService("InventoryService")
	local Item = Inventoryservice:GetRestoredItem(Player, Itemid)
	if not Item then
		return { Success = false, Reason = "ItemUnavailable" }
	end

	Busyplayers[Player] = true
	Reservedslots[Slotindex] = Player
	local Template = Objecttemplates:WaitForChild(Item.ObjectKey)
	if not Template:IsA("Model") and not Template:IsA("BasePart") then
		Releasereservation(Player, Slotindex)
		error("ExpositionService: le modèle '" .. Item.ObjectKey .. "' doit être un Model ou une BasePart")
	end
	local Object = Template:Clone() :: DisplayObject
	Anchordisplayobject(Object)
	Pivotdisplayobject(Object, Slotattachments[Slotindex].WorldCFrame)

	if not Player.Parent or Reservedslots[Slotindex] ~= Player then
		Object:Destroy()
		Releasereservation(Player, Slotindex)
		return { Success = false, Reason = "PlayerUnavailable" }
	end

	local Removeditem = Inventoryservice:TakeRestoredItem(Player, Itemid)
	if not Removeditem then
		Object:Destroy()
		Releasereservation(Player, Slotindex)
		return { Success = false, Reason = "ItemUnavailable" }
	end

	Object.Name = "Display_" .. Player.UserId .. "_" .. Slotindex
	Object:SetAttribute("OwnerUserId", Player.UserId)
	Object:SetAttribute("SlotIndex", Slotindex)
	Object:SetAttribute("ItemId", Removeditem.Id)
	Object:SetAttribute("ObjectKey", Removeditem.ObjectKey)
	local Reputationcontribution = Core:GetService("StatsService"):GetReputationContribution(Player, Removeditem.Reputation)
	Occupiedslots[Slotindex] = {
		Player = Player,
		Object = Object,
		Item = Removeditem,
		ReputationContribution = Reputationcontribution,
	}
	Object.Parent = Displayedobjects
	Refreshdisplayreputation(Player)
	Releasereservation(Player, Slotindex)

	local Displaysnapshot = Commitdisplaychange()
	Inventoryservice:PushItems(Player)
	return {
		Success = true,
		SlotIndex = Slotindex,
		ItemId = Removeditem.Id,
		ObjectKey = Removeditem.ObjectKey,
		GrantedReputation = Reputationcontribution,
		DisplayItems = Displaysnapshot,
	}
end

function Expositionservice:RemoveDisplayItem(Player: Player, Slotindex: any)
	if not Ispositiveinteger(Slotindex) or Slotindex > 9 then
		return { Success = false, Reason = "InvalidSlot" }
	end
	if Busyplayers[Player] then
		return { Success = false, Reason = "Busy" }
	end

	local Placement = Occupiedslots[Slotindex]
	if not Placement then
		return { Success = false, Reason = "SlotEmpty" }
	end
	if Placement.Player ~= Player then
		return { Success = false, Reason = "NotOwner" }
	end

	Busyplayers[Player] = true
	Occupiedslots[Slotindex] = nil
	if Placement.Object.Parent then
		Placement.Object:Destroy()
	end
	local Inventoryservice = Core:GetService("InventoryService")
	Inventoryservice:ReturnRestoredItem(Player, Placement.Item)
	Refreshdisplayreputation(Player)
	Busyplayers[Player] = nil

	local Displaysnapshot = Commitdisplaychange()
	Inventoryservice:PushItems(Player)
	return {
		Success = true,
		RemovedReputation = Placement.ReputationContribution,
		DisplayItems = Displaysnapshot,
	}
end

function Expositionservice:Init()
	local Etagere = Workspace:WaitForChild("Work"):WaitForChild("Etagere")
	local Slots = Etagere:WaitForChild("Slots")
	for Slotindex = 1, 9 do
		Slotattachments[Slotindex] = Slots:WaitForChild(tostring(Slotindex)) :: Attachment
	end

	Displayedobjects = Instance.new("Folder")
	Displayedobjects.Name = "DisplayedObjects"
	Displayedobjects.Parent = Etagere
	Objecttemplates = Replicatedstorage:WaitForChild("Asset"):WaitForChild("Object") :: Folder

	Players.PlayerRemoving:Connect(Cleanupplayer)
	Remotemanager:OnServerInvoke(self.Name, "GetDisplayItems", function()
		return self:GetDisplayItems()
	end)
	Remotemanager:OnServerInvoke(self.Name, "PlaceDisplayItem", function(Player, Slotindex, Itemid)
		return self:PlaceDisplayItem(Player, Slotindex, Itemid)
	end)
	Remotemanager:OnServerInvoke(self.Name, "RemoveDisplayItem", function(Player, Slotindex)
		return self:RemoveDisplayItem(Player, Slotindex)
	end)
end

return Expositionservice
