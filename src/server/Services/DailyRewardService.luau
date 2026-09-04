local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Config = require(ReplicatedStorage.Shared.Config.DailyRewards)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local DailyRewardService = {
	Name = "DailyRewardService",
	Priority = 4,
	Remotes = {
		ClaimReward = "Function",
		GetState = "Function",
		ObjectRewardReady = "Event",
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
local DataByPlayer: { [Player]: DailyRewardData } = {}
local LoadedByPlayer: { [Player]: boolean } = {}
local ActiveBoostByPlayer: { [Player]: boolean } = {}
local MaximumStoredPurchases = 50

local function Now(): number
	return workspace:GetServerTimeNow()
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
	Data.ClaimedDays = math.clamp(math.floor(tonumber(Saved.ClaimedDays) or 0), 0, #Config.Rewards)
	Data.NextClaimAt = math.max(tonumber(Saved.NextClaimAt) or 0, 0)
	Data.SaleBoostEndsAt = math.max(tonumber(Saved.SaleBoostEndsAt) or 0, 0)
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
	DataByPlayer[Player] = NewData()
	local Success, Saved = pcall(function()
		return Store:GetAsync(tostring(Player.UserId))
	end)
	if not Player.Parent then
		DataByPlayer[Player] = nil
		return
	end
	if Success then
		DataByPlayer[Player] = NormalizeData(Saved)
	else
		warn("DailyRewardService: failed to load data for " .. Player.Name .. ": " .. tostring(Saved))
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

function DailyRewardService:Wipe(Player: Player)
	DataByPlayer[Player] = NewData()
	local Success, Error = pcall(function()
		Store:RemoveAsync(tostring(Player.UserId))
	end)
	if not Success then
		warn("DailyRewardService: could not erase data for " .. Player.Name .. ": " .. tostring(Error))
	end
end

function DailyRewardService:SavePlayer(Player: Player): boolean
	if not LoadedByPlayer[Player] then return false end
	local Snapshot = SerializeData(DataByPlayer[Player])
	local Success, Error = pcall(function()
		Store:SetAsync(tostring(Player.UserId), Snapshot)
	end)
	if not Success then warn("DailyRewardService: failed to save data for " .. Player.Name .. ": " .. tostring(Error)) end
	return Success
end

function DailyRewardService:BuildState(Player: Player)
	local Data = self:WaitForData(Player)
	if not Data then return nil end
	local CurrentTime = Now()
	if ResetCycleIfNeeded(Data, CurrentTime) then task.spawn(function() self:SavePlayer(Player) end) end
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

function DailyRewardService:PushState(Player: Player)
	local State = self:BuildState(Player)
	if State then RemoteManager:FireClient(self.Name, "StateUpdated", Player, State) end
end

function DailyRewardService:ObjectRewardReady(Player: Player)
	RemoteManager:FireClient(self.Name, "ObjectRewardReady", Player)
end

function DailyRewardService:GrantReward(Player: Player, Day: number, Data: DailyRewardData): (boolean, boolean)
	local Reward = Config.Rewards[Day]
	if Reward.Type == "Cash" then
		Core:GetService("CashService"):AddCash(Player, tonumber(Reward.Amount) or 0, false, false)
		return true, false
	end
	if Reward.Type == "Object" then
		return Core:GetService("RestorationService"):GrantObject(Player, tostring(Reward.ObjectKey), function()
			self:ObjectRewardReady(Player)
		end)
	end
	if Reward.Type == "SaleBoost" then
		Data.SaleBoostEndsAt = math.max(Data.SaleBoostEndsAt, Now()) + (tonumber(Reward.DurationSeconds) or 0)
		ActiveBoostByPlayer[Player] = true
		return true, false
	end
	return false, false
end

function DailyRewardService:ClaimNextReward(Player: Player)
	local Data = self:WaitForData(Player)
	if not Data then return { Success = false, Reason = "DataUnavailable" } end
	local CurrentTime = Now()
	ResetCycleIfNeeded(Data, CurrentTime)
	local Day = Data.ClaimedDays + 1
	if Day > #Config.Rewards then return { Success = false, Reason = "CycleComplete", State = self:BuildState(Player) } end
	local CanClaim = Data.ClaimedDays == 0 or CurrentTime >= Data.NextClaimAt
	if not CanClaim then return { Success = false, Reason = "NotReady", State = self:BuildState(Player) } end
	local Granted, ObjectReady = self:GrantReward(Player, Day, Data)
	if not Granted then return { Success = false, Reason = "RewardFailed", State = self:BuildState(Player) } end
	Data.ClaimedDays = Day
	Data.NextClaimAt = CurrentTime + (tonumber(Config.ClaimIntervalSeconds) or 0)
	self:SavePlayer(Player)
	self:PushState(Player)
	if Config.Rewards[Day].Type == "SaleBoost" then Core:GetService("InventoryService"):PushItems(Player) end
	return {
		Success = true,
		Day = Day,
		RewardType = Config.Rewards[Day].Type,
		ObjectReady = ObjectReady,
		State = self:BuildState(Player),
	}
end

function DailyRewardService:UnlockNextReward(Player: Player, PurchaseId: string?)
	local Data = self:WaitForData(Player)
	if not Data then return { Success = false, Reason = "DataUnavailable" } end
	if PurchaseId and HasProcessedPurchase(Data, PurchaseId) then
		return { Success = true, State = self:BuildState(Player) }
	end
	local Previous = SerializeData(Data)
	local CurrentTime = Now()
	ResetCycleIfNeeded(Data, CurrentTime)
	local Day = Data.ClaimedDays + 1
	if Day > #Config.Rewards then return { Success = false, Reason = "CycleComplete", State = self:BuildState(Player) } end
	Data.NextClaimAt = 0
	if PurchaseId then AddProcessedPurchase(Data, PurchaseId) end
	local Saved = self:SavePlayer(Player)
	if PurchaseId and not Saved and not RunService:IsStudio() then
		Data.ClaimedDays = Previous.ClaimedDays
		Data.NextClaimAt = Previous.NextClaimAt
		Data.SaleBoostEndsAt = Previous.SaleBoostEndsAt
		Data.ProcessedPurchases = Previous.ProcessedPurchases
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
	Data.SaleBoostEndsAt = math.max(Data.SaleBoostEndsAt, Now()) + Seconds
	self:PushState(Player)
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
	end)

	RemoteManager:OnServerInvoke(self.Name, "GetState", function(Player)
		return self:BuildState(Player)
	end)
	RemoteManager:OnServerInvoke(self.Name, "ClaimReward", function(Player)
		return self:ClaimNextReward(Player)
	end)
	game:BindToClose(function()
		for _, Player in ipairs(Players:GetPlayers()) do self:SavePlayer(Player) end
	end)
end

function DailyRewardService:Start()
	task.spawn(function()
		while true do
			task.wait(1)
			local CurrentTime = Now()
			for Player, Data in pairs(DataByPlayer) do
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
						self:SavePlayer(Player)
						self:PushState(Player)
					end
				end
			end
		end
	end)
end

return DailyRewardService
