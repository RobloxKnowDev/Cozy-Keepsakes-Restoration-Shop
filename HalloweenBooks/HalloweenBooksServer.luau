local Badgeservice = game:GetService("BadgeService")
local Datastoreservice = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Serverstorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = {
	BooksRequired = 40,
	BadgeId = 0, --id badge bg
	SkipProductId = 0,
	BooksInZone = 6,
	RespawnDelay = 5,
	PickupRadius = 5,
	FloatHeight = 2.5,
	MinimumSpacing = 12,
	MinimumFlatness = 0.7,
	SpawnAttempts = 25,
	RetryDelay = 1,
	CastMargin = 1,
	CastDepth = 100,
	WarningInterval = 10,
	CollectDuration = 0.6,
	CheckInterval = 0.1,
	AutosaveInterval = 60,
	DataStoreName = "HalloweenBooks2026_v3",
	Texts = {
		NotEnough = "Come back when you have found all %d books! You only have %d.",
		Reward = "You found all my books! As promised, this house is yours. Happy Halloween!",
		Claimed = "I hope you like your new house! Happy Halloween!",
	},
}

local function Givehouse(Player: Player)
	print("[Halloween] " .. Player.Name .. " receives a house")
end

type PlayerData = {
	Books: number,
	Claimed: boolean,
	Met: boolean,
	Dirty: boolean,
}

local Store = Datastoreservice:GetDataStore(Config.DataStoreName)
local Datas: { [Player]: PlayerData } = {}
local Books: { [Model]: Vector3 } = {}
local Eventmap = Workspace:WaitForChild("EventMap")
local Zone = Eventmap:WaitForChild("SpawnZone") :: BasePart
local Spawnlocation = Eventmap:WaitForChild("SpawnLocation") :: BasePart
local Npc = Eventmap:WaitForChild("Wizard") :: Model
assert(Npc.PrimaryPart, "[Halloween] EventMap.Wizard needs a PrimaryPart")
for _, Part in ipairs(Npc:GetDescendants()) do
	if Part:IsA("BasePart") then
		Part.Anchored = Part == Npc.PrimaryPart or #Part:GetJoints() == 0
	end
end

local function Create(Class: string, Name: string, Parent: Instance): any
	local Object = Instance.new(Class)
	Object.Name = Name
	Object.Parent = Parent
	return Object
end

local Remotes = Instance.new("Folder")
Remotes.Name = "HalloweenBooksRemotes"
local Progressevent = Create("RemoteEvent", "Progress", Remotes)
local Collectedevent = Create("RemoteEvent", "Collected", Remotes)
local Dialogueevent = Create("RemoteEvent", "Dialogue", Remotes)
local Getprogress = Create("RemoteFunction", "GetProgress", Remotes)
local Booksfolder = Create("Folder", "HalloweenBooks", Workspace)

local Boxcframe, Boxsize = Npc:GetBoundingBox()
Remotes:SetAttribute("NpcTop", Boxcframe.Position + Vector3.new(0, Boxsize.Y / 2, 0))
Remotes:SetAttribute("NpcCenter", Boxcframe.Position)
Remotes:SetAttribute("ZoneCFrame", Zone.CFrame)
Remotes:SetAttribute("ZoneSize", Zone.Size)
Remotes:SetAttribute("TeleportCFrame", Spawnlocation.CFrame * CFrame.new(0, Spawnlocation.Size.Y / 2, 0))
Remotes:SetAttribute("SkipProductId", Config.SkipProductId)

local Models = Replicatedstorage:WaitForChild("Assets"):WaitForChild("Book"):GetChildren()
local Bookreach = 0
for _, Template in ipairs(Models) do
	local Size = Template:GetExtentsSize()
	Bookreach = math.max(Bookreach, Size.X, Size.Y, Size.Z)
end
local Floatheight = math.max(Config.FloatHeight, Bookreach / 2 + 0.5)

local Hiddenprobe = CFrame.new(0, 10000, 0)
local Probe = Instance.new("Part")
Probe.Name = "HalloweenSpawnProbe"
Probe.Size = Vector3.new(Bookreach + 1, Bookreach + 0.5, Bookreach + 1)
Probe.CFrame = Hiddenprobe
Probe.Transparency = 1
Probe.Anchored = true
Probe.CanCollide = false
Probe.CanTouch = false
Probe.Parent = Workspace

local Raycastparams = RaycastParams.new()
Raycastparams.FilterType = Enum.RaycastFilterType.Exclude
Raycastparams.RespectCanCollide = true
local Overlapparams = OverlapParams.new()
Overlapparams.FilterType = Enum.RaycastFilterType.Exclude

local function Refreshfilters()
	local Ignored: { Instance } = { Booksfolder, Zone, Probe }
	for _, Other in ipairs(Players:GetPlayers()) do
		if Other.Character then
			table.insert(Ignored, Other.Character)
		end
	end
	Overlapparams.FilterDescendantsInstances = Ignored
	table.insert(Ignored, Npc)
	Raycastparams.FilterDescendantsInstances = Ignored
end

local Lastwarning = -math.huge

local function Blocker(Position: Vector3, Ground: Instance): BasePart?
	Probe.CFrame = CFrame.new(Position)
	local Parts = Workspace:GetPartsInPart(Probe, Overlapparams)
	Probe.CFrame = Hiddenprobe
	for _, Part in ipairs(Parts) do
		if Part ~= Ground and (Part.CanCollide or Part.Transparency < 1) then
			return Part
		end
	end
	return nil
end

local function Isfree(Spot: Vector3): boolean
	for _, Position in pairs(Books) do
		if ((Position - Spot) * Vector3.new(1, 0, 1)).Magnitude < Config.MinimumSpacing then
			return false
		end
	end
	return true
end

local function Tryspot(): (Vector3?, string?, BasePart?)
	local Size = Zone.Size
	local Top = Zone.CFrame:PointToWorldSpace(
		Vector3.new((math.random() - 0.5) * Size.X, Size.Y / 2, (math.random() - 0.5) * Size.Z)
	)
	local Start = Top + Vector3.new(0, Config.CastMargin, 0)
	local Result = Workspace:Raycast(Start, Vector3.new(0, -(Size.Y + Config.CastDepth), 0), Raycastparams)
	if not Result then
		return nil, "Noground", nil
	end
	if Result.Normal.Y < Config.MinimumFlatness then
		return nil, "Steep", nil
	end
	local Position = Result.Position + Vector3.new(0, Floatheight, 0)
	if not Isfree(Position) then
		return nil, "Close", nil
	end
	local Part = Blocker(Position, Result.Instance)
	if Part then
		return nil, "Blocked", Part
	end
	return Position, nil, nil
end

local function Findspot(): Vector3?
	Refreshfilters()
	local Reasons = { Noground = 0, Steep = 0, Close = 0, Blocked = 0 }
	local Blockers: { [string]: number } = {}
	for _ = 1, Config.SpawnAttempts do
		local Spot, Reason, Part = Tryspot()
		if Spot then
			return Spot
		end
		Reasons[Reason :: string] += 1
		if Part then
			local Name = Part:GetFullName()
			Blockers[Name] = (Blockers[Name] or 0) + 1
		end
	end
	if os.clock() - Lastwarning >= Config.WarningInterval then
		Lastwarning = os.clock()
		local Worst, Most = "nothing", 0
		for Name, Count in pairs(Blockers) do
			if Count > Most then
				Worst, Most = Name, Count
			end
		end
		warn(
			string.format(
				"[Halloween] no free spot in %d tries: %d without ground under SpawnZone, %d too steep, %d too close to another book, %d blocked (mostly by %s)",
				Config.SpawnAttempts,
				Reasons.Noground,
				Reasons.Steep,
				Reasons.Close,
				Reasons.Blocked,
				Worst
			)
		)
	end
	return nil
end

local function Spawnbook()
	local Spot = Findspot()
	if not Spot then
		task.delay(Config.RetryDelay, Spawnbook)
		return
	end
	local Book = Models[math.random(#Models)]:Clone()
	Book:SetAttribute("Kind", Book.Name)
	Book.Name = "Book"
	Book.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for _, Part in ipairs(Book:GetDescendants()) do
		if Part:IsA("BasePart") then
			Part.Anchored = true
			Part.CanCollide = false
			Part.CanQuery = false
			Part.CanTouch = false
		end
	end
	local Center = Book:GetBoundingBox()
	Book.WorldPivot = Center
	local Seed = math.random() * 10
	local Base = CFrame.new(Spot) * CFrame.Angles(0, Seed, 0)
	Book:PivotTo(Base)
	Book:SetAttribute("Base", Base)
	Book:SetAttribute("Seed", Seed)
	Book.Parent = Booksfolder
	Books[Book] = Spot
end

local Prompt = Instance.new("ProximityPrompt")
Prompt.ActionText = "Talk"
Prompt.ObjectText = "Wizard"
Prompt.HoldDuration = 0
Prompt.MaxActivationDistance = 10
Prompt.RequiresLineOfSight = false
Prompt.Parent = Npc.PrimaryPart

local function Progress(Data: PlayerData)
	return {
		Books = Data.Books,
		Required = Config.BooksRequired,
		Claimed = Data.Claimed,
		Met = Data.Met,
	}
end

local function Key(Userid: number): string
	return "Player_" .. Userid
end

local function Awardbadge(Player: Player)
	local Success, Failure = pcall(function()
		if not Badgeservice:UserHasBadgeAsync(Player.UserId, Config.BadgeId) then
			Badgeservice:AwardBadge(Player.UserId, Config.BadgeId)
		end
	end)
	if not Success then
		warn(
			"[Halloween] could not award badge " .. Config.BadgeId .. " to " .. Player.Name .. ": " .. tostring(Failure)
		)
	end
end

local function Load(Player: Player)
	local Success, Saved = false, nil
	for Attempt = 1, 3 do
		Success, Saved = pcall(function()
			return Store:GetAsync(Key(Player.UserId))
		end)
		if Success then
			break
		end
		if Attempt < 3 then
			task.wait(Attempt)
		end
	end
	if not Success then
		warn("[Halloween] could not load " .. Player.Name .. ": " .. tostring(Saved))
	end
	if not Player.Parent then
		return
	end
	local Stored = if Success and type(Saved) == "table" then Saved else {}
	Datas[Player] = {
		Books = math.clamp(math.floor(tonumber(Stored.Books) or 0), 0, Config.BooksRequired),
		Claimed = Stored.Claimed == true,
		Met = Stored.Met == true,
		Dirty = false,
	}
end

local function Write(Userid: number, Data: PlayerData): boolean
	local Success, Failure = pcall(function()
		Store:UpdateAsync(Key(Userid), function(Stored)
			local Current = if type(Stored) == "table" then Stored else {}
			return {
				Books = math.max(tonumber(Current.Books) or 0, Data.Books),
				Claimed = Current.Claimed == true or Data.Claimed,
				Met = Current.Met == true or Data.Met,
			}
		end)
	end)
	if not Success then
		warn("[Halloween] could not save " .. Userid .. ": " .. tostring(Failure))
	end
	return Success
end

local function Save(Userid: number, Data: PlayerData)
	if not Data.Dirty then
		return
	end
	Data.Dirty = false
	if not Write(Userid, Data) then
		Data.Dirty = true
	end
end

local function Collect(Player: Player, Data: PlayerData, Book: Model)
	Books[Book] = nil
	Data.Books += 1
	Data.Dirty = true
	Collectedevent:FireAllClients(Book, Player)
	Progressevent:FireClient(Player, Progress(Data))
	task.delay(Config.CollectDuration + 0.3, function()
		Book:Destroy()
	end)
	task.delay(Config.RespawnDelay, Spawnbook)
end

Prompt.Triggered:Connect(function(Player)
	local Data = Datas[Player]
	if not Data then
		return
	end
	if not Data.Met then
		Data.Met = true
		Data.Dirty = true
		Progressevent:FireClient(Player, Progress(Data))
	end
	if Data.Claimed then
		task.spawn(Awardbadge, Player)
		Dialogueevent:FireClient(Player, Config.Texts.Claimed)
	elseif Data.Books >= Config.BooksRequired then
		Data.Claimed = true
		Data.Dirty = true
		task.spawn(Awardbadge, Player)
		Givehouse(Player)
		Dialogueevent:FireClient(Player, Config.Texts.Reward)
		Progressevent:FireClient(Player, Progress(Data))
		task.spawn(Save, Player.UserId, Data)
	else
		Dialogueevent:FireClient(Player, string.format(Config.Texts.NotEnough, Config.BooksRequired, Data.Books))
	end
end)

Getprogress.OnServerInvoke = function(Player)
	while Player.Parent and not Datas[Player] do
		task.wait()
	end
	local Data = Datas[Player]
	return if Data then Progress(Data) else nil
end

local Skipreceipt = Instance.new("BindableFunction")
Skipreceipt.Name = tostring(Config.SkipProductId)
Skipreceipt.OnInvoke = function(Receipt)
	local Player = Players:GetPlayerByUserId(Receipt.PlayerId)
	while Player and Player.Parent and not Datas[Player] do
		task.wait()
	end
	local Data = if Player then Datas[Player] else nil
	if not Player or not Data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Data.Books = Config.BooksRequired
	if not Write(Player.UserId, Data) then
		Data.Dirty = true
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Progressevent:FireClient(Player, Progress(Data))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
task.spawn(function()
	Skipreceipt.Parent = Serverstorage:WaitForChild("ReceiptHandlers")
end)

Players.PlayerAdded:Connect(Load)
for _, Player in ipairs(Players:GetPlayers()) do
	task.spawn(Load, Player)
end

Players.PlayerRemoving:Connect(function(Player)
	local Data = Datas[Player]
	Datas[Player] = nil
	if Data then
		Save(Player.UserId, Data)
	end
end)

game:BindToClose(function()
	local Pending = 0
	for Player, Data in pairs(Datas) do
		Pending += 1
		task.spawn(function()
			Save(Player.UserId, Data)
			Pending -= 1
		end)
	end
	local Deadline = os.clock() + 25
	while Pending > 0 and os.clock() < Deadline do
		task.wait()
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for Player, Data in pairs(Datas) do
			task.spawn(Save, Player.UserId, Data)
		end
	end
end)

Remotes.Parent = Replicatedstorage

for _ = 1, Config.BooksInZone do
	Spawnbook()
end
local Spawned = 0
for _, Position in pairs(Books) do
	Spawned += 1
	if Spawned == 1 then
		print(string.format("[Halloween] first book at %.0f, %.0f, %.0f", Position.X, Position.Y, Position.Z))
	end
end
print(string.format("[Halloween] %d/%d books spawned in %s", Spawned, Config.BooksInZone, Zone:GetFullName()))

local Elapsed = 0
Runservice.Heartbeat:Connect(function(Delta)
	Elapsed += Delta
	if Elapsed < Config.CheckInterval then
		return
	end
	Elapsed = 0
	for _, Player in ipairs(Players:GetPlayers()) do
		local Data = Datas[Player]
		local Character = Player.Character
		local Root = if Character then Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if Data and Root and Data.Books < Config.BooksRequired then
			for Book, Position in pairs(Books) do
				if (Root.Position - Position).Magnitude <= Config.PickupRadius then
					Collect(Player, Data, Book)
					break
				end
			end
		end
	end
end)
