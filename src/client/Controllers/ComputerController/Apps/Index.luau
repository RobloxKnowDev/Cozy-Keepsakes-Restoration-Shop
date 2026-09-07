local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Mutationconfig = require(ReplicatedStorage.Shared.Config.Mutation)
local Rarityconfig = require(ReplicatedStorage.Shared.Config.Rarity)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local Index = {}
local Rarityrank = {}
for Rank, Rarity in ipairs(Rarityconfig.Order) do
	Rarityrank[Rarity] = Rank
end
local GainColor = Color3.fromRGB(126, 255, 145)
local LockedIconColor = Color3.fromRGB(160, 160, 160)
local LockedIconTransparency = 0.35

local function UpdateCount(Controller)
	local UnlockedCount = 0
	for _, Entry in ipairs(Controller.indexEntries) do
		if Controller.indexUnlockedByObject[Entry.ObjectKey] then UnlockedCount += 1 end
	end
	Controller.restoredText.Text = string.format("Restored items  (%d/%d)", UnlockedCount, #Controller.indexEntries)
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
	Controller.indexEntries = Sortedentries
	Controller.indexUnlockedByObject = {}
	Controller.indexRainbowLabels = {}
	local Unlockedname = nil
	for _, Child in ipairs(Controller.indexScrollingFrame:GetChildren()) do
		if Child ~= Controller.indexTemplate and not Child:IsA("UIGridLayout") then Child:Destroy() end
	end

	for Order, Entry in ipairs(Controller.indexEntries) do
		local Unlockedbymutation = if type(Entry.Unlocked) == "table" then Entry.Unlocked else {}
		Controller.indexUnlockedByObject[Entry.ObjectKey] = Unlockedbymutation[Page] == true
		if Entry.ObjectKey == Unlockedkey and Unlockedbymutation[tostring(Unlockedmutation)] == true then
			Unlockedname = tostring(Entry.Name or Entry.ObjectKey or "Unknown item")
		end
		local Card = Controller.indexTemplate:Clone()
		Card.Name = "Index_" .. tostring(Entry.ObjectKey or Entry.Name or math.random(1, 999999))
		Card.LayoutOrder = Order
		Card.Visible = true
		Card.Parent = Controller.indexScrollingFrame
		local RootButton = Card:WaitForChild("Button")
		Shared.AnimateButton(RootButton, function() return false end)
		local NameText = RootButton:WaitForChild("NameText")
		local RarityText = RootButton:WaitForChild("RarityText")
		local MutationText = RootButton:WaitForChild("MutationText")
		local Icon = RootButton:WaitForChild("Icon")
		local IsUnlocked = Unlockedbymutation[Page] == true
		local Rarity = Rarityconfig[tostring(Entry.Rarity or "Common")]
		local Mutation = Mutationconfig[Page]
		NameText.Text = if IsUnlocked then tostring(Entry.Name or "") else "???"
		NameText.Visible = true
		RarityText.Text = Rarity.Name
		RarityText.TextColor3 = Rarity.Color
		MutationText.Text = Mutation.Name
		MutationText.TextColor3 = Mutation.Color
		if Page == "Rainbow" then
			table.insert(Controller.indexRainbowLabels, MutationText)
		end
		local DefaultColor = Icon.ImageColor3
		local DefaultTransparency = Icon.ImageTransparency
		Icon.Image = tostring(Entry.ImageId or "")
		Icon.ImageColor3 = if IsUnlocked then DefaultColor else LockedIconColor
		Icon.ImageTransparency = if IsUnlocked then DefaultTransparency else LockedIconTransparency
	end

	if Unlockedname then
		local Label = if Unlockedmutation == "Normal"
			then Unlockedname
			else Mutationconfig[tostring(Unlockedmutation)].Name .. " " .. Unlockedname
		Core:GetController("MessageController"):Show(string.format("New index entry unlocked: %s", Label), GainColor)
	end
	UpdateCount(Controller)
	task.defer(function()
		Controller.indexScrollingFrame.CanvasSize = UDim2.fromOffset(0, Controller.indexGridLayout.AbsoluteContentSize.Y)
	end)
end

function Index.SetMutation(Controller, Mutation: string)
	if Controller.indexMutation == Mutation then
		return
	end
	Controller.indexMutation = Mutation
	for Name, Button in pairs(Controller.indexMutationButtons) do
		Button:FindFirstChildOfClass("UIStroke").Enabled = Name == Mutation
	end
	Index.ApplyEntries(Controller)
end

function Index.Init(Controller)
	Controller.indexScrollingFrame = Controller.indexFrame:WaitForChild("ScrollingFrame")
	Controller.indexTemplate = Controller.indexScrollingFrame:WaitForChild("Template")
	Controller.indexGridLayout = Controller.indexScrollingFrame:WaitForChild("UIGridLayout")
	Controller.indexGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	Controller.restoredText = Controller.indexFrame:WaitForChild("RestoredText")
	Controller.indexEntries = {}
	Controller.indexUnlockedByObject = {}
	Controller.indexTemplate.Visible = false
	Controller.indexMutationFrame = Controller.indexFrame:WaitForChild("MutationFrame")
	Controller.indexRainbowText = Controller.indexMutationFrame:WaitForChild("RainbowButton"):WaitForChild("Text")
	Controller.indexRainbowLabels = {}
	Controller.indexMutation = "Normal"
	Controller.indexMutationButtons = {}
	for _, Mutation in ipairs(Mutationconfig.Order) do
		local Button = Controller.indexMutationFrame:WaitForChild(Mutation .. "Button")
		Controller.indexMutationButtons[Mutation] = Button
		Shared.AnimateButton(Button, function()
			return Controller.indexMutation == Mutation
		end)
		Button.Activated:Connect(function()
			Index.SetMutation(Controller, Mutation)
		end)
	end
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
		local Color = Core:GetController("MutationController"):GetColor("Rainbow")
		if not Color then
			return
		end
		Controller.indexRainbowText.TextColor3 = Color
		for _, Label in ipairs(Controller.indexRainbowLabels) do
			if Label.Parent then
				Label.TextColor3 = Color
			end
		end
	end)
end

return Index
