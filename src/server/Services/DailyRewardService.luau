local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Config = require(ReplicatedStorage.Shared.Config.DailyRewards)
local Datastorerequest = require(script.Parent.Parent.Utils.Datastorerequest)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local DailyRewardService = {
	Name = "DailyRewardService",
	Priority = 4,
	Remotes = {
		ClaimReward = "Function",
		GetState = "Function",
		StateUpdated = "Event",
	},
}

type DailyRewardData = {
	ClaimedDays: number,
	NextClaimAt: number,
	SaleBoostEndsAt: number,
	ProcessedPurchases: { string },
}

local Store = DataStoreService:GetDataStore("DailyRewards_v2")
local GetOptions = Instance.new("DataStoreGetOptions")
GetOptions.UseCache = false
local DataByPlayer: { [Player]: DailyRewardData } = {}
local LoadedByPlayer: { [Player]: boolean } = {}
local ActiveBoostByPlayer: { [Player]: boolean } = {}
local BlockedByPlayer: { [Player]: boolean } = {}
local ErroredByPlayer: { [Player]: boolean } = {}
local ExistedByPlayer: { [Player]: boolean } = {}
local WritingByUserId: { [number]: boolean } = {}
local ActiveWrites = 0
local MaximumStoredPurchases = 50
local LoadAttempts = 5
local SaveAttempts = 3
local ShutdownTimeout = 25

local function Now(): number
	return workspace:GetServerTimeNow()
end

local function FiniteNumber(Value: any): number
	local Number = tonumber(Value) or 0
	if Number ~= Number or Number == math.huge or Number == -math.huge then return 0 end
	return Number
end

local function NewData(): DailyRewardData
	return {
		ClaimedDays = 0,
		NextClaimAt = 0,
		SaleBoostEndsAt = 0,
		ProcessedPurchases = {},
	}
end

local function NormalizeData(Saved): DailyRewardData
	local Data = NewData()
	if type(Saved) ~= "table" then return Data end
	Data.ClaimedDays = math.clamp(math.floor(FiniteNumber(Saved.ClaimedDays)), 0, #Config.Rewards)
	Data.NextClaimAt = math.max(FiniteNumber(Saved.NextClaimAt), 0)
	Data.SaleBoostEndsAt = math.max(FiniteNumber(Saved.SaleBoostEndsAt), 0)
	if type(Saved.ProcessedPurchases) == "table" then
		for _, PurchaseId in ipairs(Saved.ProcessedPurchases) do
			if type(PurchaseId) == "string" then table.insert(Data.ProcessedPurchases, PurchaseId) end
		end
	end
	while #Data.ProcessedPurchases > MaximumStoredPurchases do table.remove(Data.ProcessedPurchases, 1) end
	return Data
end

local function SerializeData(Data: DailyRewardData)
	return {
		ClaimedDays = Data.ClaimedDays,
		NextClaimAt = Data.NextClaimAt,
		SaleBoostEndsAt = Data.SaleBoostEndsAt,
		ProcessedPurchases = table.clone(Data.ProcessedPurchases),
	}
end

local function ResetCycleIfNeeded(Data: DailyRewardData, CurrentTime: number): boolean
	if Data.ClaimedDays < #Config.Rewards or Data.NextClaimAt <= 0 or CurrentTime < Data.NextClaimAt then return false end
	Data.ClaimedDays = 0
	Data.NextClaimAt = 0
	return true
end

local function HasProcessedPurchase(Data: DailyRewardData, PurchaseId: string): boolean
	return table.find(Data.ProcessedPurchases, PurchaseId) ~= nil
end

local function AddProcessedPurchase(Data: DailyRewardData, PurchaseId: string)
	table.insert(Data.ProcessedPurchases, PurchaseId)
	while #Data.ProcessedPurchases > MaximumStoredPurchases do table.remove(Data.ProcessedPurchases, 1) end
end

function DailyRewardService:LoadPlayer(Player: Player)
	local UserId = Player.UserId
	DataByPlayer[Player] = NewData()
	while WritingByUserId[UserId] do task.wait() end
	local Success, Saved = Datastorerequest.Run(LoadAttempts, function()
		return Store:GetAsync(tostring(UserId), GetOptions)
	end)
	if not Player.Parent then
		DataByPlayer[Player] = nil
		return
	end
	if Success then
		DataByPlayer[Player] = NormalizeData(Saved)
		ExistedByPlayer[Player] = Saved ~= nil
	else
		ErroredByPlayer[Player] = true
		warn("DailyRewardService: failed to load data for " .. Player.Name .. ", saving is disabled for this session: " .. tostring(Saved))
	end
	LoadedByPlayer[Player] = true
	ActiveBoostByPlayer[Player] = DataByPlayer[Player].SaleBoostEndsAt > Now()
	task.defer(function()
		if Player.Parent then self:PushState(Player) end
	end)
end

function DailyRewardService:WaitForData(Player: Player): DailyRewardData?
	while Player.Parent and not LoadedByPlayer[Player] do task.wait() end
	return DataByPlayer[Player]
end

function DailyRewardService:Wipe(UserId: number): (boolean, string)
	local Player = Players:GetPlayerByUserId(UserId)
	if Player then
		BlockedByPlayer[Player] = true
		DataByPlayer[Player] = NewData()
	end
	ActiveWrites += 1
	while WritingByUserId[UserId] do task.wait() end
	WritingByUserId[UserId] = true
	local Success, Result = Datastorerequest.Run(SaveAttempts, function()
		return Store:RemoveAsync(tostring(UserId))
	end)
	WritingByUserId[UserId] = nil
	ActiveWrites -= 1
	if not Success then
		warn("DailyRewardService: could not erase data for " .. UserId .. ": " .. tostring(Result))
		return false, tostring(Result)
	end
	return true, if Result == nil then "no save found" else "save erased"
end

function DailyRewardService:Peek(Player: Player): DailyRewardData?
	local Data = DataByPlayer[Player]
	if not Data or not LoadedByPlayer[Player] or ErroredByPlayer[Player] then return nil end
	return SerializeData(Data)
end

function DailyRewardService:Read(UserId: number): (boolean, any)
	local Success, Saved = Datastorerequest.Run(SaveAttempts, function()
		return Store:GetAsync(tostring(UserId), GetOptions)
	end)
	return Success, Saved
end

function DailyRewardService:SavePlayer(Player: Player): boolean
	local UserId = Player.UserId
	ActiveWrites += 1
	while WritingByUserId[UserId] do task.wait() end
	if
		not LoadedByPlayer[Player]
		or BlockedByPlayer[Player]
		or ErroredByPlayer[Player]
		or Core:GetService("DataService"):IsLost(Player)
	then
		ActiveWrites -= 1
		return false
	end
	local Snapshot = SerializeData(DataByPlayer[Player])
	local Existed = ExistedByPlayer[Player] == true
	local Erased = false
	WritingByUserId[UserId] = true
	local Success, Error = Datastorerequest.Run(SaveAttempts, function()
		Store:UpdateAsync(tostring(UserId), function(Current)
			if Current == nil and Existed then
				Erased = true
				return nil
			end
			Erased = false
			return Snapshot, { UserId }
		end)
	end)
	WritingByUserId[UserId] = nil
	ActiveWrites -= 1
	if not Success then
		warn("DailyRewardService: failed to save data for " .. Player.Name .. ": " .. tostring(Error))
		return false
	end
	if Erased then
		BlockedByPlayer[Player] = true
		warn("DailyRewardService: " .. Player.Name .. "'s daily reward data was erased elsewhere, saving stopped")
		return false
	end
	if LoadedByPlayer[Player] then
		ExistedByPlayer[Player] = true
	end
	return true
end

function DailyRewardService:BuildState(Player: Player)
	local Data = self:WaitForData(Player)
	if not Data then return nil end
	local CurrentTime = Now()
	if ResetCycleIfNeeded(Data, CurrentTime) and not ErroredByPlayer[Player] then task.spawn(function() self:SavePlayer(Player) end) end
	local CurrentDay = if Data.ClaimedDays < #Config.Rewards then Data.ClaimedDays + 1 else 0
	return {
		ClaimedDays = Data.ClaimedDays,
		CurrentDay = CurrentDay,
		CanClaim = CurrentDay > 0 and (Data.ClaimedDays == 0 or CurrentTime >= Data.NextClaimAt),
		NextClaimAt = Data.NextClaimAt,
		SaleBoostEndsAt = Data.SaleBoostEndsAt,
		SkipProductId = tonumber(Config.SkipProductId) or 0,
	}
end

function DailyRewardService:PushState(Player: Player, Granted: string?)
	local State = self:BuildState(Player)
	if State then RemoteManager:FireClient(self.Name, "StateUpdated", Player, State, Granted) end
end

function DailyRewardService:GrantReward(Player: Player, Day: number): boolean
	local Reward = Config.Rewards[Day]
	if Reward.Type == "Cash" then
		Core:GetService("CashService"):AddCash(Player, tonumber(Reward.Amount) or 0, false, false)
		return true
	end
	if Reward.Type == "Item" then
		return (Core:GetService("RestorationService"):GrantObject(Player, Reward.ObjectKey))
	end
	if Reward.Type == "SaleBoost" then
		ActiveBoostByPlayer[Player] = true
		return true
	end
	return false
end

function DailyRewardService:ClaimNextReward(Player: Player)
	local Data = self:WaitForData(Player)
	local DataService = Core:GetService("DataService")
	if not Data or ErroredByPlayer[Player] or not DataService:CanSave(Player) then return { Success = false, Reason = "DataUnavailable" } end
	local CurrentTime = Now()
	ResetCycleIfNeeded(Data, CurrentTime)
	local Day = Data.ClaimedDays + 1
	if Day > #Config.Rewards then return { Success = false, Reason = "CycleComplete", State = self:BuildState(Player) } end
	local CanClaim = Data.ClaimedDays == 0 or CurrentTime >= Data.NextClaimAt
	if not CanClaim then return { Success = false, Reason = "NotReady", State = self:BuildState(Player) } end
	local Reward = Config.Rewards[Day]
	local PreviousClaimedDays = Data.ClaimedDays
	local PreviousNextClaimAt = Data.NextClaimAt
	local PreviousSaleBoostEndsAt = Data.SaleBoostEndsAt
	local function RevertClaim()
		Data.ClaimedDays = PreviousClaimedDays
		Data.NextClaimAt = PreviousNextClaimAt
		if Reward.Type == "SaleBoost" then Data.SaleBoostEndsAt = PreviousSaleBoostEndsAt end
	end
	Data.ClaimedDays = Day
	Data.NextClaimAt = CurrentTime + (tonumber(Config.ClaimIntervalSeconds) or 0)
	if Reward.Type == "SaleBoost" then
		Data.SaleBoostEndsAt = math.max(Data.SaleBoostEndsAt, CurrentTime) + (tonumber(Reward.DurationSeconds) or 0)
	end
	if not self:SavePlayer(Player) then
		RevertClaim()
		return { Success = false, Reason = "SaveFailed", State = self:BuildState(Player) }
	end
	if not DataService:CanSave(Player) or not self:GrantReward(Player, Day) then
		RevertClaim()
		self:SavePlayer(Player)
		return { Success = false, Reason = "RewardFailed", State = self:BuildState(Player) }
	end
	task.spawn(function() DataService:Save(Player) end)
	self:PushState(Player, if Reward.Type == "SaleBoost" then "DailySaleBoost" else nil)
	if Reward.Type == "SaleBoost" then Core:GetService("InventoryService"):PushItems(Player) end
	return {
		Success = true,
		Day = Day,
		RewardType = Reward.Type,
		RewardText = Reward.ValueText,
		State = self:BuildState(Player),
	}
end

function DailyRewardService:UnlockNextReward(Player: Player, PurchaseId: string?)
	local Data = self:WaitForData(Player)
	if not Data or ErroredByPlayer[Player] then return { Success = false, Reason = "DataUnavailable" } end
	if PurchaseId and HasProcessedPurchase(Data, PurchaseId) then
		return { Success = true, State = self:BuildState(Player) }
	end
	local CurrentTime = Now()
	ResetCycleIfNeeded(Data, CurrentTime)
	local Day = Data.ClaimedDays + 1
	if Day > #Config.Rewards then return { Success = false, Reason = "CycleComplete", State = self:BuildState(Player) } end
	local PreviousNextClaimAt = Data.NextClaimAt
	Data.NextClaimAt = 0
	if PurchaseId then AddProcessedPurchase(Data, PurchaseId) end
	local Saved = self:SavePlayer(Player)
	if PurchaseId and not Saved and not RunService:IsStudio() then
		if Data.NextClaimAt == 0 then Data.NextClaimAt = PreviousNextClaimAt end
		local Index = table.find(Data.ProcessedPurchases, PurchaseId)
		if Index then table.remove(Data.ProcessedPurchases, Index) end
		return { Success = false, Reason = "SaveFailed", State = self:BuildState(Player) }
	end
	self:PushState(Player)
	return { Success = true, Day = Day, State = self:BuildState(Player) }
end

function DailyRewardService:GrantSaleBoost(Player: Player, Seconds: number)
	local Data = self:WaitForData(Player)
	if not Data then
		return
	end
	Data.SaleBoostEndsAt = math.max(Data.SaleBoostEndsAt, Now()) + math.max(FiniteNumber(Seconds), 0)
	task.spawn(function() self:SavePlayer(Player) end)
	self:PushState(Player, "DailySaleBoost")
	Core:GetService("InventoryService"):PushItems(Player)
end

function DailyRewardService:GetSaleMultiplier(Player: Player): number
	local Data = DataByPlayer[Player]
	if not Data or Data.SaleBoostEndsAt <= Now() then return 1 end
	local Reward = Config.Rewards[4]
	return 1 + (tonumber(Reward.Percent) or 0) / 100
end

function DailyRewardService:HandleDeveloperProduct(Player: Player, ProductId: number, PurchaseId: string): boolean
	if ProductId <= 0 or ProductId ~= tonumber(Config.SkipProductId) then return false end
	return self:UnlockNextReward(Player, PurchaseId).Success == true
end

function DailyRewardService:Init()
	local function SetupPlayer(Player: Player)
		task.spawn(function() self:LoadPlayer(Player) end)
	end

	for _, Player in ipairs(Players:GetPlayers()) do SetupPlayer(Player) end
	Players.PlayerAdded:Connect(SetupPlayer)
	Players.PlayerRemoving:Connect(function(Player)
		self:SavePlayer(Player)
		DataByPlayer[Player] = nil
		LoadedByPlayer[Player] = nil
		ActiveBoostByPlayer[Player] = nil
		BlockedByPlayer[Player] = nil
		ErroredByPlayer[Player] = nil
		ExistedByPlayer[Player] = nil
	end)

	RemoteManager:OnServerInvoke(self.Name, "GetState", function(Player)
		return self:BuildState(Player)
	end)
	RemoteManager:OnServerInvoke(self.Name, "ClaimReward", function(Player)
		Core:GetService("DataService"):WaitForLoad(Player)
		if not Player.Parent then
			return { Success = false, Reason = "DataUnavailable" }
		end
		return self:ClaimNextReward(Player)
	end)
	game:BindToClose(function()
		for _, Player in ipairs(Players:GetPlayers()) do
			task.spawn(function() self:SavePlayer(Player) end)
		end
		local Deadline = os.clock() + ShutdownTimeout
		while ActiveWrites > 0 and os.clock() < Deadline do task.wait() end
	end)
end

function DailyRewardService:Start()
	task.spawn(function()
		while true do
			task.wait(1)
			local CurrentTime = Now()
			for Player, Data in pairs(table.clone(DataByPlayer)) do
				if LoadedByPlayer[Player] and Player.Parent then
					local Changed = ResetCycleIfNeeded(Data, CurrentTime)
					local BoostActive = Data.SaleBoostEndsAt > CurrentTime
					if ActiveBoostByPlayer[Player] and not BoostActive then
						Data.SaleBoostEndsAt = 0
						Changed = true
						Core:GetService("InventoryService"):PushItems(Player)
					end
					ActiveBoostByPlayer[Player] = BoostActive
					if Changed then
						task.spawn(function() self:SavePlayer(Player) end)
						self:PushState(Player)
					end
				end
			end
		end
	end)
end

return DailyRewardService
