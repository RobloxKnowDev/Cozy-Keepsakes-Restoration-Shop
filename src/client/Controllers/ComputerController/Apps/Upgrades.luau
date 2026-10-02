local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Customerconfig = require(ReplicatedStorage.Shared.Config.Customer)
local FormatDuration = require(ReplicatedStorage.Shared.Utils.DurationFormatter)
local Rarityconfig = require(ReplicatedStorage.Shared.Config.Rarity)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local Upgrades = {}
local ErrorGradient = Rarityconfig.Mythic.Gradient
local RobuxIcon = " "
local ValueTexts = {
	PurchaseDiscount = function(Value: number): string
		return string.format("%d%%", Value)
	end,
	CooldownReduction = function(Value: number): string
		return FormatDuration(Customerconfig.GetInterval(Value))
	end,
}
local SecondTexts = {
	PurchaseDiscount = "-1%",
	CooldownReduction = string.format("-%ds", Customerconfig.SecondsPerCooldownLevel),
}

local function LoadRobuxPrice(CardData, ProductId: number)
	CardData.ProductRequestId = (CardData.ProductRequestId or 0) + 1
	local RequestId = CardData.ProductRequestId
	if ProductId <= 0 then
		CardData.RobuxPriceText.Text = "N/A"
		return
	end
	CardData.RobuxPriceText.Text = "..."
	task.spawn(function()
		local Success, Info = pcall(function()
			return MarketplaceService:GetProductInfo(ProductId, Enum.InfoType.Product)
		end)
		if CardData.ProductRequestId ~= RequestId then
			return
		end
		local Price = Success and type(Info) == "table" and tonumber(Info.PriceInRobux) or nil
		CardData.RobuxPriceText.Text = if Price then string.format("%s%d", RobuxIcon, math.floor(Price)) else "N/A"
	end)
end

local function ApplyCard(Controller, UpgradeName: string, State)
	local CardData = Controller.upgradeCards[UpgradeName]
	if not CardData or not State then
		return
	end
	local IsMax = State.MaxLevel ~= nil and State.Level >= State.MaxLevel
	local WasMax = CardData.IsMaxLevel == true
	CardData.IsMaxLevel = IsMax
	local FormatValue = ValueTexts[UpgradeName]
	CardData.LevelText.Text = if FormatValue
		then FormatValue(State.CurrentValue)
		elseif State.MaxLevel then string.format("%d/%d", State.Level, State.MaxLevel)
		else string.format("%d/∞", State.Level)
	CardData.CashPriceText.Text = if IsMax then "Max" else Shared.FormatCurrency(State.CashPrice or 0)
	CardData.SecondText.Visible = SecondTexts[UpgradeName] ~= nil and not IsMax
	local ProductId = tonumber(State.DeveloperProductId) or 0
	CardData.ProductId = ProductId
	if IsMax then
		CardData.ProductRequestId += 1
		CardData.RobuxPriceText.Text = "Max"
	elseif WasMax or CardData.LastProductId ~= ProductId then
		CardData.LastProductId = ProductId
		LoadRobuxPrice(CardData, ProductId)
	end
end

function Upgrades.Apply(Controller, State)
	if type(State) ~= "table" then
		return
	end
	Controller.upgradeState = State
	for UpgradeName in pairs(Controller.upgradeCards) do
		ApplyCard(Controller, UpgradeName, State[UpgradeName])
	end
end

local function BindCard(Controller, UpgradeName: string)
	local Card = Controller.upgradesScrollingFrame:WaitForChild(UpgradeName)
	local Button = Card:WaitForChild("Button")
	local CashButton = Button:WaitForChild("BuyButton")
	local RobuxButton = Button:WaitForChild("RobuxButton")
	local SecondText = CashButton:WaitForChild("SecondText")
	SecondText.Text = SecondTexts[UpgradeName] or ""
	local CardData = {
		CashButton = CashButton,
		RobuxButton = RobuxButton,
		CashPriceText = CashButton:WaitForChild("PriceText"),
		RobuxPriceText = RobuxButton:WaitForChild("PriceText"),
		SecondText = SecondText,
		LevelText = Button:WaitForChild("LevelText"),
		ProductId = 0,
		LastProductId = nil,
		IsMaxLevel = false,
		ProductRequestId = 0,
	}
	Controller.upgradeCards[UpgradeName] = CardData
	Shared.AnimateButton(CashButton, function()
		return false
	end)
	Shared.AnimateButton(RobuxButton, function()
		return false
	end)
	CashButton:SetAttribute("SilentClick", true)
	Core:GetController("GamepadController"):OnActivated(CashButton, function()
		local Feedback = Core:GetController("FeedbackController")
		if CardData.IsMaxLevel then
			Feedback:UiClick()
			return
		end
		local State = Controller.upgradeState and Controller.upgradeState[UpgradeName]
		local Price = tonumber(State and State.CashPrice) or 0
		if Core:GetController("CashController"):GetCash() >= Price then
			Feedback:Confirm()
		else
			Feedback:UiClick()
		end
		local Response = RemoteManager:InvokeServer("UpgradeService", "PurchaseWithCash", UpgradeName)
		if type(Response) == "table" and Response.Success == true then
			return
		end
		local Reason = type(Response) == "table" and Response.Reason or "UpgradeFailed"
		local Message = if Reason == "NotEnoughCash"
			then "Not enough money"
			elseif Reason == "MaxLevel" then "Maximum level reached"
			else "Upgrade purchase failed"
		Core:GetController("MessageController"):Show(Message, ErrorGradient)
	end)
	Core:GetController("GamepadController"):OnActivated(RobuxButton, function()
		if not CardData.IsMaxLevel and CardData.ProductId > 0 then
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, CardData.ProductId)
		end
	end)
end

function Upgrades.Init(Controller)
	Controller.upgradesScrollingFrame = Controller.upgradesPage:WaitForChild("ScrollingFrame")
	Controller.upgradesGridLayout = Controller.upgradesScrollingFrame:WaitForChild("UIGridLayout")
	Controller.upgradeCards = {}
	Controller.upgradeState = {}
	for _, Name in ipairs({
		"PriceEstimation",
		"DailyCustomers",
		"PurchaseDiscount",
		"DisplaySpace",
		"CooldownReduction",
	}) do
		BindCard(Controller, Name)
	end
end

function Upgrades.Start(Controller)
	Controller.upgradesGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		Controller.upgradesScrollingFrame.CanvasSize =
			UDim2.fromOffset(0, Controller.upgradesGridLayout.AbsoluteContentSize.Y)
	end)
	RemoteManager:OnClientEvent("UpgradeService", "UpgradesUpdated", function(State)
		Upgrades.Apply(Controller, State)
	end)
	Upgrades.Apply(Controller, RemoteManager:InvokeServer("UpgradeService", "GetUpgrades"))
	Controller.upgradesScrollingFrame.CanvasSize = UDim2.fromOffset(0, Controller.upgradesGridLayout.AbsoluteContentSize.Y)
end

return Upgrades
