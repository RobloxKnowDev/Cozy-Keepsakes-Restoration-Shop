local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Cleaningconfig = require(Replicatedstorage.Shared.Config.Cleaning)
local Mutationconfig = require(Replicatedstorage.Shared.Config.Mutation)
local Mutationvfx = require(Replicatedstorage.Shared.Utils.MutationVfx)
local Getobjectrotation = require(Replicatedstorage.Shared.Utils.ObjectRotation)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Expositionservice = {
	Name = "ExpositionService",
	Priority = 8,
	Remotes = {
		GetDisplayItems = "Function",
		PlaceDisplayItem = "Function",
		RemoveDisplayItem = "Function",
		EquipBest = "Function",
		DisplayItemsUpdated = "Event",
	},
}

type DisplayObject = Model | BasePart

type DisplayPlacement = {
	Player: Player,
	Object: DisplayObject,
	Item: any,
}

type DisplayEntry = {
	SlotIndex: number,
	OwnerUserId: number,
	Reputation: number,
}

type DisplaySnapshot = {
	Revision: number,
	Items: { DisplayEntry },
}

type ShopDisplay = {
	DisplayedObjects: Folder,
	SlotAttachments: { [number]: Attachment },
	OccupiedSlots: { [number]: DisplayPlacement },
	ReservedSlots: { [number]: Player },
	Revision: number,
}

local Displayturndegrees = 90
local Displaybyshop: { [Model]: ShopDisplay } = {}
local Busyplayers: { [Player]: boolean } = {}
local Objecttemplates: Folder
local Vfxfolder: Folder
local Placementparticle: Attachment
local Placementburst = 0.05
local Dirtsurfacenames = {
	UiTop = true,
	UiBottom = true,
	UiLeft = true,
	UiRight = true,
	UiFront = true,
	UiBack = true,
}
local Dirtdecalnames = Cleaningconfig.DirtDecals

local function Getdisplay(Player: Player): ShopDisplay
	return Displaybyshop[Core:GetService("ShopService"):GetShop(Player)]
end

local function Attachmutationvfx(Object: DisplayObject, Item: any)
	if (tonumber(Item.RestorationPercent) or 0) / 100 < Mutationconfig.RevealRatio then
		return
	end
	Mutationvfx.Attach(Object, tostring(Item.Mutation or "Normal"))
end

local function Playplacementvfx(Object: DisplayObject)
	local Vfx = Placementparticle:Clone() :: Attachment
	local Emitter = Vfx.PlacementParticle :: ParticleEmitter
	Emitter.Enabled = true
	Vfx.Parent = Object:WaitForChild("Base")
	task.delay(Placementburst, function()
		Emitter.Enabled = false
		task.delay(Emitter.Lifetime.Max, function()
			Vfx:Destroy()
		end)
	end)
end

local function Hidedisplayobject(Object: DisplayObject): { [BasePart]: number }
	local Transparencies: { [BasePart]: number } = {}
	if Object:IsA("BasePart") then
		Transparencies[Object] = Object.Transparency
		Object.Transparency = 1
	end
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("BasePart") then
			Transparencies[Descendant] = Descendant.Transparency
			Descendant.Transparency = 1
		end
	end
	return Transparencies
end

local function Revealdisplayobject(Object: DisplayObject, Displayedobjects: Folder)
	local Transparencies = Hidedisplayobject(Object);
	(Object :: Instance).Parent = Displayedobjects
	task.delay(0.1, function()
		if Object.Parent then
			Playplacementvfx(Object)
		end
	end)
	task.delay(0.2, function()
		for Part, Transparency in pairs(Transparencies) do
			Part.Transparency = Transparency
		end
	end)
end

local function Clearvfx(Object: DisplayObject)
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if
			Descendant:IsA("ParticleEmitter")
			or Descendant:IsA("Beam")
			or Descendant:IsA("Trail")
			or Descendant:IsA("Light")
			or Descendant:IsA("Fire")
			or Descendant:IsA("Smoke")
			or Descendant:IsA("Sparkles")
		then
			Descendant:Destroy()
		end
	end
end

local function Removedisplayobject(Object: DisplayObject)
	Clearvfx(Object)
	Hidedisplayobject(Object)
	task.delay(0.2, function()
		Object:Destroy()
	end)
end

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
	Object.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("BasePart") then
			Descendant.Anchored = true
		end
	end
end

local function Cleandisplayobject(Object: DisplayObject)
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("SurfaceGui") and Dirtsurfacenames[Descendant.Name] then
			Descendant.Enabled = false
		elseif Descendant:IsA("Decal") and Dirtdecalnames[Descendant.Name] then
			Descendant:Destroy()
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

local function Releasereservation(Display: ShopDisplay, Player: Player, Slotindex: number)
	Busyplayers[Player] = nil
	if Display.ReservedSlots[Slotindex] == Player then
		Display.ReservedSlots[Slotindex] = nil
	end
end

local function Getdisplayreputation(Player: Player): number
	local Reputation = 0
	for _, Placement in pairs(Getdisplay(Player).OccupiedSlots) do
		if Placement.Player == Player then
			Reputation += Placement.Item.Reputation
		end
	end
	return Reputation
end

local function Refreshdisplayreputation(Player: Player): number
	local Basereputation = Getdisplayreputation(Player)
	local Statsservice = Core:GetService("StatsService")
	Statsservice:SetRankedReputation(Player, Basereputation * Core:GetService("MonetizationService"):GetPassReputationMultiplier(Player))
	return Statsservice:SetReputation(Player, Statsservice:GetReputationContribution(Player, Basereputation))
end

local function Builddisplayitems(Display: ShopDisplay): { DisplayEntry }
	local Items = {}
	for Slotindex = 1, 9 do
		local Placement = Display.OccupiedSlots[Slotindex]
		if Placement then
			table.insert(Items, {
				SlotIndex = Slotindex,
				OwnerUserId = Placement.Player.UserId,
				Reputation = math.max(tonumber(Placement.Item.Reputation) or 0, 0),
			})
		end
	end
	return Items
end

local function Buildsnapshot(Display: ShopDisplay): DisplaySnapshot
	return {
		Revision = Display.Revision,
		Items = Builddisplayitems(Display),
	}
end

local function Commitdisplaychange(Display: ShopDisplay, Player: Player): DisplaySnapshot
	Display.Revision += 1
	local Snapshot = Buildsnapshot(Display)
	Remotemanager:FireClient(Expositionservice.Name, "DisplayItemsUpdated", Player, Snapshot)
	return Snapshot
end

local function Cleanupplayer(Player: Player)
	local Display = Getdisplay(Player)
	Busyplayers[Player] = nil
	for Slotindex, Reservedplayer in pairs(Display.ReservedSlots) do
		if Reservedplayer == Player then
			Display.ReservedSlots[Slotindex] = nil
		end
	end
	for Slotindex, Placement in pairs(Display.OccupiedSlots) do
		if Placement.Player == Player then
			if Placement.Object.Parent then
				Placement.Object:Destroy()
			end
			Display.OccupiedSlots[Slotindex] = nil
		end
	end
end

function Expositionservice:GetDisplayItems(Player: Player): DisplaySnapshot
	return Buildsnapshot(Getdisplay(Player))
end

function Expositionservice:RefreshPlayerReputation(Player: Player): number
	return Refreshdisplayreputation(Player)
end

function Expositionservice:RefreshAllReputations()
	for _, Player in ipairs(Players:GetPlayers()) do
		if Player.Parent then
			Refreshdisplayreputation(Player)
		end
	end
end

function Expositionservice:RestoreDisplayItem(Player: Player, Slotindex: number, Item: any): boolean
	local Display = Getdisplay(Player)
	if not Ispositiveinteger(Slotindex) or Slotindex > 9 or Display.OccupiedSlots[Slotindex] then
		return false
	end
	local Template = Objecttemplates:FindFirstChild(tostring(Item.ObjectKey))
	if not Template or (not Template:IsA("Model") and not Template:IsA("BasePart")) then
		warn("ExpositionService: model not found for " .. tostring(Item.ObjectKey))
		return false
	end
	local Object = Template:Clone() :: DisplayObject
	Attachmutationvfx(Object, Item)
	Cleandisplayobject(Object)
	Anchordisplayobject(Object)
	Object.Name = "Display_" .. Player.UserId .. "_" .. Slotindex
	Object:SetAttribute("OwnerUserId", Player.UserId)
	Object:SetAttribute("SlotIndex", Slotindex)
	Object:SetAttribute("ItemId", Item.Id)
	Object:SetAttribute("ObjectKey", Item.ObjectKey)
	local Slotcframe = Display.SlotAttachments[Slotindex].WorldCFrame * CFrame.Angles(0, math.rad(Displayturndegrees), 0)
	Pivotdisplayobject(Object, Slotcframe * Getobjectrotation(Item.ObjectKey))
	Object.Parent = Display.DisplayedObjects
	Display.OccupiedSlots[Slotindex] = { Player = Player, Object = Object, Item = Item }
	return true
end

function Expositionservice:PlaceDisplayItem(Player: Player, Slotindex: any, Itemid: any, Silent: boolean?)
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
	local Display = Getdisplay(Player)
	if Display.OccupiedSlots[Slotindex] or Display.ReservedSlots[Slotindex] then
		return { Success = false, Reason = "SlotOccupied" }
	end
	local Inventoryservice = Core:GetService("InventoryService")
	local Item = Inventoryservice:GetRestoredItem(Player, Itemid)
	if not Item then
		return { Success = false, Reason = "ItemUnavailable" }
	end

	Busyplayers[Player] = true
	Display.ReservedSlots[Slotindex] = Player
	local Template = Objecttemplates:WaitForChild(Item.ObjectKey)
	if not Template:IsA("Model") and not Template:IsA("BasePart") then
		Releasereservation(Display, Player, Slotindex)
		error("ExpositionService: model '" .. Item.ObjectKey .. "' must be a Model or a BasePart")
	end
	local Object = Template:Clone() :: DisplayObject
	Attachmutationvfx(Object, Item)
	Cleandisplayobject(Object)
	Anchordisplayobject(Object)
	local Slotcframe = Display.SlotAttachments[Slotindex].WorldCFrame * CFrame.Angles(0, math.rad(Displayturndegrees), 0)
	Pivotdisplayobject(Object, Slotcframe * Getobjectrotation(Item.ObjectKey))

	if not Player.Parent or Display.ReservedSlots[Slotindex] ~= Player then
		Object:Destroy()
		Releasereservation(Display, Player, Slotindex)
		return { Success = false, Reason = "PlayerUnavailable" }
	end

	local Removeditem = Inventoryservice:TakeRestoredItem(Player, Itemid, Silent)
	if not Removeditem then
		Object:Destroy()
		Releasereservation(Display, Player, Slotindex)
		return { Success = false, Reason = "ItemUnavailable" }
	end

	Object.Name = "Display_" .. Player.UserId .. "_" .. Slotindex
	Object:SetAttribute("OwnerUserId", Player.UserId)
	Object:SetAttribute("SlotIndex", Slotindex)
	Object:SetAttribute("ItemId", Removeditem.Id)
	Object:SetAttribute("ObjectKey", Removeditem.ObjectKey)
	local Basereputation = math.max(tonumber(Removeditem.Reputation) or 0, 0)
	Display.OccupiedSlots[Slotindex] = {
		Player = Player,
		Object = Object,
		Item = Removeditem,
	}
	Revealdisplayobject(Object, Display.DisplayedObjects)
	Refreshdisplayreputation(Player)
	Releasereservation(Display, Player, Slotindex)

	local Displaysnapshot = Commitdisplaychange(Display, Player)
	Core:GetService("DailyTaskService"):Record(Player, "Display", {
		Rarity = Removeditem.Rarity,
		Percent = Removeditem.RestorationPercent,
	})
	return {
		Success = true,
		SlotIndex = Slotindex,
		ItemId = Removeditem.Id,
		ObjectKey = Removeditem.ObjectKey,
		GrantedReputation = Basereputation,
		DisplayItems = Displaysnapshot,
	}
end

function Expositionservice:RemoveDisplayItem(Player: Player, Slotindex: any, Silent: boolean?)
	if not Ispositiveinteger(Slotindex) or Slotindex > 9 then
		return { Success = false, Reason = "InvalidSlot" }
	end
	if Busyplayers[Player] then
		return { Success = false, Reason = "Busy" }
	end

	local Display = Getdisplay(Player)
	local Placement = Display.OccupiedSlots[Slotindex]
	if not Placement then
		return { Success = false, Reason = "SlotEmpty" }
	end
	if Placement.Player ~= Player then
		return { Success = false, Reason = "NotOwner" }
	end

	Busyplayers[Player] = true
	Display.OccupiedSlots[Slotindex] = nil
	local Basereputation = math.max(tonumber(Placement.Item.Reputation) or 0, 0)
	if Placement.Object.Parent then
		Removedisplayobject(Placement.Object)
	end
	local Inventoryservice = Core:GetService("InventoryService")
	Inventoryservice:ReturnRestoredItem(Player, Placement.Item, Silent)
	Refreshdisplayreputation(Player)
	Busyplayers[Player] = nil

	local Displaysnapshot = Commitdisplaychange(Display, Player)
	return {
		Success = true,
		RemovedReputation = Basereputation,
		DisplayItems = Displaysnapshot,
	}
end

function Expositionservice:EquipBest(Player: Player)
	if Busyplayers[Player] then
		return { Success = false, Reason = "Busy" }
	end
	local Display = Getdisplay(Player)
	local Displayspace = math.clamp(math.floor(Core:GetService("UpgradeService"):GetValue(Player, "DisplaySpace")), 0, 9)
	local Freeslots = {}
	local Candidates = {}
	for Slotindex = 1, Displayspace do
		local Placement = Display.OccupiedSlots[Slotindex]
		if not Placement then
			table.insert(Freeslots, Slotindex)
		elseif Placement.Player == Player then
			table.insert(Candidates, { Item = Placement.Item, Slot = Slotindex })
		end
	end
	local Slotcount = #Freeslots + #Candidates
	for _, Item in ipairs(Core:GetService("InventoryService"):EnsurePlayer(Player)) do
		table.insert(Candidates, { Item = Item })
	end
	for _, Candidate in ipairs(Candidates) do
		Candidate.Reputation = math.max(tonumber(Candidate.Item.Reputation) or 0, 0)
	end
	table.sort(Candidates, function(Left, Right)
		if Left.Reputation ~= Right.Reputation then
			return Left.Reputation > Right.Reputation
		end
		return Left.Slot ~= nil and Right.Slot == nil
	end)

	local Removals = {}
	local Placements = {}
	local Kept = 0
	for Index, Candidate in ipairs(Candidates) do
		local Keep = Index <= Slotcount and (Candidate.Reputation > 0 or Candidate.Slot ~= nil)
		if Keep then
			Kept += 1
		end
		if Candidate.Slot and not Keep then
			table.insert(Removals, Candidate.Slot)
		elseif not Candidate.Slot and Keep then
			table.insert(Placements, Candidate.Item.Id)
		end
	end

	local Changed = 0
	local Grantedreputation = 0
	for _, Slotindex in ipairs(Removals) do
		local Result = self:RemoveDisplayItem(Player, Slotindex, true)
		if Result.Success then
			Changed += 1
			Grantedreputation -= Result.RemovedReputation
			table.insert(Freeslots, Slotindex)
		end
	end
	table.sort(Freeslots)
	for Index, Itemid in ipairs(Placements) do
		local Result = self:PlaceDisplayItem(Player, Freeslots[Index], Itemid, true)
		if Result.Success then
			Changed += 1
			Grantedreputation += Result.GrantedReputation
		end
	end
	if Changed > 0 then
		Core:GetService("InventoryService"):PushItems(Player)
	end
	return {
		Success = true,
		Changed = Changed,
		Kept = Kept,
		GrantedReputation = Grantedreputation,
		DisplayItems = self:GetDisplayItems(Player),
	}
end

function Expositionservice:IsBusy(Player: Player): boolean
	return Busyplayers[Player] == true
end

function Expositionservice:MoveShop(Player: Player, Previous: Model)
	local Olddisplay = Displaybyshop[Previous]
	local Newdisplay = Getdisplay(Player)
	for Slotindex, Placement in pairs(Olddisplay.OccupiedSlots) do
		if Placement.Player == Player then
			Olddisplay.OccupiedSlots[Slotindex] = nil
			Placement.Object:Destroy()
			self:RestoreDisplayItem(Player, Slotindex, Placement.Item)
		end
	end
	Newdisplay.Revision = math.max(Newdisplay.Revision, Olddisplay.Revision)
	Commitdisplaychange(Newdisplay, Player)
end

function Expositionservice:Init()
	for _, Shop in ipairs(Core:GetService("ShopService"):GetShops()) do
		local Displayedobjects = Instance.new("Folder")
		Displayedobjects.Name = "DisplayedObjects"
		Displayedobjects.Parent = Shop
		local Shelf = Shop:WaitForChild("Attachement"):WaitForChild("Shelf")
		local Slotattachments = {}
		for Slotindex = 1, 9 do
			Slotattachments[Slotindex] = Shelf:WaitForChild(tostring(Slotindex)) :: Attachment
		end
		Displaybyshop[Shop] = {
			DisplayedObjects = Displayedobjects,
			SlotAttachments = Slotattachments,
			OccupiedSlots = {},
			ReservedSlots = {},
			Revision = 0,
		}
	end

	Objecttemplates = Replicatedstorage:WaitForChild("Asset"):WaitForChild("Object") :: Folder
	Vfxfolder = Replicatedstorage:WaitForChild("Asset"):WaitForChild("Vfx") :: Folder
	Placementparticle = Vfxfolder:WaitForChild("PlacementParticle") :: Attachment

	Core:GetService("DataService"):Register("Exposition", {
		Load = function(Player, Saved)
			for Slotkey, Item in pairs(if type(Saved) == "table" then Saved else {}) do
				local Slotindex = tonumber(Slotkey)
				if Slotindex and type(Item) == "table" then
					Item.Id = Core:GetService("InventoryService"):NewItemId()
					self:RestoreDisplayItem(Player, Slotindex, Item)
				end
			end
			Refreshdisplayreputation(Player)
			Commitdisplaychange(Getdisplay(Player), Player)
		end,
		Save = function(Player)
			local Snapshot = {}
			for Slotindex, Placement in pairs(Getdisplay(Player).OccupiedSlots) do
				if Placement.Player == Player then
					Snapshot[tostring(Slotindex)] = Placement.Item
				end
			end
			return Snapshot
		end,
		Clear = Cleanupplayer,
	})

	Remotemanager:OnServerInvoke(self.Name, "GetDisplayItems", function(Player)
		return self:GetDisplayItems(Player)
	end)
	Remotemanager:OnServerInvoke(self.Name, "PlaceDisplayItem", function(Player, Slotindex, Itemid)
		return self:PlaceDisplayItem(Player, Slotindex, Itemid)
	end)
	Remotemanager:OnServerInvoke(self.Name, "RemoveDisplayItem", function(Player, Slotindex)
		return self:RemoveDisplayItem(Player, Slotindex)
	end)
	Remotemanager:OnServerInvoke(self.Name, "EquipBest", function(Player)
		return self:EquipBest(Player)
	end)
end

return Expositionservice
