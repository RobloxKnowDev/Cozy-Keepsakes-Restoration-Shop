local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.Upgrades)

local UpgradeService = {
	Name = "UpgradeService",
	Priority = 4,
	Remotes = {
		GetUpgrades = "Function",
		PurchaseWithCash = "Function",
		UpgradesUpdated = "Event",
	},
}

type PlayerUpgradeData = {
	Levels: { [string]: number },
	EstimatesUsed: number,
	EstimateDay: number,
}

local DataByPlayer: { [Player]: PlayerUpgradeData } = {}
local StandardPriceGrowth = 1.5
local PurchaseDiscountPriceGrowth = 2

local function CurrentDay(): number
	return tonumber(Lighting:GetAttribute("Day")) or 1
end

local function GetDefinition(UpgradeName: string)
	return UpgradeConfig[UpgradeName]
end

local function GetMaxLevel(Player: Player, UpgradeName: string, Definition): number?
	if UpgradeName == "PurchaseDiscount" then
		return math.max(math.floor(tonumber(Definition.MaxPercent) or 0), Definition.DefaultLevel)
	end
	if UpgradeName == "PriceEstimation" then
		local DailyDefinition = GetDefinition("DailyCustomers")
		local Data = DataByPlayer[Player]
		local DailyLevel = if Data then Data.Levels.DailyCustomers else DailyDefinition.DefaultLevel
		return math.max(math.floor(tonumber(DailyLevel) or 0), DailyDefinition.DefaultLevel)
	end
	return nil
end

local function NormalizeLevel(Player: Player, UpgradeName: string, Definition, Level: number): number
	local Normalized = math.max(math.floor(Level), Definition.DefaultLevel)
	local MaxLevel = GetMaxLevel(Player, UpgradeName, Definition)
	if MaxLevel then
		Normalized = math.min(Normalized, MaxLevel)
	end
	return Normalized
end

function UpgradeService:EnsurePlayer(Player: Player): PlayerUpgradeData
	local Data = DataByPlayer[Player]
	if Data then
		return Data
	end

	local Levels = {}
	for UpgradeName, Definition in pairs(UpgradeConfig) do
		Levels[UpgradeName] = NormalizeLevel(Player, UpgradeName, Definition, Definition.DefaultLevel)
	end
	Data = {
		Levels = Levels,
		EstimatesUsed = 0,
		EstimateDay = CurrentDay(),
	}
	DataByPlayer[Player] = Data
	return Data
end

function UpgradeService:ResetDailyUses(Player: Player)
	local Data = self:EnsurePlayer(Player)
	local Day = CurrentDay()
	if Data.EstimateDay ~= Day then
		Data.EstimateDay = Day
		Data.EstimatesUsed = 0
	end
end

function UpgradeService:GetLevel(Player: Player, UpgradeName: string): number
	local Definition = GetDefinition(UpgradeName)
	if not Definition then
		return 0
	end
	return NormalizeLevel(Player, UpgradeName, Definition, self:EnsurePlayer(Player).Levels[UpgradeName] or Definition.DefaultLevel)
end

function UpgradeService:GetValue(Player: Player, UpgradeName: string): number
	if not GetDefinition(UpgradeName) then
		return 0
	end
	return self:GetLevel(Player, UpgradeName)
end

function UpgradeService:GetCashPrice(Player: Player, UpgradeName: string): number?
	local Definition = GetDefinition(UpgradeName)
	if not Definition then
		return nil
	end
	local Level = self:GetLevel(Player, UpgradeName)
	local MaxLevel = GetMaxLevel(Player, UpgradeName, Definition)
	if MaxLevel and Level >= MaxLevel then
		return nil
	end
	local TargetLevel = Level + 1
	local Growth = if UpgradeName == "PurchaseDiscount" then PurchaseDiscountPriceGrowth else StandardPriceGrowth
	local BasePrice = math.max(tonumber(Definition.CashPriceLevel1) or 0, 0)
	local Price = BasePrice * Growth ^ (TargetLevel - 1)
	return math.max(math.round(Price), 0)
end

function UpgradeService:GetUpgradeState(Player: Player, UpgradeName: string)
	local Definition = GetDefinition(UpgradeName)
	if not Definition then
		return nil
	end
	local Level = self:GetLevel(Player, UpgradeName)
	local MaxLevel = GetMaxLevel(Player, UpgradeName, Definition)
	return {
		Name = UpgradeName,
		Level = Level,
		MaxLevel = MaxLevel,
		CurrentValue = self:GetValue(Player, UpgradeName),
		NextValue = if MaxLevel and Level >= MaxLevel then nil else Level + 1,
		CashPrice = self:GetCashPrice(Player, UpgradeName),
		DeveloperProductId = tonumber(Definition.DeveloperProductId) or 0,
	}
end

function UpgradeService:GetUpgrades(Player: Player)
	self:ResetDailyUses(Player)
	local Result = {}
	for UpgradeName in pairs(UpgradeConfig) do
		Result[UpgradeName] = self:GetUpgradeState(Player, UpgradeName)
	end
	Result.EstimatesRemaining = math.max(self:GetValue(Player, "PriceEstimation") - self:EnsurePlayer(Player).EstimatesUsed, 0)
	return Result
end

function UpgradeService:PushUpgrades(Player: Player)
	RemoteManager:FireClient(self.Name, "UpgradesUpdated", Player, self:GetUpgrades(Player))
end

function UpgradeService:GrantLevel(Player: Player, UpgradeName: string): boolean
	local Definition = GetDefinition(UpgradeName)
	if not Definition then
		return false
	end

	local Data = self:EnsurePlayer(Player)
	local Level = self:GetLevel(Player, UpgradeName)
	local MaxLevel = GetMaxLevel(Player, UpgradeName, Definition)
	if MaxLevel and Level >= MaxLevel then
		return false
	end

	Data.Levels[UpgradeName] = Level + 1
	self:PushUpgrades(Player)
	if UpgradeName == "DailyCustomers" then
		Core:GetService("CustomerService"):RefreshCustomerLimit()
	end
	return true
end

function UpgradeService:PurchaseWithCash(Player: Player, UpgradeName: string)
	if type(UpgradeName) ~= "string" or not GetDefinition(UpgradeName) then
		return { Success = false, Reason = "InvalidUpgrade" }
	end

	local Price = self:GetCashPrice(Player, UpgradeName)
	if Price == nil then
		return { Success = false, Reason = "MaxLevel" }
	end
	if not Core:GetService("CashService"):SpendCash(Player, Price) then
		return { Success = false, Reason = "NotEnoughCash" }
	end
	if not self:GrantLevel(Player, UpgradeName) then
		Core:GetService("CashService"):AddCash(Player, Price)
		return { Success = false, Reason = "UpgradeFailed" }
	end
	return { Success = true, State = self:GetUpgradeState(Player, UpgradeName) }
end

function UpgradeService:ConsumePriceEstimate(Player: Player): boolean
	self:ResetDailyUses(Player)
	local Data = self:EnsurePlayer(Player)
	local Maximum = self:GetValue(Player, "PriceEstimation")
	if Data.EstimatesUsed >= Maximum then
		return false
	end
	Data.EstimatesUsed += 1
	self:PushUpgrades(Player)
	return true
end

function UpgradeService:FindUpgradeByProductId(ProductId: number): string?
	for UpgradeName, Definition in pairs(UpgradeConfig) do
		if tonumber(Definition.DeveloperProductId) == ProductId and ProductId > 0 then
			return UpgradeName
		end
	end
	return nil
end

function UpgradeService:Init()
	for _, Player in ipairs(Players:GetPlayers()) do
		self:EnsurePlayer(Player)
	end

	Players.PlayerAdded:Connect(function(Player)
		self:EnsurePlayer(Player)
		task.defer(function()
			if Player.Parent then
				self:PushUpgrades(Player)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(Player)
		DataByPlayer[Player] = nil
	end)
	Lighting:GetAttributeChangedSignal("Day"):Connect(function()
		for _, Player in ipairs(Players:GetPlayers()) do
			self:ResetDailyUses(Player)
			self:PushUpgrades(Player)
		end
	end)

	RemoteManager:OnServerInvoke(self.Name, "GetUpgrades", function(Player)
		return self:GetUpgrades(Player)
	end)
	RemoteManager:OnServerInvoke(self.Name, "PurchaseWithCash", function(Player, UpgradeName)
		return self:PurchaseWithCash(Player, UpgradeName)
	end)

	MarketplaceService.ProcessReceipt = function(ReceiptInfo)
		local Player = Players:GetPlayerByUserId(ReceiptInfo.PlayerId)
		if not Player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local UpgradeName = self:FindUpgradeByProductId(ReceiptInfo.ProductId)
		if not UpgradeName then
			warn(string.format("UpgradeService: Developer Product inconnu (%d)", ReceiptInfo.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local Definition = GetDefinition(UpgradeName)
		local MaxLevel = Definition and GetMaxLevel(Player, UpgradeName, Definition) or nil
		if MaxLevel and self:GetLevel(Player, UpgradeName) >= MaxLevel then
			-- Le reçu est valide, mais l'achat est arrivé alors que l'upgrade est déjà au maximum.
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		if not self:GrantLevel(Player, UpgradeName) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return UpgradeService
