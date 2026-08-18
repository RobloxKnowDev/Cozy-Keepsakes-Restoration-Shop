local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.Monetization)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local Shop = {}
local Player = Players.LocalPlayer
local RobuxIcon = ""

local function SetEnabled(Button: GuiButton, Enabled: boolean)
	Button.Active = true
	Button.Interactable = true
	Button.AutoButtonColor = Enabled
	Button:SetAttribute("CanPurchase", Enabled)
end

local function SetPrice(Button: GuiButton, Text: string)
	Button:WaitForChild("PriceText").Text = Text
end

local function LoadPrice(Button: GuiButton, Id: number, InfoType: Enum.InfoType)
	SetPrice(Button, "...")
	task.spawn(function()
		local Info = MarketplaceService:GetProductInfo(Id, InfoType)
		local Price = Info.PriceInRobux
		SetPrice(Button, if Price then string.format("%s%d", RobuxIcon, Price) else "N/A")
	end)
end

local function BindGamePass(Button: GuiButton, Id: number, PassName: string)
	SetEnabled(Button, true)
	Shared.AnimateButton(Button, function() return Button:GetAttribute("CanPurchase") ~= true end)
	LoadPrice(Button, Id, Enum.InfoType.GamePass)
	Button.Activated:Connect(function()
		if RunService:IsStudio() then
			RemoteManager:InvokeServer("MonetizationService", "TestGamePass", PassName)
			return
		end
		if not Button:GetAttribute("CanPurchase") then return end
		MarketplaceService:PromptGamePassPurchase(Player, Id)
	end)
end

local function BindProduct(Button: GuiButton, Id: number)
	SetEnabled(Button, true)
	Shared.AnimateButton(Button, function() return false end)
	LoadPrice(Button, Id, Enum.InfoType.Product)
	Button.Activated:Connect(function()
		if not Button:GetAttribute("CanPurchase") then return end
		MarketplaceService:PromptProductPurchase(Player, Id)
	end)
end

local function FormatTime(Seconds: number): string
	local Total = math.max(math.ceil(Seconds), 0)
	return string.format("%d:%02d", math.floor(Total / 60), Total % 60)
end

function Shop.ApplyState(Controller, State)
	Controller.shopState = State
	local BoostController = Core:GetController("BoostController")
	BoostController:SetBoost("StarterReputation", Controller.personalReputationBoostIcon, State.PersonalReputationBoostEndsAt, 1)
	BoostController:SetBoost("ServerReputationLuck", Controller.serverReputationBoostIcon, State.ServerLuckEndsAt, 2)

	if State.OwnsVIP then
		SetPrice(Controller.vipButton, "OWNED")
		SetEnabled(Controller.vipButton, false)
	end

	if State.OwnsDoubleMoney then
		SetPrice(Controller.doubleMoneyButton, "OWNED")
		SetEnabled(Controller.doubleMoneyButton, false)
	end

	if State.OwnsStarterPack then
		SetPrice(Controller.starterPackButton, "OWNED")
		SetEnabled(Controller.starterPackButton, false)
	end

	Controller.currentLuckText.Text = tostring(State.ServerLuckMultiplier) .. "x"
	Controller.nextLuckText.Text = if State.ServerLuckNextMultiplier then tostring(State.ServerLuckNextMultiplier) .. "x" else "MAX"
	Controller.minutesText.Text = FormatTime(State.ServerLuckEndsAt - workspace:GetServerTimeNow())
	Controller.minutesText.Visible = true
	local IsMax = State.ServerLuckNextMultiplier == nil
	Controller.currentLuckText.Visible = not IsMax
	Controller.nextLuckText.Visible = not IsMax
	Controller.luckArrowText.Text = if IsMax then "MAX" else Controller.luckArrowDefaultText
	Controller.luckArrowText.TextColor3 = if IsMax then Controller.nextLuckColor else Controller.luckArrowDefaultColor
	Controller.luckArrowScale.Scale = if IsMax then 2 else 1
	Controller.serverLuckProductId = State.ServerLuckNextProductId

	if Controller.serverLuckProductId > 0 then
		SetEnabled(Controller.serverLuckButton, true)
		LoadPrice(Controller.serverLuckButton, Controller.serverLuckProductId, Enum.InfoType.Product)
	else
		SetPrice(Controller.serverLuckButton, "MAX")
		SetEnabled(Controller.serverLuckButton, false)
	end
end

function Shop.Init(Controller)
	Controller.shopScrollingFrame = Controller.shopFrame:WaitForChild("ScrollingFrame")
	Controller.shopGridLayout = Controller.shopScrollingFrame:WaitForChild("UIGridLayout")

	local GamePasses = Controller.shopScrollingFrame:WaitForChild("GamePasses"):WaitForChild("Button")
	local Money = Controller.shopScrollingFrame:WaitForChild("Money"):WaitForChild("Button")
	local Money2 = Controller.shopScrollingFrame:WaitForChild("Money2"):WaitForChild("Button")
	local ServerLuck = Controller.shopScrollingFrame:WaitForChild("ServerReputationLuck"):WaitForChild("Button")
	local StarterPack = Controller.shopScrollingFrame:WaitForChild("StarterPack"):WaitForChild("Button")

	GamePasses.AutoButtonColor = false
	Money.AutoButtonColor = false
	Money2.AutoButtonColor = false
	ServerLuck.AutoButtonColor = false
	StarterPack.AutoButtonColor = false
	GamePasses.Interactable = true
	Money.Interactable = true
	Money2.Interactable = true
	ServerLuck.Interactable = true
	StarterPack.Interactable = true
	GamePasses.Active = true
	Money.Active = true
	Money2.Active = true
	ServerLuck.Active = true
	StarterPack.Active = true

	Controller.doubleMoneyButton = GamePasses:WaitForChild("Cash"):WaitForChild("RobuxButton")
	Controller.vipButton = GamePasses:WaitForChild("Vip"):WaitForChild("RobuxButton")
	Controller.cash1Button = Money:WaitForChild("Cash1"):WaitForChild("RobuxButton")
	Controller.cash2Button = Money:WaitForChild("Cash2"):WaitForChild("RobuxButton")
	Controller.cash3Button = Money:WaitForChild("Cash3"):WaitForChild("RobuxButton")
	Controller.cash4Button = Money2:WaitForChild("Cash4"):WaitForChild("RobuxButton")
	Controller.serverLuckButton = ServerLuck:WaitForChild("RobuxButton")
	Controller.starterPackButton = StarterPack:WaitForChild("RobuxButton")
	Controller.currentLuckText = ServerLuck:WaitForChild("CurrentLuckText")
	Controller.nextLuckText = ServerLuck:WaitForChild("NextLuckText")
	Controller.minutesText = ServerLuck:WaitForChild("MinutesText")
	Controller.luckArrowText = ServerLuck:WaitForChild(">Label")
	Controller.luckArrowScale = Shared.EnsureScale(Controller.luckArrowText)
	Controller.luckArrowDefaultText = Controller.luckArrowText.Text
	Controller.luckArrowDefaultColor = Controller.luckArrowText.TextColor3
	Controller.nextLuckColor = Controller.nextLuckText.TextColor3
	Controller.personalReputationBoostIcon = StarterPack:WaitForChild("Reputation"):WaitForChild("Icon").Image
	Controller.serverReputationBoostIcon = ServerLuck:WaitForChild("Icon").Image
	for _, Button in ipairs({
		Controller.doubleMoneyButton,
		Controller.vipButton,
		Controller.cash1Button,
		Controller.cash2Button,
		Controller.cash3Button,
		Controller.cash4Button,
		Controller.serverLuckButton,
		Controller.starterPackButton,
	}) do
		Button.ZIndex = 10
		Button:WaitForChild("PriceText").ZIndex = 11
	end
	BindGamePass(Controller.doubleMoneyButton, MonetizationConfig.GamePasses.DoubleMoney, "DoubleMoney")
	BindGamePass(Controller.vipButton, MonetizationConfig.GamePasses.VIP, "VIP")
	BindProduct(Controller.cash1Button, MonetizationConfig.CashProducts.Cash1.Id)
	BindProduct(Controller.cash2Button, MonetizationConfig.CashProducts.Cash2.Id)
	BindProduct(Controller.cash3Button, MonetizationConfig.CashProducts.Cash3.Id)
	BindProduct(Controller.cash4Button, MonetizationConfig.CashProducts.Cash4.Id)
	BindGamePass(Controller.starterPackButton, MonetizationConfig.StarterPack.Id, "StarterPack")

	Shared.AnimateButton(Controller.serverLuckButton, function()
		return Controller.serverLuckButton:GetAttribute("CanPurchase") ~= true
	end)
	Controller.serverLuckButton.Activated:Connect(function()
		if not Controller.serverLuckButton:GetAttribute("CanPurchase") then return end
		MarketplaceService:PromptProductPurchase(Player, Controller.serverLuckProductId)
	end)

	Shop.ApplyState(Controller, RemoteManager:InvokeServer("MonetizationService", "GetShopState"))
end

function Shop.Start(Controller)
	Controller.shopGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		Controller.shopScrollingFrame.CanvasSize = UDim2.fromOffset(0, Controller.shopGridLayout.AbsoluteContentSize.Y)
	end)

	RemoteManager:OnClientEvent("MonetizationService", "ShopStateUpdated", function(State)
		Shop.ApplyState(Controller, State)
	end)
	RemoteManager:OnClientEvent("MonetizationService", "StarterPackGranted", function()
		Controller:Close()
		Core:GetController("RestorationController"):Enter()
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			Controller.minutesText.Text = FormatTime(Controller.shopState.ServerLuckEndsAt - workspace:GetServerTimeNow())
		end
	end)
end

return Shop
