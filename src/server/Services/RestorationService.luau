local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Tweenservice = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Config = require(Replicatedstorage.Shared.Config.Object)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Restorationservice = {
	Name = "RestorationService",
	Priority = 10,
	Remotes = {
		BeginSession = "Function",
		BeginPeel = "Function",
		ApplyInkSolvent = "Event",
		ApplyScratchPolish = "Event",
		CleanInk = "Event",
		CleanDirt = "Event",
		CleanScratch = "Event",
		CompleteRestoration = "Function",
		CompletePeel = "Event",
		CancelPeel = "Event",
		CleanSpot = "Event",
		SessionEnded = "Event",
	},
}

local Dirtgridwidth = 4
local Dirtcenterpower = 0.1
local Dirtneighborpower = 0.04
local Dirtcleaninterval = 0.07
local Scratchimagecount = 4
local Inkimagecount = 4
local Scratchcleanpower = Dirtcenterpower * 0.75
local Scratchcleaninterval = Dirtcleaninterval
local Inkcleanpower = Scratchcleanpower
local Inkcleaninterval = Scratchcleaninterval
local Dirtsurfacenames = {
	UiTop = true,
	UiBottom = true,
	UiLeft = true,
	UiRight = true,
	UiFront = true,
	UiBack = true,
}
local Dirttools = { CottonTip = true, ToothBrush = true }
local Dirttoolpower = { CottonTip = 1, ToothBrush = 1.2 }
local Spothealth = { Sticker = 3 }
local Toolpower = { CottonTip = 1, HeatGun = 1, Polish = 1, Solvent = 1, ToothBrush = 1, Tweezers = 1 }
local Toolsforspot = { Sticker = "Tweezers" }

type RestorationObject = Model | BasePart

local Slot: Folder
local Generateditems: Folder

type ObjectMaximums = {
	MaxValue: number,
	MaxReputation: number,
}

local Sessions: { [Player]: RestorationObject } = {}
local Lastclean: { [Player]: number } = {}
local Lastscratchclean: { [Player]: number } = {}
local Lastinkclean: { [Player]: number } = {}
local Peeling: { [Player]: BasePart } = {}
local Activeobject: RestorationObject? = nil
local Grantedobjectqueue: { { Player: Player, Objectname: string, OnReady: (() -> ())? } } = {}
local Randomgenerator = Random.new()

local function Roundtwodecimals(Value: number): number
	return math.round(Value * 100) / 100
end

local function Randomizemaximum(Value: number): number
	local Minimum = Config.Variation.MinimumPercent / 100
	local Maximum = Config.Variation.MaximumPercent / 100
	return Roundtwodecimals(Value * Randomgenerator:NextNumber(Minimum, Maximum))
end

local function Generateobjectmaximums(Objectname: string): ObjectMaximums
	local Definition = Config.Object[Objectname]
	return {
		MaxValue = Randomizemaximum(Definition.MaxValue),
		MaxReputation = Randomizemaximum(Definition.Reputation),
	}
end

local function Destroyobject(Object: RestorationObject?)
	if Object and Object.Parent then
		Object:Destroy()
	end
end

local function Getcompletionratio(Object: RestorationObject): number
	local Totalspots = tonumber(Object:GetAttribute("TotalSpots")) or 0
	local Cleanedspots = tonumber(Object:GetAttribute("CleanedSpots")) or 0
	if Totalspots <= 0 then
		return 0
	end

	return math.clamp(Cleanedspots / Totalspots, 0, 1)
end

local function Cleanupactiveobjectifidle()
	if next(Sessions) == nil then
		Destroyobject(Activeobject)
		Activeobject = nil
	end
end

local function Validsessionspot(Player: Player, Spot: any): (RestorationObject?, boolean)
	local Object = Sessions[Player]
	if not Object or typeof(Spot) ~= "Instance" or not Spot:IsA("BasePart") then
		return Object, false
	end
	local Spots = Object:FindFirstChild("RestorationSpots")
	return Object, Spots ~= nil and Spot:IsDescendantOf(Spots)
end

local function Spawnconfiguredobject(Objectname: string, Maximums: ObjectMaximums?): RestorationObject
	local Spawnattachment = Slot:WaitForChild("Spawn") :: Attachment
	local Definition = Config.Object[Objectname]
	local Asset = Replicatedstorage:WaitForChild("Asset"):WaitForChild("Object"):WaitForChild(Objectname)
	local Object = Asset:Clone() :: RestorationObject
	if Objectname == "Skate" then
		local Objectcore = Object:WaitForChild("Core")
		local Grip = Objectcore:WaitForChild("Grip")
		local Uitop = Grip:WaitForChild("UiTop") :: SurfaceGui
		Uitop.AlwaysOnTop = false
	end
	local Objectmaximums = Maximums or Generateobjectmaximums(Objectname)
	local Maxvalue = Objectmaximums.MaxValue
	local Maxreputation = Objectmaximums.MaxReputation
	Object.Name = Objectname
	Object:SetAttribute("RestorationObject", true)
	Object:SetAttribute("KeepSpawnPosition", true)
	Object:SetAttribute("ObjectKey", Objectname)
	Object:SetAttribute("SpawnFloorY", Spawnattachment.WorldPosition.Y)
	Object:SetAttribute("DisplayName", Definition.Name or Objectname)
	Object:SetAttribute("MaxPrice", Maxvalue)
	Object:SetAttribute("MaxValue", Maxvalue)
	Object:SetAttribute("Rarity", Definition.Rarity or Definition.Rarety or "Common")
	Object:SetAttribute("ImageId", Definition.IdImage or "")
	Object:SetAttribute("MaxReputation", Maxreputation)
	Object.Parent = Generateditems
	local Spawncframe = Spawnattachment.WorldCFrame * CFrame.Angles(0, math.rad(90), 0)
	if Object:IsA("Model") then
		Object:PivotTo(Spawncframe)
	else
		Object.CFrame = Spawncframe
	end

	local Boundscframe, Boundssize
	if Object:IsA("Model") then
		Boundscframe, Boundssize = Object:GetBoundingBox()
	else
		Boundscframe, Boundssize = Object.CFrame, Object.Size
	end
	local Bottomy = Boundscframe.Position.Y - Boundssize.Y * 0.5
	local Heightoffset = Spawnattachment.WorldPosition.Y - Bottomy
	if Object:IsA("Model") then
		Object:PivotTo(Object:GetPivot() + Vector3.new(0, Heightoffset, 0))
	else
		Object.CFrame += Vector3.new(0, Heightoffset, 0)
	end

	return Object
end

local function Initializedirt(Object: RestorationObject): number
	local Dirtframes = {}
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("GuiObject") and Descendant.Name == "DirtFrame" then
			local Surface = Descendant.Parent
			assert(Surface and Surface:IsA("SurfaceGui"), "RestorationService: " .. Descendant:GetFullName() .. " doit être dans un SurfaceGui")
			assert(Dirtsurfacenames[Surface.Name], "RestorationService: " .. Surface:GetFullName() .. " doit utiliser un nom Ui valide")
			local Part = Surface.Parent
			assert(Part and Part:IsA("BasePart"), "RestorationService: " .. Surface:GetFullName() .. " doit être dans une BasePart")
			assert(Surface.Enabled, "RestorationService: " .. Surface:GetFullName() .. " doit être activé")
			assert(
				Surface.Face.Name == string.sub(Surface.Name, 3),
				"RestorationService: la face de " .. Surface:GetFullName() .. " ne correspond pas à son nom"
			)
			assert(Descendant.Visible, "RestorationService: " .. Descendant:GetFullName() .. " doit être visible")
			table.insert(Dirtframes, Descendant)
		end
	end
	for Index = #Dirtframes, 2, -1 do
		local Swap = math.random(Index)
		Dirtframes[Index], Dirtframes[Swap] = Dirtframes[Swap], Dirtframes[Index]
	end
	local Keptcount = if #Dirtframes > 0 then math.random(1, #Dirtframes) else 0
	local Totaldirt = 0
	for Index, Dirtframe in ipairs(Dirtframes) do
		if Index > Keptcount then
			Dirtframe.Visible = false
			continue
		end
		for Imageindex = 1, 16 do
			local Image = Dirtframe:WaitForChild(tostring(Imageindex))
			assert(Image:IsA("ImageLabel"), "RestorationService: " .. Image:GetFullName() .. " doit être un ImageLabel")
			Image:SetAttribute("InitialDirtTransparency", Image.ImageTransparency)
			Totaldirt += 1 - Image.ImageTransparency
		end
	end
	Object:SetAttribute("Total_Dirt", Totaldirt)
	Object:SetAttribute("Cleaned_Dirt", 0)
	return Totaldirt
end

local function Initializescratches(Object: RestorationObject): number
	local Totalscratches = 0
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("GuiObject") and Descendant.Name == "ScratchesFrame" then
			local Surface = Descendant.Parent
			assert(Surface and Surface:IsA("SurfaceGui"), "RestorationService: " .. Descendant:GetFullName() .. " doit être dans un SurfaceGui")
			assert(Dirtsurfacenames[Surface.Name], "RestorationService: " .. Surface:GetFullName() .. " doit utiliser un nom Ui valide")
			local Part = Surface.Parent
			assert(Part and Part:IsA("BasePart"), "RestorationService: " .. Surface:GetFullName() .. " doit être dans une BasePart")
			assert(Surface.Enabled, "RestorationService: " .. Surface:GetFullName() .. " doit être activé")
			assert(
				Surface.Face.Name == string.sub(Surface.Name, 3),
				"RestorationService: la face de " .. Surface:GetFullName() .. " ne correspond pas à son nom"
			)
			assert(Descendant.Visible, "RestorationService: " .. Descendant:GetFullName() .. " doit être visible")
			for Index = 1, Scratchimagecount do
				local Image = Descendant:WaitForChild(tostring(Index))
				assert(Image:IsA("ImageLabel"), "RestorationService: " .. Image:GetFullName() .. " doit être un ImageLabel")
				assert(Image.Visible, "RestorationService: " .. Image:GetFullName() .. " doit être visible")
				Image:SetAttribute("InitialScratchTransparency", Image.ImageTransparency)
				Image:SetAttribute("HasPolish", false)
				Totalscratches += 1 - Image.ImageTransparency
			end
		end
	end
	Object:SetAttribute("Total_Scratch", Totalscratches)
	Object:SetAttribute("Cleaned_Scratch", 0)
	return Totalscratches
end

local function Initializeink(Object: RestorationObject): number
	local Totalink = 0
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("GuiObject") and Descendant.Name == "Ink" then
			local Surface = Descendant.Parent
			assert(Surface and Surface:IsA("SurfaceGui"), "RestorationService: " .. Descendant:GetFullName() .. " doit être dans un SurfaceGui")
			assert(Dirtsurfacenames[Surface.Name], "RestorationService: " .. Surface:GetFullName() .. " doit utiliser un nom Ui valide")
			local Part = Surface.Parent
			assert(Part and Part:IsA("BasePart"), "RestorationService: " .. Surface:GetFullName() .. " doit être dans une BasePart")
			assert(Surface.Enabled, "RestorationService: " .. Surface:GetFullName() .. " doit être activé")
			assert(Surface.Face.Name == string.sub(Surface.Name, 3), "RestorationService: la face de " .. Surface:GetFullName() .. " ne correspond pas à son nom")
			assert(Descendant.Visible, "RestorationService: " .. Descendant:GetFullName() .. " doit être visible")
			for Index = 1, Inkimagecount do
				local Image = Descendant:WaitForChild(tostring(Index))
				assert(Image:IsA("ImageLabel"), "RestorationService: " .. Image:GetFullName() .. " doit être un ImageLabel")
				assert(Image.Visible, "RestorationService: " .. Image:GetFullName() .. " doit être visible")
				Image:SetAttribute("InitialInkTransparency", Image.ImageTransparency)
				Image:SetAttribute("HasSolvent", false)
				Totalink += 1 - Image.ImageTransparency
			end
		end
	end
	Object:SetAttribute("Total_Ink", Totalink)
	Object:SetAttribute("Cleaned_Ink", 0)
	return Totalink
end

local function Validscratchimage(Object: RestorationObject, Target: any): boolean
	if typeof(Target) ~= "Instance" or not Target:IsA("ImageLabel") or not Target:IsDescendantOf(Object) then return false end
	local Scratchframe = Target.Parent
	if not Scratchframe or Scratchframe.Name ~= "ScratchesFrame" or not Scratchframe:IsA("GuiObject") or not Scratchframe.Visible then return false end
	local Surface = Scratchframe.Parent
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled or not Dirtsurfacenames[Surface.Name] then return false end
	if not Surface.Parent or not Surface.Parent:IsA("BasePart") then return false end
	if Surface.Face.Name ~= string.sub(Surface.Name, 3) then return false end
	local Targetindex = tonumber(Target.Name)
	if not Targetindex or Targetindex < 1 or Targetindex > Scratchimagecount or Targetindex ~= math.floor(Targetindex) then return false end
	if Scratchframe:WaitForChild(tostring(Targetindex)) ~= Target then return false end
	return Target.Visible and Target:GetAttribute("InitialScratchTransparency") ~= nil
end

local function Validinkimage(Object: RestorationObject, Target: any): boolean
	if typeof(Target) ~= "Instance" or not Target:IsA("ImageLabel") or not Target:IsDescendantOf(Object) then return false end
	local Inkframe = Target.Parent
	if not Inkframe or Inkframe.Name ~= "Ink" or not Inkframe:IsA("GuiObject") or not Inkframe.Visible then return false end
	local Surface = Inkframe.Parent
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled or not Dirtsurfacenames[Surface.Name] then return false end
	if not Surface.Parent or not Surface.Parent:IsA("BasePart") then return false end
	if Surface.Face.Name ~= string.sub(Surface.Name, 3) then return false end
	local Targetindex = tonumber(Target.Name)
	if not Targetindex or Targetindex < 1 or Targetindex > Inkimagecount or Targetindex ~= math.floor(Targetindex) then return false end
	if Inkframe:WaitForChild(tostring(Targetindex)) ~= Target then return false end
	return Target.Visible and Target:GetAttribute("InitialInkTransparency") ~= nil
end

local function Createspots(Object: RestorationObject)
	local Old = Object:FindFirstChild("RestorationSpots")
	if Old then
		Old:Destroy()
	end

	local Folder = Instance.new("Folder")
	Folder.Name = "RestorationSpots"
	Folder.Parent = Object

	local Totaldirt = Initializedirt(Object)
	local Totalscratches = Initializescratches(Object)
	local Totalink = Initializeink(Object)
	local Sticker = Object:WaitForChild("Sticker")
	assert(Sticker:IsA("BasePart"), "RestorationService: " .. Sticker:GetFullName() .. " doit être une BasePart")
	Sticker:SetAttribute("SpotKind", "Sticker")
	Sticker:SetAttribute("Health", Spothealth.Sticker)
	Sticker.CanCollide = false
	Sticker.CanQuery = true
	Sticker.CanTouch = false
	Sticker.Massless = true
	Sticker.Parent = Folder
	Object:SetAttribute("Total_Sticker", 1)
	Object:SetAttribute("Cleaned_Sticker", 0)
	local Otherspots = Totalscratches + Totalink + 1
	local Dirtshare = math.random(67, 73) / 100
	local Dirtweight = if Totaldirt > 0 then math.min(1, Otherspots * Dirtshare / ((1 - Dirtshare) * Totaldirt)) else 1
	Object:SetAttribute("DirtWeight", Dirtweight)
	Object:SetAttribute("TotalSpots", Totaldirt * Dirtweight + Otherspots)
	Object:SetAttribute("CleanedSpots", 0)
end

function Restorationservice:GenerateObjectMaximums(Objectname: string): ObjectMaximums
	return Generateobjectmaximums(Objectname)
end

function Restorationservice:PrepareObject(Objectname: string, Owner: Player?, Maximums: ObjectMaximums?): RestorationObject
	Destroyobject(Activeobject)
	local Object = Spawnconfiguredobject(Objectname, Maximums)
	if Object:IsA("BasePart") then
		Object.Anchored = true
	else
		for _, Descendant in ipairs(Object:GetDescendants()) do
			if Descendant:IsA("BasePart") then
				Descendant.Anchored = true
			end
		end
	end
	Object:SetAttribute("RestorationObject", true)
	Object:SetAttribute("AwardedUserId", if Owner then Owner.UserId else nil)
	Createspots(Object)
	Activeobject = Object
	return Object
end

function Restorationservice:TryPrepareNextGrantedObject(): RestorationObject?
	if self:HasActiveObject() or self:HasActiveSession() then return nil end
	while #Grantedobjectqueue > 0 do
		local Entry = table.remove(Grantedobjectqueue, 1)
		if Entry.Player.Parent then
			local Object = self:PrepareObject(Entry.Objectname, Entry.Player)
			if Entry.OnReady then Entry.OnReady() end
			return Object
		end
	end
	return nil
end

function Restorationservice:GrantObject(Player: Player, Objectname: string, OnReady: (() -> ())?): (boolean, boolean)
	if Config.Object[Objectname] == nil then return false, false end
	if not self:HasActiveObject() and not self:HasActiveSession() then
		self:PrepareObject(Objectname, Player)
		return true, true
	else
		table.insert(Grantedobjectqueue, { Player = Player, Objectname = Objectname, OnReady = OnReady })
		return true, false
	end
end

function Restorationservice:HasActiveSession(): boolean
	return next(Sessions) ~= nil
end

function Restorationservice:HasActiveObject(): boolean
	return Activeobject ~= nil and Activeobject.Parent ~= nil
end

function Restorationservice:Init()
	Slot = Workspace:WaitForChild("Map"):WaitForChild("Slot1") :: Folder
	Generateditems = Instance.new("Folder")
	Generateditems.Name = "GeneratedItems"
	Generateditems.Parent = Slot
	Remotemanager:OnServerInvoke(self.Name, "BeginSession", function(Player)
		local Object = Activeobject
		if not Object or not Object.Parent then
			return nil
		end
		if Object:GetAttribute("CompletingRestoration") then return nil end
		local AwardedUserId = tonumber(Object:GetAttribute("AwardedUserId"))
		if AwardedUserId and AwardedUserId ~= Player.UserId then return nil end
		Sessions[Player] = Object
		return Object
	end)

	Remotemanager:OnServerInvoke(self.Name, "BeginPeel", function(Player, Spot)
		local _, Valid = Validsessionspot(Player, Spot)
		if not Valid or Spot:GetAttribute("SpotKind") ~= "Sticker" then
			return false
		end
		local Owner = Spot:GetAttribute("PeelingBy")
		if Owner and Owner ~= Player.UserId then
			return false
		end
		Spot:SetAttribute("PeelingBy", Player.UserId)
		Peeling[Player] = Spot
		return true
	end)

	Remotemanager:OnServerInvoke(self.Name, "CompleteRestoration", function(Player)
		local Sessionobject = Sessions[Player]
		if not Sessionobject or not Sessionobject.Parent then
			return nil
		end
		if Sessionobject:GetAttribute("CompletingRestoration") then return nil end
		Sessionobject:SetAttribute("CompletingRestoration", true)
		Sessions[Player] = nil

		local Inventoryservice = Core:GetService("InventoryService")
		local Completionratio = Getcompletionratio(Sessionobject)
		local Maxvalue = tonumber(Sessionobject:GetAttribute("MaxValue")) or tonumber(Sessionobject:GetAttribute("MaxPrice")) or 0
		local Maxreputation = tonumber(Sessionobject:GetAttribute("MaxReputation")) or 0
		local Salevalue = Roundtwodecimals(Maxvalue * Completionratio)
		local Reputation = Roundtwodecimals(Maxreputation * Completionratio)
		local Purchaseprice = tonumber(Sessionobject:GetAttribute("PurchasePrice")) or 0
		local Objectkey = tostring(Sessionobject:GetAttribute("ObjectKey") or Sessionobject.Name)
		local Itemdata = {
			Id = 0,
			ObjectKey = Objectkey,
			Name = tostring(Sessionobject:GetAttribute("DisplayName") or Sessionobject.Name),
			ImageId = tostring(Sessionobject:GetAttribute("ImageId") or ""),
			Rarity = tostring(Sessionobject:GetAttribute("Rarity") or "Common"),
			RestorationPercent = math.floor(Completionratio * 100 + 0.5),
			PurchasePrice = Purchaseprice,
			CurrentValue = Salevalue,
			MaxValue = Maxvalue,
			NetProfit = Roundtwodecimals(Salevalue - Purchaseprice),
			Reputation = Reputation,
		}

		Sessionobject:SetAttribute("SaleValue", Salevalue)

		local Spot = Peeling[Player]
		if Spot and Spot.Parent then
			Spot:SetAttribute("PeelingBy", nil)
		end
		Peeling[Player] = nil
		Lastclean[Player] = nil
		Lastscratchclean[Player] = nil
		Lastinkclean[Player] = nil

		if Activeobject == Sessionobject then
			Activeobject = nil
		end
		Destroyobject(Sessionobject)

		local Restoreditem = Inventoryservice:AddRestoredItem(Player, Itemdata)
		if Completionratio >= 0.5 and Player.Parent then
			Inventoryservice:UnlockIndexEntry(Player, Objectkey)
		end
		task.defer(function() self:TryPrepareNextGrantedObject() end)

		return Restoreditem
	end)

	Remotemanager:OnServerEvent(self.Name, "CompletePeel", function(Player, Spot)
		local Object, Valid = Validsessionspot(Player, Spot)
		if not Object or not Valid or Peeling[Player] ~= Spot or Spot:GetAttribute("PeelingBy") ~= Player.UserId then
			return
		end
		Peeling[Player] = nil
		Spot.CanQuery = false
		local Totalspots = tonumber(Object:GetAttribute("TotalSpots")) or 0
		local Cleanedspots = math.min((tonumber(Object:GetAttribute("CleanedSpots")) or 0) + 1, Totalspots)
		if Totalspots - Cleanedspots < 0.000001 then Cleanedspots = Totalspots end
		Object:SetAttribute("CleanedSpots", Cleanedspots)
		Object:SetAttribute("Cleaned_Sticker", (Object:GetAttribute("Cleaned_Sticker") or 0) + 1)
		Spot:Destroy()
	end)

	Remotemanager:OnServerEvent(self.Name, "CancelPeel", function(Player, Spot)
		if Peeling[Player] ~= Spot then
			return
		end
		Peeling[Player] = nil
		if Spot.Parent and Spot:GetAttribute("PeelingBy") == Player.UserId then
			Spot:SetAttribute("PeelingBy", nil)
			Spot.CanQuery = true
		end
	end)

	Remotemanager:OnServerEvent(self.Name, "ApplyInkSolvent", function(Player, Target)
		local Sessionobject = Sessions[Player]
		if not Sessionobject or not Validinkimage(Sessionobject, Target) then return end
		if Target.ImageTransparency >= 1 then return end
		Target:SetAttribute("HasSolvent", true)
	end)

	Remotemanager:OnServerEvent(self.Name, "ApplyScratchPolish", function(Player, Target)
		local Sessionobject = Sessions[Player]
		if not Sessionobject or not Validscratchimage(Sessionobject, Target) then return end
		if Target.ImageTransparency >= 1 then return end
		Target:SetAttribute("HasPolish", true)
	end)

	Remotemanager:OnServerEvent(self.Name, "CleanInk", function(Player, Target)
		local Sessionobject = Sessions[Player]
		if not Sessionobject or not Validinkimage(Sessionobject, Target) then return end
		if Target:GetAttribute("HasSolvent") ~= true then return end
		local Now = os.clock()
		if Now - (Lastinkclean[Player] or 0) < Inkcleaninterval then return end
		Lastinkclean[Player] = Now

		local Previoustransparency = Target.ImageTransparency
		local Transparency = math.clamp(Previoustransparency + Inkcleanpower, 0, 1)
		local Removedink = Transparency - Previoustransparency
		if Removedink <= 0 then return end
		Target.ImageTransparency = Transparency

		local Totalink = tonumber(Sessionobject:GetAttribute("Total_Ink")) or 0
		local Previouscleanedink = tonumber(Sessionobject:GetAttribute("Cleaned_Ink")) or 0
		local Cleanedink = math.min(Previouscleanedink + Removedink, Totalink)
		if Totalink - Cleanedink < 0.000001 then Cleanedink = Totalink end
		local Appliedprogress = Cleanedink - Previouscleanedink
		Sessionobject:SetAttribute("Cleaned_Ink", Cleanedink)
		local Totalspots = tonumber(Sessionobject:GetAttribute("TotalSpots")) or 0
		local Cleanedspots = math.min((tonumber(Sessionobject:GetAttribute("CleanedSpots")) or 0) + Appliedprogress, Totalspots)
		if Totalspots - Cleanedspots < 0.000001 then Cleanedspots = Totalspots end
		Sessionobject:SetAttribute("CleanedSpots", Cleanedspots)
	end)

	Remotemanager:OnServerEvent(self.Name, "CleanScratch", function(Player, Target)
		local Sessionobject = Sessions[Player]
		if not Sessionobject or not Validscratchimage(Sessionobject, Target) then return end
		if Target:GetAttribute("HasPolish") ~= true then return end
		local Now = os.clock()
		if Now - (Lastscratchclean[Player] or 0) < Scratchcleaninterval then return end
		Lastscratchclean[Player] = Now

		local PreviousTransparency = Target.ImageTransparency
		local Transparency = math.clamp(PreviousTransparency + Scratchcleanpower, 0, 1)
		local Removedscratch = Transparency - PreviousTransparency
		if Removedscratch <= 0 then return end
		Target.ImageTransparency = Transparency

		local Totalscratches = tonumber(Sessionobject:GetAttribute("Total_Scratch")) or 0
		local Previouscleanedscratches = tonumber(Sessionobject:GetAttribute("Cleaned_Scratch")) or 0
		local Cleanedscratches = math.min(Previouscleanedscratches + Removedscratch, Totalscratches)
		if Totalscratches - Cleanedscratches < 0.000001 then Cleanedscratches = Totalscratches end
		local Appliedprogress = Cleanedscratches - Previouscleanedscratches
		Sessionobject:SetAttribute("Cleaned_Scratch", Cleanedscratches)
		local Totalspots = tonumber(Sessionobject:GetAttribute("TotalSpots")) or 0
		local Cleanedspots = math.min((tonumber(Sessionobject:GetAttribute("CleanedSpots")) or 0) + Appliedprogress, Totalspots)
		if Totalspots - Cleanedspots < 0.000001 then Cleanedspots = Totalspots end
		Sessionobject:SetAttribute("CleanedSpots", Cleanedspots)
	end)

	Remotemanager:OnServerEvent(self.Name, "CleanDirt", function(Player, Target, Toolname)
		local Sessionobject = Sessions[Player]
		if not Sessionobject or not Dirttools[Toolname] then return end
		if typeof(Target) ~= "Instance" or not Target:IsA("ImageLabel") or not Target:IsDescendantOf(Sessionobject) then return end
		local Dirtframe = Target.Parent
		if not Dirtframe or Dirtframe.Name ~= "DirtFrame" or not Dirtframe:IsA("GuiObject") or not Dirtframe.Visible then return end
		local Surface = Dirtframe.Parent
		if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled or not Dirtsurfacenames[Surface.Name] then return end
		if Surface.Parent == nil or not Surface.Parent:IsA("BasePart") then return end
		if Surface.Face.Name ~= string.sub(Surface.Name, 3) then return end
		local Targetindex = tonumber(Target.Name)
		if not Targetindex or Targetindex < 1 or Targetindex > 16 or Targetindex ~= math.floor(Targetindex) then return end
		if Dirtframe:WaitForChild(tostring(Targetindex)) ~= Target then return end
		if Target:GetAttribute("InitialDirtTransparency") == nil then return end
		local Now = os.clock()
		if Now - (Lastclean[Player] or 0) < Dirtcleaninterval then return end
		Lastclean[Player] = Now

		local Targetrow = math.floor((Targetindex - 1) / Dirtgridwidth)
		local Targetcolumn = (Targetindex - 1) % Dirtgridwidth
		local Removeddirt = 0
		for Index = 1, 16 do
			local Row = math.floor((Index - 1) / Dirtgridwidth)
			local Column = (Index - 1) % Dirtgridwidth
			if math.abs(Row - Targetrow) <= 1 and math.abs(Column - Targetcolumn) <= 1 then
				local Image = Dirtframe:WaitForChild(tostring(Index))
				assert(Image:IsA("ImageLabel"), "RestorationService: " .. Image:GetFullName() .. " doit être un ImageLabel")
				local Power = (if Index == Targetindex then Dirtcenterpower else Dirtneighborpower) * Dirttoolpower[Toolname]
				local Transparency = math.clamp(Image.ImageTransparency + Power, 0, 1)
				Removeddirt += Transparency - Image.ImageTransparency
				Image.ImageTransparency = Transparency
			end
		end
		if Removeddirt <= 0 then return end
		local Totaldirt = tonumber(Sessionobject:GetAttribute("Total_Dirt")) or 0
		local Cleaneddirt = math.min((tonumber(Sessionobject:GetAttribute("Cleaned_Dirt")) or 0) + Removeddirt, Totaldirt)
		if Totaldirt - Cleaneddirt < 0.000001 then Cleaneddirt = Totaldirt end
		local Previouscleaneddirt = tonumber(Sessionobject:GetAttribute("Cleaned_Dirt")) or 0
		local Appliedprogress = Cleaneddirt - Previouscleaneddirt
		Sessionobject:SetAttribute("Cleaned_Dirt", Cleaneddirt)
		local Dirtweight = tonumber(Sessionobject:GetAttribute("DirtWeight")) or 1
		local Totalspots = tonumber(Sessionobject:GetAttribute("TotalSpots")) or 0
		local Cleanedspots = math.min((tonumber(Sessionobject:GetAttribute("CleanedSpots")) or 0) + Appliedprogress * Dirtweight, Totalspots)
		if Totalspots - Cleanedspots < 0.000001 then Cleanedspots = Totalspots end
		Sessionobject:SetAttribute("CleanedSpots", Cleanedspots)
	end)

	Remotemanager:OnServerEvent(self.Name, "CleanSpot", function(Player, Spot, Toolname)
		local Sessionobject = Sessions[Player]
		if not Sessionobject then
			return
		end
		if typeof(Spot) ~= "Instance" or not Spot:IsA("BasePart") then
			return
		end
		local Spots = Sessionobject:FindFirstChild("RestorationSpots")
		if not Spots or not Spot:IsDescendantOf(Spots) then
			return
		end
		local Kind = Spot:GetAttribute("SpotKind")
		local Allowedtools = Toolsforspot[Kind]
		local Isallowed = Allowedtools == Toolname
		if type(Allowedtools) == "table" then
			Isallowed = table.find(Allowedtools, Toolname) ~= nil
		end
		if not Isallowed then
			return
		end
		local Now = os.clock()
		if Now - (Lastclean[Player] or 0) < 0.045 then
			return
		end
		Lastclean[Player] = Now
		local Health = (Spot:GetAttribute("Health") or 1) - (Toolpower[Toolname] or 0)
		if Health <= 0 then
			Sessionobject:SetAttribute("CleanedSpots", (Sessionobject:GetAttribute("CleanedSpots") or 0) + 1)
			Sessionobject:SetAttribute("Cleaned_" .. Kind, (Sessionobject:GetAttribute("Cleaned_" .. Kind) or 0) + 1)
			if Kind == "Sticker" and Toolname == "Tweezers" then
				Spot.CanQuery = false
				local Weld = Spot:FindFirstChildOfClass("WeldConstraint")
				if Weld then
					Weld:Destroy()
				end
				Spot.Anchored = true
				local Peeldirection = Spot.CFrame.LookVector
				local Peeledcframe = Spot.CFrame + Peeldirection * 0.65 + Vector3.new(0, 0.28, 0)
				Peeledcframe *= CFrame.Angles(math.rad(55), math.rad(18), math.rad(30))
				local Tween = Tweenservice:Create(Spot, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = Peeledcframe,
					Transparency = 1,
					Size = Vector3.new(Spot.Size.X * 0.72, Spot.Size.Y * 0.72, Spot.Size.Z),
				})
				Tween:Play()
				Tween.Completed:Once(function()
					Spot:Destroy()
				end)
			else
				Spot:Destroy()
			end
		else
			Spot:SetAttribute("Health", Health)
			Spot.Transparency = math.clamp(Spot.Transparency + 0.35, 0, 0.85)
		end
	end)

	Remotemanager:OnServerEvent(self.Name, "SessionEnded", function(Player)
		local Sessionobject = Sessions[Player]
		Sessions[Player] = nil
		Lastclean[Player] = nil
		Lastscratchclean[Player] = nil
		Lastinkclean[Player] = nil
		if Sessionobject and Activeobject == Sessionobject then Cleanupactiveobjectifidle() end
		task.defer(function() self:TryPrepareNextGrantedObject() end)
	end)

	Players.PlayerRemoving:Connect(function(Player)
		local Sessionobject = Sessions[Player]
		local Spot = Peeling[Player]
		if Spot and Spot.Parent then
			Spot:SetAttribute("PeelingBy", nil)
		end
		Peeling[Player] = nil
		Sessions[Player] = nil
		Lastclean[Player] = nil
		Lastscratchclean[Player] = nil
		Lastinkclean[Player] = nil
		for Index = #Grantedobjectqueue, 1, -1 do
			if Grantedobjectqueue[Index].Player == Player then table.remove(Grantedobjectqueue, Index) end
		end
		local Activeowneruserid = if Activeobject then tonumber(Activeobject:GetAttribute("AwardedUserId")) else nil
		if next(Sessions) == nil and (Activeobject == Sessionobject or Activeowneruserid == Player.UserId) then
			Destroyobject(Activeobject)
			Activeobject = nil
		end
		task.defer(function() self:TryPrepareNextGrantedObject() end)
	end)
end

return Restorationservice
