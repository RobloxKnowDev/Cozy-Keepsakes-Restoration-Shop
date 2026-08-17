local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local Index = {}
local GainColor = Color3.fromRGB(126, 255, 145)
local LockedIconColor = Color3.fromRGB(160, 160, 160)
local LockedIconTransparency = 0.35

local function UpdateCount(Controller)
	if not Controller.restoredText then return end
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
		local RootButton = Card:FindFirstChild("Button")
		if RootButton and RootButton:IsA("GuiButton") then Shared.AnimateButton(RootButton, function() return false end) end
		local ButtonRoot = RootButton or Card
		local NameText = ButtonRoot:FindFirstChild("NameText", true)
		local RarityText = ButtonRoot:FindFirstChild("RarityText", true)
		local Icon = ButtonRoot:FindFirstChild("Icon", true)
		local IsUnlocked = Entry.Unlocked == true
		if NameText and (NameText:IsA("TextLabel") or NameText:IsA("TextButton") or NameText:IsA("TextBox")) then
			NameText.Text = tostring(Entry.Name or "")
			if NameText:IsA("GuiObject") then NameText.Visible = IsUnlocked end
		end
		if RarityText and (RarityText:IsA("TextLabel") or RarityText:IsA("TextButton") or RarityText:IsA("TextBox")) then RarityText.Text = tostring(Entry.Rarity or "Common") end
		if Icon and (Icon:IsA("ImageLabel") or Icon:IsA("ImageButton")) then
			local DefaultColor = Icon.ImageColor3
			local DefaultTransparency = Icon.ImageTransparency
			Icon.Image = tostring(Entry.ImageId or "")
			Icon.ImageColor3 = if IsUnlocked then DefaultColor else LockedIconColor
			Icon.ImageTransparency = if IsUnlocked then DefaultTransparency else LockedIconTransparency
		end
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
	Controller.indexScrollingFrame = Shared.RequireScrollingFrame(Controller.indexFrame, "ScrollingFrame")
	Controller.indexTemplate = Shared.RequireFrame(Controller.indexScrollingFrame, "Template")
	Controller.indexGridLayout = Controller.indexScrollingFrame:FindFirstChildOfClass("UIGridLayout")
	assert(Controller.indexGridLayout, "UIGridLayout introuvable dans IndexFrame.ScrollingFrame")
	Controller.restoredText = Shared.FindText(Controller.indexFrame, "RestoredText")
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
