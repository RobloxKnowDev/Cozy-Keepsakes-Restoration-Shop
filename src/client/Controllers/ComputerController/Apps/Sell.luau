local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Rarityconfig = require(ReplicatedStorage.Shared.Config.Rarity)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local Sell = {}
local GainColor = Color3.fromRGB(126, 255, 145)
local LossColor = Color3.fromRGB(255, 138, 138)

local function Formatreputation(Value: number): string
	local Rounded = math.round(Value * 100) / 100
	if math.abs(Rounded - math.round(Rounded)) < 0.005 then return tostring(math.round(Rounded)) end
	return string.format("%.2f", Rounded)
end

function Sell.ShowDetails(Controller, Item)
	Controller.sellDetailsFrame.Visible = true
	if not Item then
		Controller.selectedRestoredItemId = nil
		Controller.sellDetailsNameText.Text = "No item selected"
		Controller.sellDetailsBoughtText.Text = "$0"
		Controller.sellDetailsRarityText.Text = "-"
		Controller.sellDetailsRarityText.TextColor3 = Color3.fromRGB(255, 255, 255)
		Controller.sellDetailsRestorationText.Text = "0%"
		Controller.sellDetailsReputationText.Text = "0"
		Controller.sellDetailsValueText.Text = "$0"
		Controller.sellDetailsProfitText.Text = "$0"
		Controller.sellDetailsProfitText.TextColor3 = Controller.sellDetailBaseProfitTextColor
		Controller.sellDetailsIcon.Image = ""
		Controller.sellDetailsProgressBar.Size = UDim2.fromScale(0, 1)
		Controller.sellAllButton.Active = #Controller.restoredItems > 0
		Controller.sellAllButton.AutoButtonColor = #Controller.restoredItems > 0
		return
	end

	Controller.selectedRestoredItemId = Item.Id
	local Profit = Item.NetProfit or 0
	local Rarity = Rarityconfig[tostring(Item.Rarity or "Common")]
	Controller.sellDetailsNameText.Text = tostring(Item.Name or "")
	Controller.sellDetailsBoughtText.Text = Shared.FormatCurrency(Item.PurchasePrice or 0)
	Controller.sellDetailsRarityText.Text = Rarity.Name
	Controller.sellDetailsRarityText.TextColor3 = Rarity.Color
	Controller.sellDetailsRestorationText.Text = string.format("%d%%", Item.RestorationPercent or 0)
	Controller.sellDetailsReputationText.Text = Formatreputation(tonumber(Item.Reputation) or 0)
	Controller.sellDetailsValueText.Text = Shared.FormatCurrency(Item.CurrentValue or 0)
	Controller.sellDetailsProfitText.Text = Shared.FormatProfit(Profit)
	Controller.sellDetailsProfitText.TextColor3 = if Profit > 0 then GainColor elseif Profit < 0 then LossColor else Controller.sellDetailBaseProfitTextColor
	Controller.sellDetailsIcon.Image = tostring(Item.ImageId or "")
	Controller.sellDetailsProgressBar.Size = UDim2.fromScale(math.clamp((Item.RestorationPercent or 0) / 100, 0, 1), 1)
	Controller.sellAllButton.Active = #Controller.restoredItems > 0
	Controller.sellAllButton.AutoButtonColor = #Controller.restoredItems > 0
end

function Sell.ApplyItems(Controller, Items)
	local Sorteditems = {}
	for _, Item in ipairs(Items or {}) do
		table.insert(Sorteditems, Item)
	end
	table.sort(Sorteditems, function(Left, Right)
		local Leftvalue = tonumber(Left.CurrentValue) or 0
		local Rightvalue = tonumber(Right.CurrentValue) or 0
		if Leftvalue ~= Rightvalue then
			return Leftvalue > Rightvalue
		end
		return (tonumber(Left.Id) or 0) > (tonumber(Right.Id) or 0)
	end)
	Controller.restoredItems = Sorteditems
	local SelectedItem
	for _, Child in ipairs(Controller.sellScrollingFrame:GetChildren()) do
		if Child ~= Controller.sellTemplate and not Child:IsA("UIGridLayout") then Child:Destroy() end
	end

	for Order, Item in ipairs(Controller.restoredItems) do
		local Card = Controller.sellTemplate:Clone()
		Card.Name = "Item_" .. tostring(Item.Id or math.random(1, 999999))
		Card.LayoutOrder = Order
		Card.Visible = true
		Card.Parent = Controller.sellScrollingFrame
		local RootButton = Card:WaitForChild("Button")
		local SellButton = RootButton:WaitForChild("SellButton")
		Shared.AnimateButton(RootButton, function() return false end)
		Shared.AnimateButton(SellButton, function() return false end)
		RootButton.Activated:Connect(function() Sell.ShowDetails(Controller, Item) end)
		SellButton.Activated:Connect(function()
			local Sold = RemoteManager:InvokeServer("InventoryService", "SellRestoredItem", Item.Id)
			if Sold then
				Core:GetController("FeedbackController"):Sale(tostring(Sold.Name or "ITEM"), tonumber(Sold.CurrentValue) or 0)
				if Controller.selectedRestoredItemId == Item.Id then Controller.selectedRestoredItemId = nil end
			end
		end)
		RootButton:WaitForChild("NameText").Text = tostring(Item.Name or "")
		RootButton:WaitForChild("PriceText").Text = Shared.FormatCurrency(Item.CurrentValue or 0)
		RootButton:WaitForChild("Icon").Image = tostring(Item.ImageId or "")
		if Controller.selectedRestoredItemId == Item.Id then SelectedItem = Item end
	end
	if not SelectedItem and #Controller.restoredItems > 0 then SelectedItem = Controller.restoredItems[1] end
	Sell.ShowDetails(Controller, SelectedItem)
	task.defer(function()
		Controller.sellScrollingFrame.CanvasSize = UDim2.fromOffset(0, Controller.sellGridLayout.AbsoluteContentSize.Y)
	end)
end

function Sell.Init(Controller)
	Controller.sellScrollingFrame = Controller.sellFrame:WaitForChild("ScrollingFrame")
	Controller.sellTemplate = Controller.sellScrollingFrame:WaitForChild("Template")
	Controller.sellDetailsFrame = Controller.sellFrame:WaitForChild("StatsFrame")
	Controller.sellGridLayout = Controller.sellScrollingFrame:WaitForChild("UIGridLayout")
	Controller.sellGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	Controller.sellAllButton = Controller.sellFrame:WaitForChild("SellAllButton")
	Controller.sellDetailsNameText = Controller.sellDetailsFrame:WaitForChild("NameText")
	Controller.sellDetailsBoughtText = Controller.sellDetailsFrame:WaitForChild("BoughtText")
	Controller.sellDetailsRarityText = Controller.sellDetailsFrame:WaitForChild("RarityText")
	Controller.sellDetailsRestorationText = Controller.sellDetailsFrame:WaitForChild("RestorationText")
	Controller.sellDetailsReputationText = Controller.sellDetailsFrame:WaitForChild("ReputationText")
	Controller.sellDetailsValueText = Controller.sellDetailsFrame:WaitForChild("ValueText")
	Controller.sellDetailsProfitText = Controller.sellDetailsFrame:WaitForChild("ProfitText")
	Controller.sellDetailsIcon = Controller.sellDetailsFrame:WaitForChild("Icon")
	Controller.sellDetailsProgressBar = Controller.sellDetailsFrame:WaitForChild("FrameBar").Bar
	Controller.sellDetailBaseProfitTextColor = Controller.sellDetailsProfitText.TextColor3
	Controller.restoredItems = {}
	Controller.selectedRestoredItemId = nil
	Controller.sellTemplate.Visible = false
	Shared.AnimateButton(Controller.sellAllButton, function() return false end)
	Sell.ApplyItems(Controller, RemoteManager:InvokeServer("InventoryService", "GetRestoredItems"))
end

function Sell.Start(Controller)
	Controller.sellGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		Controller.sellScrollingFrame.CanvasSize = UDim2.fromOffset(0, Controller.sellGridLayout.AbsoluteContentSize.Y)
	end)
	RemoteManager:OnClientEvent("InventoryService", "RestoredItemsUpdated", function(Items) Sell.ApplyItems(Controller, Items) end)
	Controller.sellAllButton.Activated:Connect(function()
		local Result = RemoteManager:InvokeServer("InventoryService", "SellAllRestoredItems")
		if Result and Result.Count > 0 then
			Core:GetController("FeedbackController"):Sale("ITEMS", tonumber(Result.TotalValue) or 0, Result.Count)
			Controller.selectedRestoredItemId = nil
		end
	end)
end

return Sell
