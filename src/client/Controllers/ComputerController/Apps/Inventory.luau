local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Mutationconfig = require(ReplicatedStorage.Shared.Config.Mutation)
local Rarityconfig = require(ReplicatedStorage.Shared.Config.Rarity)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Uigradient = require(ReplicatedStorage.Shared.Utils.UiGradient)
local Shared = require(script.Parent.Shared)

local Inventory = {}
local UnknownText = "???"
local CleanText = "Clean"
local SellText = "Sell"
local DetailsTweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function GetPercent(Item): number
	return math.clamp(tonumber(Item.RestorationPercent) or 0, 0, 100)
end

local function GetReputation(Item): number
	return math.round(math.max(tonumber(Item.Reputation) or 0, 0) * 100) / 100
end

local function FillItemStats(Frame: GuiObject, Item)
	local Icon = Frame:WaitForChild("Icon") :: ImageLabel
	local CashText = Frame:WaitForChild("CashText") :: TextLabel
	local ReputationText = Frame:WaitForChild("ReputationText") :: TextLabel
	Icon.Image = tostring(Item.ImageId or "")
	CashText.Text = Shared.FormatCurrency(Item.CurrentValue or 0)
	ReputationText.Text = tostring(GetReputation(Item))
end

local function FillItemProgress(Frame: GuiObject, Item)
	local FrameBar = Frame:WaitForChild("FrameBar")
	local Percent = GetPercent(Item)
	FrameBar:WaitForChild("PourcentageText").Text = string.format("%d%%", Percent)
	FrameBar:WaitForChild("Bar").Size = UDim2.fromScale(Percent / 100, 1)
end

local function SetButtonEnabled(Button: GuiButton, Enabled: boolean)
	if Button.Active == Enabled then return end
	Button.Active = Enabled
	Button.Interactable = Enabled
	if not Enabled then Shared.ApplyActiveScale(Button, false) end
end

function Inventory.RefreshControls(Controller)
	local CardsEnabled = not Controller.inventoryInfoFrame.Visible
	for _, Card in ipairs(Controller.inventoryCards) do
		SetButtonEnabled(Card.Button, CardsEnabled)
		SetButtonEnabled(Card.ButtonOpen, CardsEnabled)
		SetButtonEnabled(Card.InfoButton, CardsEnabled)
		SetButtonEnabled(Card.ActionButton, CardsEnabled)
	end
	SetButtonEnabled(Controller.inventorySellButton, not Controller.sellLocked)
end

function Inventory.GetOpenCardBottom(Controller): number
	local ButtonOpen = Controller.inventoryOpenCard.ButtonOpen
	local Scrolling = Controller.inventoryScrollingFrame
	return ButtonOpen.AbsolutePosition.Y + ButtonOpen.AbsoluteSize.Y - Scrolling.AbsolutePosition.Y + Scrolling.CanvasPosition.Y
end

function Inventory.UpdateCanvas(Controller)
	local Bottom = Controller.inventoryGridLayout.AbsoluteContentSize.Y
	if Controller.inventoryOpenCard then
		Bottom = math.max(Bottom, Inventory.GetOpenCardBottom(Controller))
	end
	Controller.inventoryScrollingFrame.CanvasSize = UDim2.fromOffset(0, Bottom)
end

function Inventory.ScrollToOpenCard(Controller)
	local Scrolling = Controller.inventoryScrollingFrame
	local Target = Inventory.GetOpenCardBottom(Controller) - Scrolling.AbsoluteWindowSize.Y
	if Target > Scrolling.CanvasPosition.Y then
		TweenService:Create(Scrolling, DetailsTweenInfo, { CanvasPosition = Vector2.new(0, Target) }):Play()
	end
end

function Inventory.SetCardOpen(Controller, Card, Open: boolean)
	local OpenCard = Controller.inventoryOpenCard
	if OpenCard and OpenCard ~= Card then
		OpenCard.Button.Visible = true
		OpenCard.ButtonOpen.Visible = false
		OpenCard.Frame.ZIndex = 1
	end
	Controller.inventoryOpenCard = if Open then Card else nil
	Card.Button.Visible = not Open
	Card.ButtonOpen.Visible = Open
	Card.Frame.ZIndex = if Open then 10 else 1
	Inventory.UpdateCanvas(Controller)
	if Open then Inventory.ScrollToOpenCard(Controller) end
end

function Inventory.ShowItemInfo(Controller, Item, Animate: boolean?)
	Controller.inventoryInfoItemId = Item.Id
	local Rarity = Rarityconfig[tostring(Item.Rarity or "Common")]
	local Mutation = if Item.Revealed then Mutationconfig[tostring(Item.Mutation or "Normal")] else nil
	local HasMutation = Mutation ~= nil and Mutation ~= Mutationconfig.Normal
	FillItemStats(Controller.inventoryInfoCard, Item)
	FillItemProgress(Controller.inventoryInfoCard, Item)
	Controller.inventoryInfoNameText.Text = tostring(Item.Name or "")
	Controller.inventoryInfoRarityText.Text = Rarity.Name
	Controller.inventoryInfoRarityGradient.Color = Rarity.Gradient
	Controller.inventoryInfoMutationText.Text = if Mutation then Mutation.Name else UnknownText
	Controller.inventoryInfoMutationGradient.Color = if HasMutation
		then Mutation.Gradient
		else Controller.inventoryInfoMutationBaseGradient
	Controller.inventoryInfoMutationFrameGradient.Color = if HasMutation
		then Mutation.BackgroundGradient
		else Controller.inventoryInfoMutationFrameBaseGradient
	Controller.inventoryInfoReputationText.Text = tostring(GetReputation(Item))
	Controller.inventoryRainbowGradients = if HasMutation and Item.Mutation == "Rainbow"
		then { Controller.inventoryInfoMutationGradient, Controller.inventoryInfoMutationFrameGradient }
		else nil
	Controller.inventoryBlackFrame.Visible = true
	Controller.inventoryInfoFrame.Visible = true
	if Animate then
		Controller.inventoryInfoScale.Scale = 0.96
		TweenService:Create(Controller.inventoryInfoScale, DetailsTweenInfo, { Scale = 1 }):Play()
	end
	Inventory.RefreshControls(Controller)
end

function Inventory.CloseItemInfo(Controller)
	Controller.inventoryInfoItemId = nil
	Controller.inventoryRainbowGradients = nil
	Controller.inventoryInfoFrame.Visible = false
	Controller.inventoryBlackFrame.Visible = false
	Controller.inventoryInfoScale.Scale = 1
	Inventory.RefreshControls(Controller)
end

function Inventory.Clean(Controller, ItemId: number)
	local Object = RemoteManager:InvokeServer("RestorationService", "BeginItem", ItemId)
	if not Object then
		return
	end
	Controller:Close()
	task.defer(function()
		Core:GetController("RestorationController"):Enter()
	end)
end

function Inventory.Sell(Controller, ItemId: number)
	local Sold = RemoteManager:InvokeServer("InventoryService", "SellRestoredItem", ItemId)
	if not Sold then
		return
	end
	Core:GetController("FeedbackController"):Sale(tostring(Sold.Name or "Item"), tonumber(Sold.CurrentValue) or 0)
end

function Inventory.ApplyItems(Controller, Items)
	local SortedItems = {}
	for _, Item in ipairs(Items) do
		table.insert(SortedItems, Item)
	end
	table.sort(SortedItems, function(Left, Right)
		local LeftPercent = GetPercent(Left)
		local RightPercent = GetPercent(Right)
		local LeftDone = LeftPercent >= 100
		local RightDone = RightPercent >= 100
		if LeftDone ~= RightDone then
			return RightDone
		end
		if LeftDone then
			local LeftValue = tonumber(Left.CurrentValue) or 0
			local RightValue = tonumber(Right.CurrentValue) or 0
			if LeftValue ~= RightValue then
				return LeftValue > RightValue
			end
		elseif LeftPercent ~= RightPercent then
			return LeftPercent < RightPercent
		end
		return (tonumber(Left.Id) or 0) > (tonumber(Right.Id) or 0)
	end)
	Controller.inventoryItems = SortedItems
	if Controller.activePage ~= "Inventory" then
		Controller.inventoryDirty = true
		return
	end
	Inventory.Render(Controller)
end

local function CreateCard(Controller, Item, IsOpen: boolean)
	local Done = GetPercent(Item) >= 100
	local Frame = Controller.inventoryTemplate:Clone()
	Frame.Name = "Item_" .. tostring(Item.Id)
	Frame.Visible = true
	Frame.ZIndex = if IsOpen then 10 else 1
	local Button = Frame:WaitForChild("Button") :: GuiButton
	local ButtonOpen = Frame:WaitForChild("ButtonOpen") :: GuiButton
	local InfoButton = ButtonOpen:WaitForChild("InfoButton") :: GuiButton
	local ActionButton = ButtonOpen:WaitForChild("Button") :: GuiButton
	Button.Visible = not IsOpen
	ButtonOpen.Visible = IsOpen
	ActionButton:WaitForChild("Text").Text = if Done then SellText else CleanText
	if Done then
		local ActionGradient = ActionButton:WaitForChild("UIGradient") :: UIGradient
		ActionGradient.Color = Controller.inventorySellGradient.Color
		ActionGradient.Transparency = Controller.inventorySellGradient.Transparency
		ActionGradient.Rotation = Controller.inventorySellGradient.Rotation
		ActionGradient.Offset = Controller.inventorySellGradient.Offset
	end
	local Card = {
		Frame = Frame,
		Button = Button,
		ButtonOpen = ButtonOpen,
		InfoButton = InfoButton,
		ActionButton = ActionButton,
		Item = Item,
		Done = Done,
	}
	local Enabled = not Controller.inventoryInfoFrame.Visible
	for _, Target in ipairs({ Button, ButtonOpen, InfoButton, ActionButton }) do
		Target.Active = Enabled
		Target.Interactable = Enabled
		Shared.AnimateButton(Target, function()
			return not Target.Active
		end)
	end
	local Gamepad = Core:GetController("GamepadController")
	Gamepad:OnActivated(Button, function()
		Inventory.SetCardOpen(Controller, Card, true)
	end)
	Gamepad:OnActivated(ButtonOpen, function()
		Inventory.SetCardOpen(Controller, Card, false)
	end)
	Gamepad:OnActivated(InfoButton, function()
		Inventory.ShowItemInfo(Controller, Card.Item, true)
	end)
	Gamepad:OnActivated(ActionButton, function()
		if not Done then
			Inventory.Clean(Controller, Card.Item.Id)
		elseif not Controller.sellLocked then
			Inventory.Sell(Controller, Card.Item.Id)
		end
	end)
	return Card
end

function Inventory.Render(Controller)
	Controller.inventoryDirty = false
	local ItemsById = {}
	for _, Item in ipairs(Controller.inventoryItems) do
		ItemsById[Item.Id] = Item
	end
	local OpenItemId = if Controller.inventoryOpenCard then Controller.inventoryOpenCard.Item.Id else nil
	for Id, Card in pairs(Controller.inventoryCardsById) do
		local Item = ItemsById[Id]
		if not Item or (GetPercent(Item) >= 100) ~= Card.Done then
			Card.Frame:Destroy()
			Controller.inventoryCardsById[Id] = nil
		end
	end
	table.clear(Controller.inventoryCards)
	Controller.inventoryOpenCard = nil

	local InfoItem
	for Order, Item in ipairs(Controller.inventoryItems) do
		local Card = Controller.inventoryCardsById[Item.Id]
		local IsNew = Card == nil
		if IsNew then
			Card = CreateCard(Controller, Item, OpenItemId == Item.Id)
			Controller.inventoryCardsById[Item.Id] = Card
		end
		Card.Item = Item
		Card.Frame.LayoutOrder = Order
		FillItemStats(Card.Button, Item)
		FillItemProgress(Card.Button, Item)
		FillItemStats(Card.ButtonOpen, Item)
		Card.ButtonOpen:WaitForChild("ObjectNameText").Text = tostring(Item.Name or "")
		if IsNew then
			Card.Frame.Parent = Controller.inventoryScrollingFrame
		end
		table.insert(Controller.inventoryCards, Card)
		if OpenItemId == Item.Id then
			Controller.inventoryOpenCard = Card
		end
		if Controller.inventoryInfoItemId == Item.Id then
			InfoItem = Item
		end
	end

	if Controller.inventoryInfoItemId then
		if InfoItem then
			Inventory.ShowItemInfo(Controller, InfoItem, false)
		else
			Inventory.CloseItemInfo(Controller)
		end
	end
	Inventory.RefreshControls(Controller)
	task.defer(function()
		Inventory.UpdateCanvas(Controller)
	end)
end

function Inventory.Init(Controller)
	local Page = Controller.inventoryPage
	local ScrollingFrame = Page:WaitForChild("ScrollingFrame")
	local InfoFrame = Page:WaitForChild("InfoFrame")
	local StatsFrame = InfoFrame:WaitForChild("StatsFrame")
	local MutationFrame = StatsFrame:WaitForChild("MutationFrame")
	Controller.inventoryScrollingFrame = ScrollingFrame
	Controller.inventoryGridLayout = ScrollingFrame:WaitForChild("UIGridLayout")
	Controller.inventoryTemplate = ScrollingFrame:WaitForChild("Template")
	Controller.inventoryBlackFrame = Page:WaitForChild("BlackFrame")
	Controller.inventoryInfoFrame = InfoFrame
	Controller.inventoryInfoScale = Shared.EnsureScale(InfoFrame)
	Controller.inventoryInfoCloseButton = InfoFrame:WaitForChild("CloseButton")
	Controller.inventorySellButton = InfoFrame:WaitForChild("SellButton")
	Controller.inventorySellGradient = Controller.inventorySellButton:WaitForChild("UIGradient")
	Controller.inventoryInfoCard = InfoFrame:WaitForChild("Button")
	Controller.inventoryInfoNameText = InfoFrame:WaitForChild("ObjectNameText")
	Controller.inventoryInfoRarityText = InfoFrame:WaitForChild("RarityText")
	Controller.inventoryInfoRarityGradient = Controller.inventoryInfoRarityText:WaitForChild("UIGradient")
	Controller.inventoryInfoMutationText = MutationFrame:WaitForChild("MutationText")
	Controller.inventoryInfoMutationGradient = Uigradient.Ensure(Controller.inventoryInfoMutationText)
	Controller.inventoryInfoMutationFrameGradient = Uigradient.Ensure(MutationFrame)
	Controller.inventoryInfoMutationBaseGradient = Controller.inventoryInfoMutationGradient.Color
	Controller.inventoryInfoMutationFrameBaseGradient = Controller.inventoryInfoMutationFrameGradient.Color
	Controller.inventoryInfoReputationText = StatsFrame:WaitForChild("ReputationFrame"):WaitForChild("ReputationText")
	Controller.inventoryItems = {}
	Controller.inventoryCards = {}
	Controller.inventoryCardsById = {}
	Controller.inventoryDirty = false
	Controller.inventoryOpenCard = nil
	Controller.inventoryInfoItemId = nil
	Controller.inventoryRainbowGradients = nil
	Controller.inventoryGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	Controller.inventoryTemplate.Visible = false
	Controller.inventoryInfoFrame.Visible = false
	Controller.inventoryBlackFrame.Visible = false
	Shared.AnimateButton(Controller.inventorySellButton, function()
		return not Controller.inventorySellButton.Active
	end)
	Shared.AnimateButton(Controller.inventoryInfoCloseButton, function()
		return false
	end)
	Inventory.ApplyItems(Controller, RemoteManager:InvokeServer("InventoryService", "GetRestoredItems"))
end

function Inventory.Start(Controller)
	local Gamepad = Core:GetController("GamepadController")
	Gamepad:RegisterMenu({
		Priority = 12,
		IsOpen = function()
			return Controller:IsOpen()
				and Controller.activePage == "Inventory"
				and Controller.inventoryInfoFrame.Visible
		end,
		Close = function()
			Inventory.CloseItemInfo(Controller)
		end,
	})
	RunService.Heartbeat:Connect(function()
		local Sequence = Core:GetController("MutationController"):GetGradient("Rainbow")
		for _, Gradient in ipairs(Controller.inventoryRainbowGradients or {}) do
			Gradient.Color = Sequence
		end
	end)
	Controller.inventoryGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		Inventory.UpdateCanvas(Controller)
	end)
	RemoteManager:OnClientEvent("InventoryService", "RestoredItemsUpdated", function(Items)
		Inventory.ApplyItems(Controller, Items)
	end)
	Gamepad:OnActivated(Controller.inventoryInfoCloseButton, function()
		Inventory.CloseItemInfo(Controller)
	end)
	Gamepad:OnActivated(Controller.inventorySellButton, function()
		Inventory.Sell(Controller, Controller.inventoryInfoItemId)
	end)
end

return Inventory
