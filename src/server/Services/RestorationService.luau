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
		CompleteRestoration = "Function",
		CompletePeel = "Event",
		CancelPeel = "Event",
		CleanSpot = "Event",
		SessionEnded = "Event",
	},
}

local Spotcount = 2
local Spotkinds = { "Dirt", "Sticker" }
local Spothealth = { Dirt = 6, Sticker = 3, Adhesive = 3, Scratch = 4 }
local Toolpower = { CottonTip = 1, HeatGun = 1, Polish = 1, Solvent = 1, ToothBrush = 1, Tweezers = 1 }
local Toolsforspot = {
	Dirt = { "ToothBrush", "CottonTip" },
	Sticker = "Tweezers",
	Adhesive = "Solvent",
	Scratch = "Polish",
}

type RestorationObject = Model | BasePart

local Sessions: { [Player]: RestorationObject } = {}
local Lastclean: { [Player]: number } = {}
local Peeling: { [Player]: BasePart } = {}
local Activeobject: RestorationObject? = nil
local Grantedobjectqueue: { { Player: Player, Objectname: string, OnReady: (() -> ())? } } = {}

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

local function Spawnconfiguredobject(Objectname: string): RestorationObject
	local Spawnattachment = Workspace:WaitForChild("Spawn") :: Attachment
	local Definition = Config.Object[Objectname]
	local Asset = Replicatedstorage:WaitForChild("Asset"):WaitForChild("Object"):WaitForChild(Objectname)
	local Object = Asset:Clone() :: RestorationObject
	local Maxvalue = tonumber(Definition.MaxValue) or tonumber(Definition.MaxPrice) or 0
	Object.Name = Objectname
	Object:SetAttribute("RestorationObject", true)
	Object:SetAttribute("KeepSpawnPosition", true)
	Object:SetAttribute("SpawnFloorY", Spawnattachment.WorldPosition.Y)
	Object:SetAttribute("DisplayName", Definition.Name or Objectname)
	Object:SetAttribute("MaxPrice", Maxvalue)
	Object:SetAttribute("MaxValue", Maxvalue)
	Object:SetAttribute("Rarity", Definition.Rarity or Definition.Rarety or "Common")
	Object:SetAttribute("ImageId", Definition.IdImage or "")
	Object.Parent = Workspace
	if Object:IsA("Model") then
		Object:PivotTo(Spawnattachment.WorldCFrame)
	else
		Object.CFrame = Spawnattachment.WorldCFrame
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

local function Randompointonsurface(Size: Vector3): (Vector3, Vector3)
	local Face = math.random(1, 6)
	local Sx, Sy, Sz = Size.X / 2, Size.Y / 2, Size.Z / 2
	if Face == 1 then
		return Vector3.new(Sx, (math.random() - 0.5) * Size.Y, (math.random() - 0.5) * Size.Z), Vector3.xAxis
	end
	if Face == 2 then
		return Vector3.new(-Sx, (math.random() - 0.5) * Size.Y, (math.random() - 0.5) * Size.Z), -Vector3.xAxis
	end
	if Face == 3 then
		return Vector3.new((math.random() - 0.5) * Size.X, Sy, (math.random() - 0.5) * Size.Z), Vector3.yAxis
	end
	if Face == 4 then
		return Vector3.new((math.random() - 0.5) * Size.X, -Sy, (math.random() - 0.5) * Size.Z), -Vector3.yAxis
	end
	if Face == 5 then
		return Vector3.new((math.random() - 0.5) * Size.X, (math.random() - 0.5) * Size.Y, Sz), Vector3.zAxis
	end
	return Vector3.new((math.random() - 0.5) * Size.X, (math.random() - 0.5) * Size.Y, -Sz), -Vector3.zAxis
end

local function Createspots(Object: RestorationObject)
	local Old = Object:FindFirstChild("RestorationSpots")
	if Old then
		Old:Destroy()
	end

	local Folder = Instance.new("Folder")
	Folder.Name = "RestorationSpots"
	Folder.Parent = Object

	local Totals = {}
	for _, Kind in ipairs(Spotkinds) do
		Totals[Kind] = 0
		Object:SetAttribute("Total_" .. Kind, 0)
		Object:SetAttribute("Cleaned_" .. Kind, 0)
	end

	local Surfaces = {}
	if Object:IsA("BasePart") then
		table.insert(Surfaces, Object)
	else
		for _, Descendant in ipairs(Object:GetDescendants()) do
			if Descendant:IsA("BasePart") then
				table.insert(Surfaces, Descendant)
			end
		end
	end
	if #Surfaces == 0 then
		return
	end

	for Index = 1, Spotcount do
		local Kind = Spotkinds[((Index - 1) % #Spotkinds) + 1]
		Totals[Kind] += 1
		local Surface = Surfaces[((Index - 1) % #Surfaces) + 1]
		local Localposition, Normal = Randompointonsurface(Surface.Size)
		local Spot = Instance.new("Part")
		Spot.Name = Kind .. "Spot"
		Spot.Shape = Enum.PartType.Block
		if Kind == "Dirt" then
			local Width = math.random(65, 120) / 100
			local Height = math.random(40, 85) / 100
			Spot.Size = Vector3.new(Width, Height, 0.025)
			Spot.Color = Color3.fromRGB(101, 82, 64)
			Spot.Material = Enum.Material.Ground
			Spot.Transparency = 0.04
		elseif Kind == "Adhesive" then
			local Width = math.random(45, 95) / 100
			local Height = math.random(30, 70) / 100
			Spot.Size = Vector3.new(Width, Height, 0.018)
			Spot.Color = Color3.fromRGB(238, 234, 218)
			Spot.Material = Enum.Material.SmoothPlastic
			Spot.Transparency = 0.22
		elseif Kind == "Sticker" then
			local Width = math.random(45, 90) / 100
			local Height = math.random(40, 80) / 100
			Spot.Size = Vector3.new(Width, Height, 0.02)
			Spot.Color = Color3.fromRGB(72, 205, 96)
			Spot.Material = Enum.Material.SmoothPlastic
			Spot.Transparency = 0
		else
			local Length = math.random(45, 110) / 100
			local Thickness = math.random(3, 7) / 100
			Spot.Size = Vector3.new(Length, Thickness, 0.012)
			Spot.Color = Color3.fromRGB(95, 97, 101)
			Spot.Material = Enum.Material.Metal
			Spot.Transparency = 0.08
		end
		Spot.CanCollide = false
		Spot.CanQuery = true
		Spot.CanTouch = false
		Spot.Massless = true
		Spot:SetAttribute("SpotKind", Kind)
		Spot:SetAttribute("Health", Spothealth[Kind])
		local Worldnormal = Surface.CFrame:VectorToWorldSpace(Normal)
		local Surfaceposition = Surface.CFrame:PointToWorldSpace(Localposition) + Worldnormal * 0.035
		Spot.CFrame = CFrame.lookAt(Surfaceposition, Surfaceposition + Worldnormal)
		Spot.CFrame *= CFrame.Angles(0, 0, math.rad(math.random(0, 359)))
		Spot.Parent = Folder
		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = Surface
		Weld.Part1 = Spot
		Weld.Parent = Spot
	end
	for Kind, Total in pairs(Totals) do
		Object:SetAttribute("Total_" .. Kind, Total)
	end
	Object:SetAttribute("TotalSpots", Spotcount)
	Object:SetAttribute("CleanedSpots", 0)
end

function Restorationservice:PrepareObject(Objectname: string, Owner: Player?): RestorationObject
	Destroyobject(Activeobject)
	local Object = Spawnconfiguredobject(Objectname)
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
	Remotemanager:OnServerInvoke(self.Name, "BeginSession", function(Player)
		local Object = Activeobject
		if not Object or not Object.Parent then
			return nil
		end
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

		local Inventoryservice = Core:GetService("InventoryService")
		local Completionratio = Getcompletionratio(Sessionobject)
		local Maxvalue = tonumber(Sessionobject:GetAttribute("MaxValue")) or tonumber(Sessionobject:GetAttribute("MaxPrice")) or 0
		local Salevalue = math.round(Maxvalue * Completionratio * 100) / 100
		local Purchaseprice = tonumber(Sessionobject:GetAttribute("PurchasePrice")) or 0
		local Restoreditem = Inventoryservice:AddRestoredItem(Player, {
			Id = 0,
			Name = tostring(Sessionobject:GetAttribute("DisplayName") or Sessionobject.Name),
			ImageId = tostring(Sessionobject:GetAttribute("ImageId") or ""),
			Rarity = tostring(Sessionobject:GetAttribute("Rarity") or "Common"),
			RestorationPercent = math.floor(Completionratio * 100 + 0.5),
			PurchasePrice = Purchaseprice,
			CurrentValue = Salevalue,
			MaxValue = Maxvalue,
			NetProfit = math.round((Salevalue - Purchaseprice) * 100) / 100,
		})

		if Completionratio >= 0.5 then
			Inventoryservice:UnlockIndexEntry(Player, Sessionobject.Name)
		end

		Sessionobject:SetAttribute("SaleValue", Salevalue)

		local Spot = Peeling[Player]
		if Spot and Spot.Parent then
			Spot:SetAttribute("PeelingBy", nil)
		end
		Peeling[Player] = nil
		Sessions[Player] = nil
		Lastclean[Player] = nil

		if Activeobject == Sessionobject then
			Activeobject = nil
		end
		Destroyobject(Sessionobject)
		Cleanupactiveobjectifidle()

		return Restoreditem
	end)

	Remotemanager:OnServerEvent(self.Name, "CompletePeel", function(Player, Spot)
		local Object, Valid = Validsessionspot(Player, Spot)
		if not Object or not Valid or Peeling[Player] ~= Spot or Spot:GetAttribute("PeelingBy") ~= Player.UserId then
			return
		end
		Peeling[Player] = nil
		Spot.CanQuery = false
		Object:SetAttribute("CleanedSpots", (Object:GetAttribute("CleanedSpots") or 0) + 1)
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
		Sessions[Player] = nil
		Cleanupactiveobjectifidle()
		task.defer(function() self:TryPrepareNextGrantedObject() end)
	end)

	Players.PlayerRemoving:Connect(function(Player)
		local Spot = Peeling[Player]
		if Spot and Spot.Parent then
			Spot:SetAttribute("PeelingBy", nil)
		end
		Peeling[Player] = nil
		Sessions[Player] = nil
		Lastclean[Player] = nil
		for Index = #Grantedobjectqueue, 1, -1 do
			if Grantedobjectqueue[Index].Player == Player then table.remove(Grantedobjectqueue, Index) end
		end
		Cleanupactiveobjectifidle()
		task.defer(function() self:TryPrepareNextGrantedObject() end)
	end)
end

return Restorationservice
