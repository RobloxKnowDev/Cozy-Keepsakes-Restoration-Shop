local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Rarityconfig = require(ReplicatedStorage.Shared.Config.Rarity)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local Index = {}
local GainColor = Color3.fromRGB(126, 255, 145)
local LockedIconColor = Color3.fromRGB(160, 160, 160)
local LockedIconTransparency = 0.35

local function UpdateCount(Controller)
	local UnlockedCount = 0
	for _, Entry in ipairs(Controller.indexEntries) do
		if Entry.Unlocked then UnlockedCount += 1 end
	end
	Controller.restoredText.Text = string.format("Restored items  (%d/%d)", UnlockedCount, #Controller.indexEntries)
end

function Index.ApplyEntries(Controller, Entries)
	local Previous = Controller.indexUnlockedByObject or {}
	Controller.indexEntries = Entries or {}
	Controller.indexUnlockedByObject = {}
	local NewlyUnlocked = {}
	for _, Child in ipairs(Controller.indexScrollingFrame:GetChildren()) do
		if Child ~= Controller.indexTemplate and not Child:IsA("UIGridLayout") then Child:Destroy() end
	end

	for _, Entry in ipairs(Controller.indexEntries) do
		Controller.indexUnlockedByObject[Entry.ObjectKey] = Entry.Unlocked == true
		if Controller.hasLoadedIndexEntries and Entry.Unlocked == true and Previous[Entry.ObjectKey] ~= true then
			table.insert(NewlyUnlocked, tostring(Entry.Name or Entry.ObjectKey or "Unknown item"))
		end
		local Card = Controller.indexTemplate:Clone()
		Card.Name = "Index_" .. tostring(Entry.ObjectKey or Entry.Name or math.random(1, 999999))
		Card.Visible = true
		Card.Parent = Controller.indexScrollingFrame
		local RootButton = Card:WaitForChild("Button")
		Shared.AnimateButton(RootButton, function() return false end)
		local NameText = RootButton:WaitForChild("NameText")
		local RarityText = RootButton:WaitForChild("RarityText")
		local Icon = RootButton:WaitForChild("Icon")
		local IsUnlocked = Entry.Unlocked == true
		local Rarity = Rarityconfig[tostring(Entry.Rarity or "Common")]
		NameText.Text = if IsUnlocked then tostring(Entry.Name or "") else "???"
		NameText.Visible = true
		RarityText.Text = Rarity.Name
		RarityText.TextColor3 = Rarity.Color
		local DefaultColor = Icon.ImageColor3
		local DefaultTransparency = Icon.ImageTransparency
		Icon.Image = tostring(Entry.ImageId or "")
		Icon.ImageColor3 = if IsUnlocked then DefaultColor else LockedIconColor
		Icon.ImageTransparency = if IsUnlocked then DefaultTransparency else LockedIconTransparency
	end

	if Controller.hasLoadedIndexEntries then
		for _, Name in ipairs(NewlyUnlocked) do
			Core:GetController("MessageController"):Show(string.format("New index entry unlocked: %s", Name), GainColor)
		end
	end
	Controller.hasLoadedIndexEntries = true
	UpdateCount(Controller)
	task.defer(function()
		Controller.indexScrollingFrame.CanvasSize = UDim2.fromOffset(0, Controller.indexGridLayout.AbsoluteContentSize.Y)
	end)
end

function Index.Init(Controller)
	Controller.indexScrollingFrame = Controller.indexFrame:WaitForChild("ScrollingFrame")
	Controller.indexTemplate = Controller.indexScrollingFrame:WaitForChild("Template")
	Controller.indexGridLayout = Controller.indexScrollingFrame:WaitForChild("UIGridLayout")
	Controller.restoredText = Controller.indexFrame:WaitForChild("RestoredText")
	Controller.indexEntries = {}
	Controller.indexUnlockedByObject = {}
	Controller.hasLoadedIndexEntries = false
	Controller.indexTemplate.Visible = false
	Index.ApplyEntries(Controller, RemoteManager:InvokeServer("InventoryService", "GetIndexEntries"))
end

function Index.Start(Controller)
	Controller.indexGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		Controller.indexScrollingFrame.CanvasSize = UDim2.fromOffset(0, Controller.indexGridLayout.AbsoluteContentSize.Y)
	end)
	RemoteManager:OnClientEvent("InventoryService", "IndexUpdated", function(Entries) Index.ApplyEntries(Controller, Entries) end)
end

return Index
