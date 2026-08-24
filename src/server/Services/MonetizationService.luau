local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Config = require(ReplicatedStorage.Shared.Config.Monetization)
local DailyRewardsConfig = require(ReplicatedStorage.Shared.Config.DailyRewards)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local MonetizationService = {
	Name = "MonetizationService",
	Priority = 3,
	Remotes = {
		GetShopState = "Function",
		StarterPackGranted = "Event",
		ShopStateUpdated = "Event",
		TestGamePass = "Function",
	},
}

local GamePassCache: { [Player]: { [string]: boolean } } = {}
local PersonalReputationBoostEndsAt: { [Player]: number } = {}
local ServerLuckLevel = 0
local ServerLuckEndsAt = 0

local function Now(): number
	return workspace:GetServerTimeNow()
end

local function FindGamePassName(GamePassId: number): string?
	for Name, Id in pairs(Config.GamePasses) do
		if tonumber(Id) == GamePassId and GamePassId > 0 then
			return Name
		end
	end
	if Config.StarterPack.PurchaseType == "GamePass" and tonumber(Config.StarterPack.Id) == GamePassId and GamePassId > 0 then
		return "StarterPack"
	end
	return nil
end

local function GetGamePassId(PassName: string): number
	if PassName == "StarterPack" and Config.StarterPack.PurchaseType == "GamePass" then
		return tonumber(Config.StarterPack.Id) or 0
	end
	return tonumber(Config.GamePasses[PassName]) or 0
end

function MonetizationService:RefreshGamePass(Player: Player, PassName: string): boolean
	local Id = GetGamePassId(PassName)
	local Owns = false
	if Id > 0 then
		local Success, Result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, Player.UserId, Id)
		Owns = Success and Result == true
	end
	GamePassCache[Player] = GamePassCache[Player] or {}
	GamePassCache[Player][PassName] = Owns
	Player:SetAttribute("Owns" .. PassName, Owns)
	return Owns
end

function MonetizationService:OwnsGamePass(Player: Player, PassName: string): boolean
	local Cache = GamePassCache[Player]
	if Cache and Cache[PassName] ~= nil then
		return Cache[PassName]
	end
	return self:RefreshGamePass(Player, PassName)
end

function MonetizationService:GetSaleMultiplier(Player: Player): number
	local Multiplier = if self:OwnsGamePass(Player, "DoubleMoney") then 2 else 1
	if self:OwnsGamePass(Player, "VIP") then
		Multiplier *= 1 + (tonumber(Config.VIP.SaleBonusPercent) or 0) / 100
	end
	Multiplier *= Core:GetService("DailyRewardService"):GetSaleMultiplier(Player)
	return Multiplier
end

function MonetizationService:GetVIPCustomerDiscount(Player: Player): number
	return if self:OwnsGamePass(Player, "VIP") then tonumber(Config.VIP.CustomerDiscountPercent) or 0 else 0
end

function MonetizationService:GetReputationMultiplier(Player: Player): number
	local PersonalMultiplier = 1
	local PersonalEnd = PersonalReputationBoostEndsAt[Player] or 0
	if PersonalEnd > Now() then
		PersonalMultiplier = tonumber(Config.StarterPack.ReputationMultiplier) or 2
	end

	local ServerMultiplier = 1
	if ServerLuckEndsAt > Now() and ServerLuckLevel > 0 then
		local Level = Config.ServerReputationLuck.Levels[ServerLuckLevel]
		ServerMultiplier = if Level then tonumber(Level.Multiplier) or 1 else 1
	end
	return PersonalMultiplier * ServerMultiplier
end

function MonetizationService:GetShopState(Player: Player)
	local CurrentTime = Now()
	local EffectiveServerLuckLevel = if ServerLuckEndsAt > CurrentTime then ServerLuckLevel else 0
	local EffectiveServerLuckEndsAt = if EffectiveServerLuckLevel > 0 then ServerLuckEndsAt else 0
	local EffectivePersonalBoostEndsAt = if (PersonalReputationBoostEndsAt[Player] or 0) > CurrentTime
		then PersonalReputationBoostEndsAt[Player]
		else 0
	local NextLevel = EffectiveServerLuckLevel + 1
	local NextDefinition = if NextLevel <= #Config.ServerReputationLuck.Levels then Config.ServerReputationLuck.Levels[NextLevel] else nil
	local CurrentDefinition = Config.ServerReputationLuck.Levels[EffectiveServerLuckLevel]
	return {
		GamePasses = Config.GamePasses,
		CashProducts = Config.CashProducts,
		StarterPackId = tonumber(Config.StarterPack.Id) or 0,
		StarterPackPurchaseType = tostring(Config.StarterPack.PurchaseType or "DeveloperProduct"),
		OwnsStarterPack = if Config.StarterPack.PurchaseType == "GamePass" then self:OwnsGamePass(Player, "StarterPack") else false,
		OwnsVIP = self:OwnsGamePass(Player, "VIP"),
		OwnsDoubleMoney = self:OwnsGamePass(Player, "DoubleMoney"),
		PersonalReputationBoostEndsAt = EffectivePersonalBoostEndsAt,
		ReputationMultiplier = self:GetReputationMultiplier(Player),
		ServerLuckLevel = EffectiveServerLuckLevel,
		ServerLuckMultiplier = if CurrentDefinition then CurrentDefinition.Multiplier else 1,
		ServerLuckEndsAt = EffectiveServerLuckEndsAt,
		ServerLuckNextMultiplier = if NextDefinition then NextDefinition.Multiplier else nil,
		ServerLuckNextProductId = if NextDefinition then tonumber(NextDefinition.Id) or 0 else 0,
	}
end

function MonetizationService:PushState(Player: Player)
	RemoteManager:FireClient(self.Name, "ShopStateUpdated", Player, self:GetShopState(Player))
end

function MonetizationService:PushAllStates()
	for _, Player in ipairs(Players:GetPlayers()) do
		self:PushState(Player)
	end
end

function MonetizationService:StarterPackObjectReady(Player: Player)
	RemoteManager:FireClient(self.Name, "StarterPackGranted", Player)
end

function MonetizationService:GrantStarterPack(Player: Player): boolean
	local Granted, Ready = Core:GetService("RestorationService"):GrantObject(Player, tostring(Config.StarterPack.ObjectKey), function()
		self:StarterPackObjectReady(Player)
	end)
	if not Granted then
		return false
	end
	Core:GetService("CashService"):AddCash(Player, tonumber(Config.StarterPack.Cash) or 0, false)
	local CurrentTime = Now()
	PersonalReputationBoostEndsAt[Player] = math.max(PersonalReputationBoostEndsAt[Player] or 0, CurrentTime) + (tonumber(Config.StarterPack.ReputationDurationSeconds) or 0)
	self:PushState(Player)
	Core:GetService("ExpositionService"):RefreshPlayerReputation(Player)
	if Ready then self:StarterPackObjectReady(Player) end
	return true
end

function MonetizationService:GrantGamePass(Player: Player, PassName: string)
	GamePassCache[Player] = GamePassCache[Player] or {}
	GamePassCache[Player][PassName] = true
	Player:SetAttribute("Owns" .. PassName, true)
	if PassName == "StarterPack" then self:GrantStarterPack(Player) end
	if PassName == "VIP" then Core:GetService("CustomerService"):RefreshPendingOfferPrice(Player) end
	if PassName == "VIP" or PassName == "DoubleMoney" then Core:GetService("InventoryService"):PushItems(Player) end
	self:PushState(Player)
end

function MonetizationService:GrantServerLuck(Level: number): boolean
	if Level < 1 or Level > #Config.ServerReputationLuck.Levels then
		return false
	end
	if ServerLuckEndsAt <= Now() then
		ServerLuckLevel = 0
		ServerLuckEndsAt = 0
	end
	ServerLuckLevel = math.max(ServerLuckLevel, Level)
	ServerLuckEndsAt = math.max(ServerLuckEndsAt, Now()) + (tonumber(Config.ServerReputationLuck.DurationPerPurchaseSeconds) or 0)
	self:PushAllStates()
	Core:GetService("ExpositionService"):RefreshAllReputations()
	return true
end

function MonetizationService:HandleDeveloperProduct(Player: Player, ProductId: number, PurchaseId: string?): boolean
	if ProductId > 0 and tonumber(DailyRewardsConfig.SkipProductId) == ProductId then
		return Core:GetService("DailyRewardService"):HandleDeveloperProduct(Player, ProductId, PurchaseId or "")
	end
	if ProductId > 0 and tonumber(Config.SkipDayProductId) == ProductId then
		return Core:GetService("DayNightService"):SkipToNextDayStart()
	end
	for _, Product in pairs(Config.CashProducts) do
		if ProductId > 0 and tonumber(Product.Id) == ProductId then
			Core:GetService("CashService"):AddCash(Player, tonumber(Product.Amount) or 0, false)
			return true
		end
	end
	if Config.StarterPack.PurchaseType ~= "GamePass" and ProductId > 0 and tonumber(Config.StarterPack.Id) == ProductId then
		return self:GrantStarterPack(Player)
	end
	for Level, Definition in ipairs(Config.ServerReputationLuck.Levels) do
		if ProductId > 0 and tonumber(Definition.Id) == ProductId then
			return self:GrantServerLuck(Level)
		end
	end
	return Core:GetService("UpgradeService"):HandleDeveloperProduct(Player, ProductId)
end

function MonetizationService:Init()
	local function SetupPlayer(Player: Player)
		GamePassCache[Player] = {}
		if RunService:IsStudio() then
			for PassName in pairs(Config.GamePasses) do
				GamePassCache[Player][PassName] = false
				Player:SetAttribute("Owns" .. PassName, false)
			end
			if Config.StarterPack.PurchaseType == "GamePass" then
				GamePassCache[Player].StarterPack = false
				Player:SetAttribute("OwnsStarterPack", false)
			end
			task.defer(function() self:PushState(Player) end)
			return
		end
		task.spawn(function()
			for PassName in pairs(Config.GamePasses) do
				if not Player.Parent then return end
				self:RefreshGamePass(Player, PassName)
			end
			if Config.StarterPack.PurchaseType == "GamePass" and Player.Parent then
				self:RefreshGamePass(Player, "StarterPack")
			end
			if Player.Parent then self:PushState(Player) end
		end)
	end

	for _, Player in ipairs(Players:GetPlayers()) do SetupPlayer(Player) end
	Players.PlayerAdded:Connect(SetupPlayer)
	Players.PlayerRemoving:Connect(function(Player)
		GamePassCache[Player] = nil
		PersonalReputationBoostEndsAt[Player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(Player, GamePassId, WasPurchased)
		if not WasPurchased then return end
		local PassName = FindGamePassName(GamePassId)
		if PassName then self:GrantGamePass(Player, PassName) end
	end)

	RemoteManager:OnServerInvoke(self.Name, "GetShopState", function(Player)
		return self:GetShopState(Player)
	end)
	RemoteManager:OnServerInvoke(self.Name, "TestGamePass", function(Player, PassName)
		if not RunService:IsStudio() then return false end
		if GetGamePassId(PassName) <= 0 then return false end
		if GamePassCache[Player][PassName] then return false end
		self:GrantGamePass(Player, PassName)
		return true
	end)

	MarketplaceService.ProcessReceipt = function(ReceiptInfo)
		local Player = Players:GetPlayerByUserId(ReceiptInfo.PlayerId)
		if not Player then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local Success, Granted = pcall(function()
			return self:HandleDeveloperProduct(Player, ReceiptInfo.ProductId, tostring(ReceiptInfo.PurchaseId))
		end)
		if not Success then
			warn("MonetizationService: erreur de reçu: " .. tostring(Granted))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not Granted then
			warn(string.format("MonetizationService: Developer Product inconnu (%d)", ReceiptInfo.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	task.spawn(function()
		while true do
			task.wait(1)
			local CurrentTime = Now()
			local ServerBoostExpired = ServerLuckEndsAt > 0 and ServerLuckEndsAt <= CurrentTime
			local ExpiredPersonalBoosts = {}
			if ServerBoostExpired then
				ServerLuckLevel = 0
				ServerLuckEndsAt = 0
			end
			for Player, EndsAt in pairs(PersonalReputationBoostEndsAt) do
				if EndsAt <= CurrentTime then
					PersonalReputationBoostEndsAt[Player] = nil
					table.insert(ExpiredPersonalBoosts, Player)
				end
			end
			if ServerBoostExpired then
				self:PushAllStates()
				Core:GetService("ExpositionService"):RefreshAllReputations()
			else
				for _, Player in ipairs(ExpiredPersonalBoosts) do
					if Player.Parent then
						self:PushState(Player)
						Core:GetService("ExpositionService"):RefreshPlayerReputation(Player)
					end
				end
				if ServerLuckEndsAt > CurrentTime then self:PushAllStates() end
			end
		end
	end)
end

return MonetizationService
