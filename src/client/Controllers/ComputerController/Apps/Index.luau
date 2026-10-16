local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Indexrewards = require(ReplicatedStorage.Shared.Config.IndexRewards)
local Mutationconfig = require(ReplicatedStorage.Shared.Config.Mutation)
local Rarityconfig = require(ReplicatedStorage.Shared.Config.Rarity)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)
local Uigradient = require(ReplicatedStorage.Shared.Utils.UiGradient)
local Shared = require(script.Parent.Shared)

local Index = {}
local Rarityrank = {}
for Rank, Rarity in ipairs(Rarityconfig.Order) do
	Rarityrank[Rarity] = Rank
end
local GainGradient = Rarityconfig.Common.Gradient
local UnlockedIconColor = Color3.fromRGB(255, 255, 255)
local RequiredPercent = math.round(Indexrewards.Ratio * 100)

function Index.ApplyBonus(Counts: { [string]: number }, Required: number)
	local Pages = 0
	for _, Mutation in ipairs(Mutationconfig.Order) do
		if Counts[Mutation] >= Required then
			Pages += 1
		end
	end
	local BoostController = Core:GetController("BoostController")
	if Pages == 0 then
		BoostController:RemoveBoost("IndexSellBonus")
		return
	end
	BoostController:SetPermanentBoost(
		"IndexSellBonus",
		0,
		string.format("+%g%%", Pages * Indexrewards.SellPercent),
		"+{1}% on all sales per index at {2}% ({3}/{4})",
		string.format("%g", Indexrewards.SellPercent),
		RequiredPercent,
		Pages,
		#Mutationconfig.Order
	)
end

function Index.ApplyReward(Controller, Page: string, Count: number, Total: number, Required: number)
	local Percent = string.format("%g", Indexrewards.SellPercent)
	Translation.Raw(Controller.indexRewardCountText, string.format("%d/%d", Count, Total))
	Controller.indexRewardBar.Size = UDim2.fromScale(Count / Total, 1)
	if Page == "Normal" and Count >= Required then
		Translation.Set(Controller.indexRewardText, "Bonus unlocked: +{1}% on all sales", Percent)
	elseif Page == "Normal" then
		Translation.Set(Controller.indexRewardText, "Unlock {1} items to get +{2}% on all sales", Required, Percent)
	elseif Count >= Required then
		Translation.Set(Controller.indexRewardText, "{1} bonus unlocked: +{2}% on all sales", Translation.Format(Mutationconfig[Page].Name), Percent)
	else
		Translation.Set(Controller.indexRewardText, "Unlock {1} {2} items to get +{3}% on all sales", Required, Translation.Format(Mutationconfig[Page].Name), Percent)
	end
end

function Index.ApplyEntries(Controller, Entries, Unlockedkey, Unlockedmutation)
	if Entries then
		Controller.indexRawEntries = Entries
	end
	Entries = Controller.indexRawEntries or {}
	local Page = Controller.indexMutation or "Normal"
	local Sortedentries = {}
	for _, Entry in ipairs(Entries) do
		table.insert(Sortedentries, Entry)
	end
	table.sort(Sortedentries, function(Left, Right)
		local Leftrank = Rarityrank[tostring(Left.Rarity or "Common")] or math.huge
		local Rightrank = Rarityrank[tostring(Right.Rarity or "Common")] or math.huge
		if Leftrank ~= Rightrank then
			return Leftrank < Rightrank
		end
		return tostring(Left.Name or "") < tostring(Right.Name or "")
	end)
	Controller.indexRainbowGradients = {}
	local Unlockedname = nil
	local Counts = {}
	for _, Mutation in ipairs(Mutationconfig.Order) do
		Counts[Mutation] = 0
	end
	for _, Child in ipairs(Controller.indexScrollingFrame:GetChildren()) do
		if Child ~= Controller.indexTemplate and not Child:IsA("UIGridLayout") then Child:Destroy() end
	end

	for Order, Entry in ipairs(Sortedentries) do
		local Unlockedbymutation = if type(Entry.Unlocked) == "table" then Entry.Unlocked else {}
		if Entry.ObjectKey == Unlockedkey and Unlockedbymutation[tostring(Unlockedmutation)] == true then
			Unlockedname = tostring(Entry.Name or Entry.ObjectKey or "Unknown item")
		end
		for _, Mutation in ipairs(Mutationconfig.Order) do
			if Unlockedbymutation[Mutation] == true then
				Counts[Mutation] += 1
			end
		end
		local Card = Controller.indexTemplate:Clone()
		Card.Name = "Index_" .. tostring(Entry.ObjectKey or Entry.Name or math.random(1, 999999))
		Card.LayoutOrder = Order
		Card.Visible = true
		Card.Parent = Controller.indexScrollingFrame
		local RootButton = Card:WaitForChild("Button")
		Shared.AnimateButton(RootButton, function() return false end)
		Core:GetController("GamepadController"):OnActivated(RootButton, function()
			Core:GetController("FeedbackController"):UiClick()
		end)
		local NameText = RootButton:WaitForChild("ObjectNameText")
		local RarityText = RootButton:WaitForChild("RarityText")
		local MutationText = RootButton:WaitForChild("MutationText")
		local Icon = RootButton:WaitForChild("Icon")
		local IsUnlocked = Unlockedbymutation[Page] == true
		local Rarity = Rarityconfig[tostring(Entry.Rarity or "Common")]
		local Mutation = Mutationconfig[Page]
		NameText.Text = if IsUnlocked then tostring(Entry.Name or "") else "???"
		NameText.Visible = true
		RarityText.Text = Rarity.Name
		Uigradient.Ensure(RarityText).Color = Rarity.Gradient
		MutationText.Text = Mutation.Name
		local MutationGradient = Uigradient.Ensure(MutationText)
		MutationGradient.Color = Mutation.Gradient
		if Page == "Rainbow" then
			table.insert(Controller.indexRainbowGradients, MutationGradient)
			Core:GetController("MutationController"):SetRainbowRotation(MutationGradient, true)
		end
		Icon.Image = tostring(Entry.ImageId or "")
		if IsUnlocked then
			Icon.ImageColor3 = UnlockedIconColor
		end
	end

	local Required = math.ceil(#Entries * Indexrewards.Ratio)
	Index.ApplyBonus(Counts, Required)
	Index.ApplyReward(Controller, Page, Counts[Page], #Entries, Required)

	if Unlockedname then
		local Mutation = Mutationconfig[tostring(Unlockedmutation)]
		local Count = Counts[tostring(Unlockedmutation)]
		local Label = if Unlockedmutation == "Normal"
			then Translation.Format(Unlockedname)
			else Translation.Format(Mutation.Name) .. " " .. Translation.Format(Unlockedname)
		Core:GetController("MessageController"):Show("New index entry unlocked: {1} ({2}/{3})", GainGradient, Label, Count, #Entries)
		if Count == Required then
			Core:GetController("FeedbackController"):RewardPopup(
				Translation.Format("{1} Index {2}%!", Translation.Format(Mutation.Name), RequiredPercent),
				Translation.Format("+{1}% Sell Bonus", string.format("%g", Indexrewards.SellPercent)),
				if Unlockedmutation == "Normal" then nil else Mutation.Gradient,
				Unlockedmutation == "Rainbow"
			)
			Core:GetController("BoostController"):PlayGain("IndexSellBonus", false)
		end
	end
	task.defer(function()
		Controller.indexScrollingFrame.CanvasSize = UDim2.fromOffset(0, Controller.indexGridLayout.AbsoluteContentSize.Y)
	end)
end

function Index.SetMutation(Controller, Mutation: string)
	if Controller.indexMutation == Mutation then
		return
	end
	Controller.indexMutation = Mutation
	for _, Refresh in ipairs(Controller.indexMutationRefreshes) do
		Refresh()
	end
	Index.ApplyEntries(Controller)
end

function Index.Init(Controller)
	local Page = Controller.indexPage
	Controller.indexScrollingFrame = Page:WaitForChild("Template")
	Controller.indexTemplate = Controller.indexScrollingFrame:WaitForChild("Template")
	Controller.indexGridLayout = Controller.indexScrollingFrame:WaitForChild("UIGridLayout")
	Controller.indexGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	Controller.indexTemplate.Visible = false
	Controller.indexMutationFrame = Page:WaitForChild("MutationButton")
	Controller.indexRainbowGradient = Uigradient.Ensure(Controller.indexMutationFrame:WaitForChild("RainbowButton"):WaitForChild("Text"))
	Core:GetController("MutationController"):SetRainbowRotation(Controller.indexRainbowGradient, true)
	Controller.indexRainbowGradients = {}
	Controller.indexMutation = "Normal"
	Controller.indexMutationRefreshes = {}
	for _, Mutation in ipairs(Mutationconfig.Order) do
		local Button = Controller.indexMutationFrame:WaitForChild(Mutation .. "Button")
		local Refresh = Shared.AnimateNavButton(Button, function()
			return Controller.indexMutation == Mutation
		end)
		table.insert(Controller.indexMutationRefreshes, Refresh)
		Refresh()
		Core:GetController("GamepadController"):OnActivated(Button, function()
			Index.SetMutation(Controller, Mutation)
		end)
	end
	local Rewardframe = Page:WaitForChild("RewardFrame")
	local Framebar = Rewardframe:WaitForChild("FrameBar")
	Controller.indexRewardBar = Framebar:WaitForChild("Bar")
	Controller.indexRewardCountText = Framebar:WaitForChild("IndexText")
	Controller.indexRewardText = Rewardframe:WaitForChild("Text")
	Index.ApplyEntries(Controller, RemoteManager:InvokeServer("InventoryService", "GetIndexEntries"))
end

function Index.Start(Controller)
	Controller.indexGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		Controller.indexScrollingFrame.CanvasSize = UDim2.fromOffset(0, Controller.indexGridLayout.AbsoluteContentSize.Y)
	end)
	RemoteManager:OnClientEvent("InventoryService", "IndexUpdated", function(Entries, Unlockedkey, Unlockedmutation)
		Index.ApplyEntries(Controller, Entries, Unlockedkey, Unlockedmutation)
	end)
	RunService.Heartbeat:Connect(function()
		local Sequence = Core:GetController("MutationController"):GetGradient("Rainbow")
		Controller.indexRainbowGradient.Color = Sequence
		for _, Gradient in ipairs(Controller.indexRainbowGradients) do
			Gradient.Color = Sequence
		end
	end)
end

return Index
