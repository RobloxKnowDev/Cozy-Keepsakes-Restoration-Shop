local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Tweenservice = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(Replicatedstorage.Shared.Config.Object)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Restorationservice = {
	Name = "RestorationService",
	Priority = 10,
	Remotes = {
		BeginSession = "Function",
		BeginPeel = "Function",
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

local function Validsessionspot(Player: Player, Spot: any): (RestorationObject?, boolean)
	local Object = Sessions[Player]
	if not Object or typeof(Spot) ~= "Instance" or not Spot:IsA("BasePart") then return Object, false end
	local Spots = Object:FindFirstChild("RestorationSpots")
	return Object, Spots ~= nil and Spot:IsDescendantOf(Spots)
end

local function Isnamedobject(Instance: Instance): boolean
	if not Instance:IsA("BasePart") and not Instance:IsA("Model") then
		return false
	end
	if Instance:GetAttribute("RestorationObject") == true then
		return true
	end
	for Assetname in pairs(Config.Object) do
		if string.lower(Instance.Name) == string.lower(Assetname) then
			return true
		end
	end
	return false
end

local function Spawnconfiguredobject(): RestorationObject?
	local Spawnattachment = Workspace:FindFirstChild("Spawn", true)
	if not Spawnattachment or not Spawnattachment:IsA("Attachment") then
		warn("RestorationService: attachment Workspace.Spawn introuvable")
		return nil
	end

	local Objectassets = Replicatedstorage:WaitForChild("Asset"):WaitForChild("Object")
	for Assetname, Definition in pairs(Config.Object) do
		local Asset = Objectassets:FindFirstChild(Assetname)
		if not Asset or (not Asset:IsA("Model") and not Asset:IsA("BasePart")) then
			warn(string.format("RestorationService: Asset/Object/%s introuvable ou invalide", Assetname))
			continue
		end

		local Object = Asset:Clone() :: RestorationObject
		Object.Name = Assetname
		Object:SetAttribute("RestorationObject", true)
		Object:SetAttribute("KeepSpawnPosition", true)
		Object:SetAttribute("SpawnFloorY", Spawnattachment.WorldPosition.Y)
		Object:SetAttribute("DisplayName", Definition.Name)
		Object:SetAttribute("MaxPrice", Definition.MaxPrice)
		Object.Parent = Workspace
		if Object:IsA("Model") then
			Object:PivotTo(Spawnattachment.WorldCFrame)
		else
			Object.CFrame = Spawnattachment.WorldCFrame
		end

		
		local Boundscframe, boundsSize
		if Object:IsA("Model") then
			Boundscframe, boundsSize = Object:GetBoundingBox()
		else
			Boundscframe, boundsSize = Object.CFrame, Object.Size
		end
		local Bottomy = Boundscframe.Position.Y - boundsSize.Y * 0.5
		local Heightoffset = Spawnattachment.WorldPosition.Y - Bottomy
		if Object:IsA("Model") then
			Object:PivotTo(Object:GetPivot() + Vector3.new(0, Heightoffset, 0))
		else
			Object.CFrame += Vector3.new(0, Heightoffset, 0)
		end
		return Object
	end
	return nil
end

local function Findobject(): RestorationObject
	local Spawnedobject = Spawnconfiguredobject()
	if Spawnedobject then return Spawnedobject end

	for _, Descendant in ipairs(Workspace:GetChildren()) do
		if Isnamedobject(Descendant) then
			return Descendant :: RestorationObject
		end
	end
	for _, Descendant in ipairs(Workspace:GetDescendants()) do
		if Isnamedobject(Descendant) then return Descendant :: RestorationObject end
	end
	for _, Child in ipairs(Workspace:GetChildren()) do
		if Child:IsA("BasePart") and Child.Name == "Part" and Child.Size.Magnitude <= 30 then
			return Child
		end
	end

	local Demo = Instance.new("Part")
	Demo.Name = "RestorationObject"
	Demo.Size = Vector3.new(5.5, 1.1, 3.6)
	Demo.CFrame = CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(20), 0)
	Demo.Color = Color3.fromRGB(109, 116, 107)
	Demo.Material = Enum.Material.SmoothPlastic
	Demo.Anchored = true
	Demo:SetAttribute("RestorationObject", true)
	Demo.Parent = Workspace
	return Demo
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
			if Descendant:IsA("BasePart") then table.insert(Surfaces, Descendant) end
		end
	end
	if #Surfaces == 0 then return end

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

function Restorationservice:Init()
	local Object = Findobject()
	if Object:IsA("BasePart") then
		Object.Anchored = true
	else
		for _, Descendant in ipairs(Object:GetDescendants()) do
			if Descendant:IsA("BasePart") then Descendant.Anchored = true end
		end
	end
	Object:SetAttribute("RestorationObject", true)
	Createspots(Object)

	Remotemanager:OnServerInvoke(self.Name, "BeginSession", function(Player)
		if not Object.Parent then
			return nil
		end
		Sessions[Player] = Object
		return Object
	end)

	Remotemanager:OnServerInvoke(self.Name, "BeginPeel", function(Player, Spot)
		local _, Valid = Validsessionspot(Player, Spot)
		if not Valid or Spot:GetAttribute("SpotKind") ~= "Sticker" then return false end
		local Owner = Spot:GetAttribute("PeelingBy")
		if Owner and Owner ~= Player.UserId then return false end
		Spot:SetAttribute("PeelingBy", Player.UserId)
		Peeling[Player] = Spot
		return true
	end)

	Remotemanager:OnServerEvent(self.Name, "CompletePeel", function(Player, Spot)
		local Object, Valid = Validsessionspot(Player, Spot)
		if not Object or not Valid or Peeling[Player] ~= Spot or Spot:GetAttribute("PeelingBy") ~= Player.UserId then return end
		Peeling[Player] = nil
		Spot.CanQuery = false
		Object:SetAttribute("CleanedSpots", (Object:GetAttribute("CleanedSpots") or 0) + 1)
		Object:SetAttribute("Cleaned_Sticker", (Object:GetAttribute("Cleaned_Sticker") or 0) + 1)
		Spot:Destroy()
	end)

	Remotemanager:OnServerEvent(self.Name, "CancelPeel", function(Player, Spot)
		if Peeling[Player] ~= Spot then return end
		Peeling[Player] = nil
		if Spot.Parent and Spot:GetAttribute("PeelingBy") == Player.UserId then
			Spot:SetAttribute("PeelingBy", nil)
			Spot.CanQuery = true
		end
	end)

	Remotemanager:OnServerEvent(self.Name, "CleanSpot", function(Player, Spot, Toolname)
		local Activeobject = Sessions[Player]
		if not Activeobject then
			return
		end
		if typeof(Spot) ~= "Instance" or not Spot:IsA("BasePart") then
			return
		end
		local Spots = Activeobject:FindFirstChild("RestorationSpots")
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
			Activeobject:SetAttribute("CleanedSpots", (Activeobject:GetAttribute("CleanedSpots") or 0) + 1)
			Activeobject:SetAttribute("Cleaned_" .. Kind, (Activeobject:GetAttribute("Cleaned_" .. Kind) or 0) + 1)
			if Kind == "Sticker" and Toolname == "Tweezers" then
				Spot.CanQuery = false
				local Weld = Spot:FindFirstChildOfClass("WeldConstraint")
				if Weld then Weld:Destroy() end
				Spot.Anchored = true
				local Peeldirection = Spot.CFrame.LookVector
				local Peeledcframe = Spot.CFrame
					+ Peeldirection * 0.65
					+ Vector3.new(0, 0.28, 0)
				Peeledcframe *= CFrame.Angles(math.rad(55), math.rad(18), math.rad(30))
				local Tween = Tweenservice:Create(Spot, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = Peeledcframe,
					Transparency = 1,
					Size = Vector3.new(Spot.Size.X * 0.72, Spot.Size.Y * 0.72, Spot.Size.Z),
				})
				Tween:Play()
				Tween.Completed:Once(function() Spot:Destroy() end)
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
	end)

	Players.PlayerRemoving:Connect(function(Player)
		local Spot = Peeling[Player]
		if Spot and Spot.Parent then Spot:SetAttribute("PeelingBy", nil) end
		Peeling[Player] = nil
		Sessions[Player] = nil
		Lastclean[Player] = nil
	end)
end

return Restorationservice
