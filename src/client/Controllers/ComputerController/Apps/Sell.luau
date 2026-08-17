local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local Sell = {}
local GainColor = Color3.fromRGB(126, 255, 145)
local LossColor = Color3.fromRGB(255, 138, 138)

function Sell.ShowDetails(Controller, Item)
	if Controller.sellDetailsFrame then Controller.sellDetailsFrame.Visible = true end
	if not Item then
		Controller.selectedRestoredItemId = nil
		if Controller.sellDetailsNameText then Controller.sellDetailsNameText.Text = "No item selected" end
		if Controller.sellDetailsBoughtText then Controller.sellDetailsBoughtText.Text = "$0" end
		if Controller.sellDetailsRarityText then Controller.sellDetailsRarityText.Text = "-" end
		if Controller.sellDetailsRestorationText then Controller.sellDetailsRestorationText.Text = "0%" end
		if Controller.sellDetailsValueText then Controller.sellDetailsValueText.Text = "$0" end
		if Controller.sellDetailsProfitText then
			Controller.sellDetailsProfitText.Text = "$0"
			Controller.sellDetailsProfitText.TextColor3 = Controller.sellDetailBaseProfitTextColor
		end
		if Controller.sellDetailsIcon and (Controller.sellDetailsIcon:IsA("ImageLabel") or Controller.sellDetailsIcon:IsA("ImageButton")) then
			Controller.sellDetailsIcon.Image = ""
		end
		if Controller.sellDetailsProgressBar then Controller.sellDetailsProgressBar.Size = UDim2.fromScale(0, 1) end
		if Controller.sellItemButton then
			Controller.sellItemButton.Active = false
			Controller.sellItemButton.AutoButtonColor = false
		end
		if Controller.sellAllButton then
			Controller.sellAllButton.Active = #Controller.restoredItems > 0
			Controller.sellAllButton.AutoButtonColor = #Controller.restoredItems > 0
		end
		return
	end

	Controller.selectedRestoredItemId = Item.Id
	if Controller.sellDetailsNameText then Controller.sellDetailsNameText.Text = tostring(Item.Name or "") end
	if Controller.sellDetailsBoughtText then Controller.sellDetailsBoughtText.Text = Shared.FormatCurrency(Item.PurchasePrice or 0) end
	if Controller.sellDetailsRarityText then Controller.sellDetailsRarityText.Text = tostring(Item.Rarity or "Common") end
	if Controller.sellDetailsRestorationText then Controller.sellDetailsRestorationText.Text = string.format("%d%%", Item.RestorationPercent or 0) end
	if Controller.sellDetailsValueText then Controller.sellDetailsValueText.Text = Shared.FormatCurrency(Item.CurrentValue or 0) end
	if Controller.sellDetailsProfitText then
		local Profit = Item.NetProfit or 0
		Controller.sellDetailsProfitText.Text = Shared.FormatProfit(Profit)
		Controller.sellDetailsProfitText.TextColor3 = if Profit > 0 then GainColor elseif Profit < 0 then LossColor else Controller.sellDetailBaseProfitTextColor
	end
	if Controller.sellDetailsIcon and (Controller.sellDetailsIcon:IsA("ImageLabel") or Controller.sellDetailsIcon:IsA("ImageButton")) then
		Controller.sellDetailsIcon.Image = tostring(Item.ImageId or "")
	end
	if Controller.sellDetailsProgressBar then
		Controller.sellDetailsProgressBar.Size = UDim2.fromScale(math.clamp((Item.RestorationPercent or 0) / 100, 0, 1), 1)
	end
	if Controller.sellItemButton then
		Controller.sellItemButton.Active = true
		Controller.sellItemButton.AutoButtonColor = true
	end
	if Controller.sellAllButton then
		Controller.sellAllButton.Active = #Controller.restoredItems > 0
		Controller.sellAllButton.AutoButtonColor = #Controller.restoredItems > 0
	end
end

function Sell.ApplyItems(Controller, Items)
	Controller.restoredItems = Items or {}
	local SelectedItem
	for _, Child in ipairs(Controller.sellScrollingFrame:GetChildren()) do
		if Child ~= Controller.sellTemplate and not Child:IsA("UIGridLayout") then Child:Destroy() end
	end

	for _, Item in ipairs(Controller.restoredItems) do
		local Card = Controller.sellTemplate:Clone()
		Card.Name = "Item_" .. tostring(Item.Id or math.random(1, 999999))
		Card.Visible = true
		Card.Parent = Controller.sellScrollingFrame
		local RootButton = Card:FindFirstChild("Button")
		if RootButton and RootButton:IsA("GuiButton") then
			Shared.AnimateButton(RootButton, function() return false end)
			RootButton.Activated:Connect(function() Sell.ShowDetails(Controller, Item) end)
		end
		local SellButton = Card:FindFirstChild("SellButton", true)
		if SellButton and SellButton:IsA("GuiButton") then
			Shared.AnimateButton(SellButton, function() return false end)
			SellButton.Activated:Connect(function()
				local Sold = RemoteManager:InvokeServer("InventoryService", "SellRestoredItem", Item.Id)
				if Sold and Controller.selectedRestoredItemId == Item.Id then Controller.selectedRestoredItemId = nil end
			end)
		end
		local ButtonRoot = RootButton or Card
		local NameText = ButtonRoot:FindFirstChild("NameText", true)
		local PriceText = ButtonRoot:FindFirstChild("PriceText", true)
		local Icon = ButtonRoot:FindFirstChild("Icon", true)
		if NameText and (NameText:IsA("TextLabel") or NameText:IsA("TextButton") or NameText:IsA("TextBox")) then NameText.Text = tostring(Item.Name or "") end
		if PriceText and (PriceText:IsA("TextLabel") or PriceText:IsA("TextButton") or PriceText:IsA("TextBox")) then PriceText.Text = Shared.FormatCurrency(Item.CurrentValue or 0) end
		if Icon and (Icon:IsA("ImageLabel") or Icon:IsA("ImageButton")) then Icon.Image = tostring(Item.ImageId or "") end
		if Controller.selectedRestoredItemId == Item.Id then SelectedItem = Item end
	end
	if not SelectedItem and #Controller.restoredItems > 0 then SelectedItem = Controller.restoredItems[1] end
	Sell.ShowDetails(Controller, SelectedItem)
	task.defer(function()
		Controller.sellScrollingFrame.CanvasSize = UDim2.fromOffset(0, Controller.sellGridLayout.AbsoluteContentSize.Y)
	end)
end

function Sell.Init(Controller)
	Controller.sellScrollingFrame = Shared.RequireScrollingFrame(Controller.sellFrame, "ScrollingFrame")
	Controller.sellTemplate = Shared.RequireFrame(Controller.sellScrollingFrame, "Template")
	Controller.sellDetailsFrame = Shared.FindFrame(Controller.sellFrame, "StatsFrame")
	Controller.sellGridLayout = Controller.sellScrollingFrame:FindFirstChildOfClass("UIGridLayout")
	assert(Controller.sellGridLayout, "UIGridLayout introuvable dans SellFrame.ScrollingFrame")
	Controller.sellItemButton = Shared.FindButton(Controller.sellDetailsFrame, "SellButton")
	Controller.sellAllButton = Shared.FindButton(Controller.sellFrame, "SellAllButton")
	Controller.sellDetailsNameText = Shared.FindText(Controller.sellDetailsFrame, "NameText")
	Controller.sellDetailsBoughtText = Shared.FindText(Controller.sellDetailsFrame, "BoughtText")
	Controller.sellDetailsRarityText = Shared.FindText(Controller.sellDetailsFrame, "RarityText")
	Controller.sellDetailsRestorationText = Shared.FindText(Controller.sellDetailsFrame, "RestorationText")
	Controller.sellDetailsValueText = Shared.FindText(Controller.sellDetailsFrame, "ValueText")
	Controller.sellDetailsProfitText = Shared.FindText(Controller.sellDetailsFrame, "ProfitText")
	Controller.sellDetailsIcon = if Controller.sellDetailsFrame then Controller.sellDetailsFrame:FindFirstChild("Icon", true) else nil
	local FrameBar = Shared.FindFrame(Controller.sellDetailsFrame, "FrameBar")
	Controller.sellDetailsProgressBar = if FrameBar then FrameBar:FindFirstChild("Bar", true) else nil
	Controller.sellDetailBaseProfitTextColor = if Controller.sellDetailsProfitText then Controller.sellDetailsProfitText.TextColor3 else Color3.new(1, 1, 1)
	Controller.restoredItems = {}
	Controller.selectedRestoredItemId = nil
	Controller.sellTemplate.Visible = false
	if Controller.sellItemButton then Shared.AnimateButton(Controller.sellItemButton, function() return false end) end
	if Controller.sellAllButton then Shared.AnimateButton(Controller.sellAllButton, function() return false end) end
	Sell.ApplyItems(Controller, RemoteManager:InvokeServer("InventoryService", "GetRestoredItems"))
end

function Sell.Start(Controller)
	Controller.sellGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		Controller.sellScrollingFrame.CanvasSize = UDim2.fromOffset(0, Controller.sellGridLayout.AbsoluteContentSize.Y)
	end)
	RemoteManager:OnClientEvent("InventoryService", "RestoredItemsUpdated", function(Items) Sell.ApplyItems(Controller, Items) end)
	if Controller.sellItemButton then
		Controller.sellItemButton.Activated:Connect(function()
			if not Controller.selectedRestoredItemId then return end
			local Sold = RemoteManager:InvokeServer("InventoryService", "SellRestoredItem", Controller.selectedRestoredItemId)
			if Sold then Controller.selectedRestoredItemId = nil end
		end)
	end
	if Controller.sellAllButton then
		Controller.sellAllButton.Activated:Connect(function()
			RemoteManager:InvokeServer("InventoryService", "SellAllRestoredItems")
			Controller.selectedRestoredItemId = nil
		end)
	end
end

return Sell
