local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Mutationconfig = require(ReplicatedStorage.Shared.Config.Mutation)
local Mutationlabel = require(ReplicatedStorage.Shared.Utils.MutationLabel)
local Rarityconfig = require(ReplicatedStorage.Shared.Config.Rarity)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local Inventory = {}
local UnknownText = "???"
local DisabledColor = Color3.fromRGB(112, 112, 118)

local function Setcleanenabled(Controller, Enabled: boolean)
	Controller.inventoryCleanButton.Active = Enabled
	Controller.inventoryCleanButton.Interactable = Enabled
	Controller.inventoryCleanButton.BackgroundColor3 = if Enabled
		then Controller.inventoryBaseCleanColor
		else DisabledColor
end

local function Formatreputation(Value: number): string
	local Rounded = math.round(Value * 100) / 100
	if math.abs(Rounded - math.round(Rounded)) < 0.005 then
		return tostring(math.round(Rounded))
	end
	return string.format("%.2f", Rounded)
end

function Inventory.ShowDetails(Controller, Item)
	Controller.inventoryDetailsFrame.Visible = true
	Controller.inventoryRainbowDetails = nil
	if not Item then
		Controller.selectedInventoryItemId = nil
		Controller.inventoryNameText.Text = "No item selected"
		Controller.inventoryNameText.TextColor3 = Controller.inventoryBaseNameColor
		Controller.inventoryRarityText.Text = UnknownText
		Controller.inventoryRarityText.TextColor3 = Controller.inventoryBaseRarityColor
		Controller.inventoryMutationText.Text = UnknownText
		Controller.inventoryMutationText.TextColor3 = Controller.inventoryBaseMutationColor
		Controller.inventoryRestorationText.Text = "0%"
		Controller.inventoryReputationText.Text = UnknownText
		Controller.inventoryValueText.Text = UnknownText
		Controller.inventoryIcon.Image = ""
		Controller.inventoryProgressBar.Size = UDim2.fromScale(0, 1)
		Setcleanenabled(Controller, true)
		return
	end

	Controller.selectedInventoryItemId = Item.Id
	local Percent = tonumber(Item.RestorationPercent) or 0
	local Rarity = Rarityconfig[tostring(Item.Rarity or "Common")]
	Mutationlabel.Apply(Controller.inventoryNameText, Item)
	Controller.inventoryRarityText.Text = Rarity.Name
	Controller.inventoryRarityText.TextColor3 = Rarity.Color
	Controller.inventoryRestorationText.Text = string.format("%d%%", Percent)
	Setcleanenabled(Controller, Percent < 100)
	Controller.inventoryProgressBar.Size = UDim2.fromScale(math.clamp(Percent / 100, 0, 1), 1)
	Controller.inventoryIcon.Image = tostring(Item.ImageId or "")

	Controller.inventoryReputationText.Text = Formatreputation(tonumber(Item.Reputation) or 0)
	Controller.inventoryValueText.Text = Shared.FormatCurrency(Item.CurrentValue or 0)

	if not Item.Revealed then
		Controller.inventoryMutationText.Text = UnknownText
		Controller.inventoryMutationText.TextColor3 = Controller.inventoryBaseMutationColor
		return
	end

	local Mutation = Mutationconfig[tostring(Item.Mutation or "Normal")]
	Controller.inventoryMutationText.Text = Mutation.Name
	Controller.inventoryMutationText.TextColor3 = Mutation.Color
	if Item.Mutation == "Rainbow" then
		Controller.inventoryRainbowDetails = { Controller.inventoryMutationText, Controller.inventoryNameText }
	end
end

function Inventory.ApplyItems(Controller, Items)
	local Sorteditems = {}
	for _, Item in ipairs(Items or {}) do
		table.insert(Sorteditems, Item)
	end
	table.sort(Sorteditems, function(Left, Right)
		local Leftpercent = tonumber(Left.RestorationPercent) or 0
		local Rightpercent = tonumber(Right.RestorationPercent) or 0
		local Leftdone = Leftpercent >= 100
		local Rightdone = Rightpercent >= 100
		if Leftdone ~= Rightdone then
			return Rightdone
		end
		if Leftdone then
			local Leftvalue = tonumber(Left.CurrentValue) or 0
			local Rightvalue = tonumber(Right.CurrentValue) or 0
			if Leftvalue ~= Rightvalue then
				return Leftvalue > Rightvalue
			end
		elseif Leftpercent ~= Rightpercent then
			return Leftpercent < Rightpercent
		end
		return (tonumber(Left.Id) or 0) > (tonumber(Right.Id) or 0)
	end)
	Controller.inventoryItems = Sorteditems
	Controller.inventoryRainbowCards = {}

	local Highestid = 0
	for _, Item in ipairs(Controller.inventoryItems) do
		Highestid = math.max(Highestid, tonumber(Item.Id) or 0)
	end
	local Newestitem
	if Controller.inventoryHighestItemId and Highestid > Controller.inventoryHighestItemId then
		for _, Item in ipairs(Controller.inventoryItems) do
			if (tonumber(Item.Id) or 0) == Highestid then
				Newestitem = Item
			end
		end
	end
	Controller.inventoryHighestItemId = Highestid

	local SelectedItem
	for _, Child in ipairs(Controller.inventoryScrollingFrame:GetChildren()) do
		if Child ~= Controller.inventoryTemplate and not Child:IsA("UIGridLayout") then
			Child:Destroy()
		end
	end

	for Order, Item in ipairs(Controller.inventoryItems) do
		local Card = Controller.inventoryTemplate:Clone()
		Card.Name = "Item_" .. tostring(Item.Id or math.random(1, 999999))
		Card.LayoutOrder = Order
		Card.Visible = true
		Card.Parent = Controller.inventoryScrollingFrame
		local RootButton = Card:WaitForChild("Button")
		Shared.AnimateButton(RootButton, function()
			return false
		end)
		RootButton.Activated:Connect(function()
			Inventory.ShowDetails(Controller, Item)
		end)
		local Nametext = RootButton:WaitForChild("NameText")
		Mutationlabel.Apply(Nametext, Item)
		if Item.Mutation == "Rainbow" then
			table.insert(Controller.inventoryRainbowCards, Nametext)
		end
		RootButton:WaitForChild("PriceText").Text = Shared.FormatCurrency(Item.CurrentValue or 0)
		RootButton:WaitForChild("PourcentageText").Text = string.format("%d%%", tonumber(Item.RestorationPercent) or 0)
		RootButton:WaitForChild("Icon").Image = tostring(Item.ImageId or "")
		if Controller.selectedInventoryItemId == Item.Id then
			SelectedItem = Item
		end
	end

	if Newestitem then
		SelectedItem = Newestitem
	elseif not SelectedItem and #Controller.inventoryItems > 0 then
		SelectedItem = Controller.inventoryItems[1]
	end
	Inventory.ShowDetails(Controller, SelectedItem)
	task.defer(function()
		Controller.inventoryScrollingFrame.CanvasSize =
			UDim2.fromOffset(0, Controller.inventoryGridLayout.AbsoluteContentSize.Y)
	end)
end

function Inventory.Init(Controller)
	Controller.inventoryScrollingFrame = Controller.inventoryFrame:WaitForChild("ScrollingFrame")
	Controller.inventoryTemplate = Controller.inventoryScrollingFrame:WaitForChild("Template")
	Controller.inventoryGridLayout = Controller.inventoryScrollingFrame:WaitForChild("UIGridLayout")
	Controller.inventoryGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	Controller.inventoryDetailsFrame = Controller.inventoryFrame:WaitForChild("StatsFrame")
	Controller.inventoryNameText = Controller.inventoryDetailsFrame:WaitForChild("NameText")
	Controller.inventoryRarityText = Controller.inventoryDetailsFrame:WaitForChild("RarityText")
	Controller.inventoryMutationText = Controller.inventoryDetailsFrame:WaitForChild("MutationText")
	Controller.inventoryRestorationText = Controller.inventoryDetailsFrame:WaitForChild("RestorationText")
	Controller.inventoryReputationText = Controller.inventoryDetailsFrame:WaitForChild("ReputationText")
	Controller.inventoryValueText = Controller.inventoryDetailsFrame:WaitForChild("ValueText")
	Controller.inventoryIcon = Controller.inventoryDetailsFrame:WaitForChild("Icon")
	Controller.inventoryProgressBar = Controller.inventoryDetailsFrame:WaitForChild("FrameBar").Bar
	Controller.inventorySellButton = Controller.inventoryDetailsFrame:WaitForChild("SellButton")
	Controller.inventoryCleanButton = Controller.inventoryDetailsFrame:WaitForChild("CleanButton")
	Controller.inventoryBaseNameColor = Controller.inventoryNameText.TextColor3
	Controller.inventoryBaseCleanColor = Controller.inventoryCleanButton.BackgroundColor3
	Controller.inventoryBaseRarityColor = Controller.inventoryRarityText.TextColor3
	Controller.inventoryBaseMutationColor = Controller.inventoryMutationText.TextColor3
	Controller.inventoryItems = {}
	Controller.selectedInventoryItemId = nil
	Controller.inventoryHighestItemId = nil
	Controller.inventoryTemplate.Visible = false
	Shared.AnimateButton(Controller.inventorySellButton, function()
		return false
	end)
	Shared.AnimateButton(Controller.inventoryCleanButton, function()
		return false
	end)
	Inventory.ApplyItems(Controller, RemoteManager:InvokeServer("InventoryService", "GetRestoredItems"))
end

function Inventory.Start(Controller)
	RunService.Heartbeat:Connect(function()
		local Color = Core:GetController("MutationController"):GetColor("Rainbow")
		if not Color then
			return
		end
		for _, Label in ipairs(Controller.inventoryRainbowCards or {}) do
			if Label.Parent then
				Label.TextColor3 = Color
			end
		end
		for _, Label in ipairs(Controller.inventoryRainbowDetails or {}) do
			Label.TextColor3 = Color
		end
	end)

	Controller.inventoryGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		Controller.inventoryScrollingFrame.CanvasSize =
			UDim2.fromOffset(0, Controller.inventoryGridLayout.AbsoluteContentSize.Y)
	end)
	RemoteManager:OnClientEvent("InventoryService", "RestoredItemsUpdated", function(Items)
		Inventory.ApplyItems(Controller, Items)
	end)

	Controller.inventorySellButton.Activated:Connect(function()
		local ItemId = Controller.selectedInventoryItemId
		if not ItemId then
			return
		end
		local Sold = RemoteManager:InvokeServer("InventoryService", "SellRestoredItem", ItemId)
		if not Sold then
			return
		end
		Core:GetController("FeedbackController"):Sale(tostring(Sold.Name or "ITEM"), tonumber(Sold.CurrentValue) or 0)
		Controller.selectedInventoryItemId = nil
	end)

	Controller.inventoryCleanButton.Activated:Connect(function()
		local ItemId = Controller.selectedInventoryItemId
		if not ItemId then
			return
		end
		local Object = RemoteManager:InvokeServer("RestorationService", "BeginItem", ItemId)
		if not Object then
			return
		end
		Controller.selectedInventoryItemId = nil
		Controller:Close()
		task.defer(function()
			Core:GetController("RestorationController"):Enter()
		end)
	end)
end

return Inventory
