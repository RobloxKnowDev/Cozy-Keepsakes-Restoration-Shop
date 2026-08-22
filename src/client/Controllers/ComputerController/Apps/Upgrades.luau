local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local Upgrades = {}
local ErrorColor = Color3.fromRGB(255, 92, 92)
local RobuxIcon = ""

local function FormatValue(UpgradeName: string, Value: number?): string
	if Value == nil then return "MAX" end
	if UpgradeName == "PurchaseDiscount" then return string.format("%d%%", Value) end
	if UpgradeName == "PriceEstimation" then return string.format("%d estimated / day", Value) end
	if UpgradeName == "DailyCustomers" then return string.format("%d / day", Value) end
	if UpgradeName == "DisplaySpace" then return string.format("%d slots", Value) end
	return tostring(Value)
end

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
		if CardData.ProductRequestId ~= RequestId then return end
		local Price = Success and type(Info) == "table" and tonumber(Info.PriceInRobux) or nil
		CardData.RobuxPriceText.Text = if Price then string.format("%s%d", RobuxIcon, math.floor(Price)) else "N/A"
	end)
end

local function ApplyCard(Controller, UpgradeName: string, State)
	local CardData = Controller.upgradeCards[UpgradeName]
	if not CardData or not State then return end
	local IsMax = State.MaxLevel ~= nil and State.Level >= State.MaxLevel
	local WasMax = CardData.IsMaxLevel == true
	CardData.IsMaxLevel = IsMax
	CardData.LevelText.Text = if State.MaxLevel then string.format("Level %d / %d", State.Level, State.MaxLevel) else string.format("Level %d / ∞", State.Level)
	CardData.CurrentText.Text = FormatValue(UpgradeName, State.CurrentValue)
	CardData.NextText.Text = FormatValue(UpgradeName, State.NextValue)
	CardData.CashPriceText.Text = if IsMax then "MAX" else Shared.FormatCurrency(State.CashPrice or 0)
	CardData.CashButton.Active = not IsMax
	CardData.CashButton.AutoButtonColor = not IsMax
	local ProductId = tonumber(State.DeveloperProductId) or 0
	CardData.ProductId = ProductId
	CardData.RobuxButton.Active = not IsMax and ProductId > 0
	CardData.RobuxButton.AutoButtonColor = not IsMax and ProductId > 0
	if IsMax then
		CardData.ProductRequestId += 1
		CardData.RobuxPriceText.Text = "MAX"
	elseif WasMax or CardData.LastProductId ~= ProductId then
		CardData.LastProductId = ProductId
		LoadRobuxPrice(CardData, ProductId)
	end
end

function Upgrades.Apply(Controller, State)
	if type(State) ~= "table" then return end
	Controller.upgradeState = State
	for UpgradeName in pairs(Controller.upgradeCards) do ApplyCard(Controller, UpgradeName, State[UpgradeName]) end
end

local function BindCard(Controller, UpgradeName: string)
	local Card = Controller.upgradesScrollingFrame:WaitForChild(UpgradeName)
	local Button = Card:WaitForChild("Button")
	local CashButton = Button:WaitForChild("UpgradeButton")
	local RobuxButton = Button:WaitForChild("RobuxButton")
	local CardData = {
		CashButton = CashButton,
		RobuxButton = RobuxButton,
		CashPriceText = CashButton:WaitForChild("PriceText"),
		RobuxPriceText = RobuxButton:WaitForChild("PriceText"),
		LevelText = Button:WaitForChild("LevelText"),
		CurrentText = Button:WaitForChild("CurrentText"),
		NextText = Button:WaitForChild("NextText"),
		ProductId = 0,
		LastProductId = nil,
		IsMaxLevel = false,
		ProductRequestId = 0,
	}
	Controller.upgradeCards[UpgradeName] = CardData
	Shared.AnimateButton(CashButton, function() return not CashButton.Active end)
	Shared.AnimateButton(RobuxButton, function() return not RobuxButton.Active end)
	CashButton.Activated:Connect(function()
		if not CashButton.Active then return end
		local Response = RemoteManager:InvokeServer("UpgradeService", "PurchaseWithCash", UpgradeName)
		if type(Response) == "table" and Response.Success == true then return end
		local Reason = type(Response) == "table" and Response.Reason or "UpgradeFailed"
		local Message = if Reason == "NotEnoughCash" then "Not enough money" elseif Reason == "MaxLevel" then "Maximum level reached" else "Upgrade purchase failed"
		Core:GetController("MessageController"):Show(Message, ErrorColor)
	end)
	RobuxButton.Activated:Connect(function()
		if RobuxButton.Active and CardData.ProductId > 0 then
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, CardData.ProductId)
		end
	end)
end

function Upgrades.Init(Controller)
	Controller.upgradesScrollingFrame = Controller.upgradesFrame:WaitForChild("ScrollingFrame")
	Controller.upgradesGridLayout = Controller.upgradesScrollingFrame:WaitForChild("UIGridLayout")
	Controller.upgradeCards = {}
	Controller.upgradeState = {}
	for _, Name in ipairs({ "PriceEstimation", "DailyCustomers", "PurchaseDiscount", "DisplaySpace" }) do BindCard(Controller, Name) end
	Upgrades.Apply(Controller, RemoteManager:InvokeServer("UpgradeService", "GetUpgrades"))
end

function Upgrades.Start(Controller)
	Controller.upgradesGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		Controller.upgradesScrollingFrame.CanvasSize = UDim2.fromOffset(0, Controller.upgradesGridLayout.AbsoluteContentSize.Y)
	end)
	RemoteManager:OnClientEvent("UpgradeService", "UpgradesUpdated", function(State) Upgrades.Apply(Controller, State) end)
end

return Upgrades
