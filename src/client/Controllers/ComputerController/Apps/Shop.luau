local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.Monetization)
local ObjectConfig = require(ReplicatedStorage.Shared.Config.Object)
local RarityConfig = require(ReplicatedStorage.Shared.Config.Rarity)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local Shop = {}
local Player = Players.LocalPlayer
local RobuxIcon = "\u{E002}"

local function NewCard(Card: Instance)
	local Button = Card:WaitForChild("RobuxButton") :: GuiButton
	return {
		Button = Button,
		PriceText = Button:WaitForChild("PriceText") :: TextLabel,
		RequestId = 0,
		Owned = false,
	}
end

local function SetPriceText(Card, Text: string)
	Card.RequestId += 1
	Card.PriceText.Text = Text
end

local function LoadPrice(Card, Id: number, InfoType: Enum.InfoType)
	if Id <= 0 then
		SetPriceText(Card, "N/A")
		return
	end
	SetPriceText(Card, "...")
	local RequestId = Card.RequestId
	task.spawn(function()
		local Success, Info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, Id, InfoType)
		if Card.RequestId ~= RequestId then return end
		local Price = if Success then tonumber(Info.PriceInRobux) else nil
		Card.PriceText.Text = if Price then string.format("%s%d", RobuxIcon, Price) else "N/A"
	end)
end

local function BindGamePass(Controller, Card, PassName: string, Id: number)
	Controller.shopPasses[PassName] = Card
	Shared.AnimateButton(Card.Button, function() return false end)
	LoadPrice(Card, Id, Enum.InfoType.GamePass)
	Core:GetController("GamepadController"):OnActivated(Card.Button, function()
		if Card.Owned then return end
		if RunService:IsStudio() then
			RemoteManager:InvokeServer("MonetizationService", "TestGamePass", PassName)
			return
		end
		MarketplaceService:PromptGamePassPurchase(Player, Id)
	end)
end

local function BindProduct(Card, Id: number)
	Shared.AnimateButton(Card.Button, function() return false end)
	LoadPrice(Card, Id, Enum.InfoType.Product)
	Core:GetController("GamepadController"):OnActivated(Card.Button, function()
		MarketplaceService:PromptProductPurchase(Player, Id)
	end)
end

function Shop.ApplyState(Controller, State)
	for PassName, Card in pairs(Controller.shopPasses) do
		if State["Owns" .. PassName] and not Card.Owned then
			Card.Owned = true
			SetPriceText(Card, "Owned")
		end
	end
	local IsMax = State.ServerLuckNextMultiplier == nil
	Controller.serverLuckFirstText.Text = tostring(State.ServerLuckMultiplier) .. "x"
	Controller.serverLuckMiddleText.Text = if IsMax then "Max" else Controller.serverLuckMiddleDefaultText
	Controller.serverLuckSecondText.Text = tostring(State.ServerLuckNextMultiplier or State.ServerLuckMultiplier) .. "x"
	local ProductId = State.ServerLuckNextProductId
	if ProductId == Controller.serverLuckProductId then return end
	Controller.serverLuckProductId = ProductId
	if ProductId > 0 then
		LoadPrice(Controller.serverLuckCard, ProductId, Enum.InfoType.Product)
	else
		SetPriceText(Controller.serverLuckCard, "Max")
	end
end

function Shop.Init(Controller)
	Controller.shopScrollingFrame = Controller.shopPage:WaitForChild("ScrollingFrame")
	Controller.shopPasses = {}
	Controller.serverLuckProductId = -1

	local Scrolling = Controller.shopScrollingFrame
	local GamePasses = Scrolling:WaitForChild("GamePasses")
	local Cash1 = Scrolling:WaitForChild("Cash1")
	local Cash2 = Scrolling:WaitForChild("Cash2")
	BindGamePass(Controller, NewCard(GamePasses:WaitForChild("2xCash")), "DoubleMoney", MonetizationConfig.GamePasses.DoubleMoney)
	BindGamePass(Controller, NewCard(GamePasses:WaitForChild("2xReputation")), "DoubleReputation", MonetizationConfig.GamePasses.DoubleReputation)
	BindGamePass(Controller, NewCard(Scrolling:WaitForChild("VIP")), "VIP", MonetizationConfig.GamePasses.VIP)
	BindGamePass(Controller, NewCard(Scrolling:WaitForChild("StarterPack")), "StarterPack", MonetizationConfig.StarterPack.Id)
	BindProduct(NewCard(Cash1:WaitForChild("Pack1")), MonetizationConfig.CashProducts.Cash1.Id)
	BindProduct(NewCard(Cash1:WaitForChild("Pack2")), MonetizationConfig.CashProducts.Cash2.Id)
	BindProduct(NewCard(Cash2:WaitForChild("Pack3")), MonetizationConfig.CashProducts.Cash3.Id)
	BindProduct(NewCard(Cash2:WaitForChild("Pack4")), MonetizationConfig.CashProducts.Cash4.Id)

	local ServerLuck = Scrolling:WaitForChild("ServerReputationLuck")
	Controller.serverLuckCard = NewCard(ServerLuck)
	Controller.serverLuckFirstText = ServerLuck:WaitForChild("FirstText") :: TextLabel
	Controller.serverLuckMiddleText = ServerLuck:WaitForChild("MiddleText") :: TextLabel
	Controller.serverLuckSecondText = ServerLuck:WaitForChild("SecondText") :: TextLabel
	Controller.serverLuckMiddleDefaultText = Controller.serverLuckMiddleText.Text
	Shared.AnimateButton(Controller.serverLuckCard.Button, function() return false end)
	Core:GetController("GamepadController"):OnActivated(Controller.serverLuckCard.Button, function()
		if Controller.serverLuckProductId > 0 then
			MarketplaceService:PromptProductPurchase(Player, Controller.serverLuckProductId)
		end
	end)

	Shop.ApplyState(Controller, RemoteManager:InvokeServer("MonetizationService", "GetShopState"))
end

function Shop.Start(Controller)
	RemoteManager:OnClientEvent("MonetizationService", "ShopStateUpdated", function(State)
		Shop.ApplyState(Controller, State)
	end)
	RemoteManager:OnClientEvent("MonetizationService", "StarterPackGranted", function()
		local Definition = ObjectConfig.Object[MonetizationConfig.StarterPack.ObjectKey]
		Core:GetController("MessageController"):Show(Definition.Name .. " added to your inventory", RarityConfig[Definition.Rarity].Gradient)
	end)
end

return Shop
