local Players = game:GetService("Players")
local Runservice = game:GetService("RunService")
local Tweenservice = game:GetService("TweenService")
local Userinputservice = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)
local Computercontroller = {
	Name = "ComputerController",
	Priority = 3,
}

local HighlightFillcolor = Color3.fromRGB(255, 232, 163)
local HighlightOutlinecolor = Color3.fromRGB(255, 255, 255)
local Cameratweeninfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Buttontweeninfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Activebuttoncolor = Color3.fromRGB(231, 248, 222)
local Activecontentcolor = Color3.fromRGB(0, 0, 0)
local Activebuttonscale = 1.03
local Countduration = 0.65
local Pulseinfo = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Gaincolor = Color3.fromRGB(126, 255, 145)
local Losscolor = Color3.fromRGB(255, 138, 138)
local Lockediconcolor = Color3.fromRGB(160, 160, 160)
local Lockedicontransparency = 0.35

local function FormatCurrency(Value: number): string
	local Rounded = math.round(Value * 100) / 100
	if math.abs(Rounded - math.round(Rounded)) < 0.005 then
		return string.format("$%d", math.round(Rounded))
	end
	return string.format("$%.2f", Rounded)
end

local function FormatProfit(Value: number): string
	local Rounded = math.round(Value * 100) / 100
	if Rounded < 0 then
		if math.abs(Rounded - math.round(Rounded)) < 0.005 then
			return string.format("-$%d", math.abs(math.round(Rounded)))
		end
		return string.format("-$%.2f", math.abs(Rounded))
	end
	if math.abs(Rounded - math.round(Rounded)) < 0.005 then
		return string.format("+$%d", math.round(Rounded))
	end
	return string.format("+$%.2f", Rounded)
end

local function FindComputerFromInstance(Target: Instance?): Instance?
	local Current = Target
	while Current and Current ~= Workspace do
		if Current.Name == "Computer" and (Current:IsA("BasePart") or Current:IsA("Model")) then
			return Current
		end
		Current = Current.Parent
	end

	return nil
end

local function FindText(Parent: Instance, Name: string): TextLabel | TextButton | TextBox
	local Instance = Parent:FindFirstChild(Name, true)
	assert(
		Instance and (Instance:IsA("TextLabel") or Instance:IsA("TextButton") or Instance:IsA("TextBox")),
		Name .. " introuvable dans l'interface computer"
	)
	return Instance
end

local function FindButton(Parent: Instance, Name: string): GuiButton
	local Instance = Parent:FindFirstChild(Name, true)
	assert(Instance and Instance:IsA("GuiButton"), Name .. " introuvable dans l'interface computer")
	return Instance
end

local function FindOptionalText(Parent: Instance?, Name: string): (TextLabel | TextButton | TextBox)?
	if not Parent then
		return nil
	end
	local Instance = Parent:FindFirstChild(Name, true)
	if Instance and (Instance:IsA("TextLabel") or Instance:IsA("TextButton") or Instance:IsA("TextBox")) then
		return Instance
	end
	return nil
end

local function FindOptionalButton(Parent: Instance?, Name: string): GuiButton?
	if not Parent then
		return nil
	end
	local Instance = Parent:FindFirstChild(Name, true)
	if Instance and Instance:IsA("GuiButton") then
		return Instance
	end
	return nil
end

local function FindOptionalFrame(Parent: Instance?, Name: string): Frame?
	if not Parent then
		return nil
	end
	local Instance = Parent:FindFirstChild(Name, true)
	if Instance and Instance:IsA("Frame") then
		return Instance
	end
	return nil
end

local function FindFrame(Parent: Instance, Name: string): Frame
	local Instance = Parent:FindFirstChild(Name, true)
	assert(Instance and Instance:IsA("Frame"), Name .. " introuvable dans l'interface computer")
	return Instance
end

local function FindScrollingFrame(Parent: Instance, Name: string): ScrollingFrame
	local Instance = Parent:FindFirstChild(Name, true)
	assert(Instance and Instance:IsA("ScrollingFrame"), Name .. " introuvable dans l'interface computer")
	return Instance
end

local function EnsureScale(Target: Instance): UIScale
	local Existing = Target:FindFirstChildOfClass("UIScale")
	if Existing then
		return Existing
	end

	local Scale = Instance.new("UIScale")
	Scale.Parent = Target
	return Scale
end

local function AnimateButton(Button: GuiButton, IsActive: () -> boolean)
	local Scale = EnsureScale(Button)
	local IsHovering = false

	Button.MouseEnter:Connect(function()
		if IsActive() then
			return
		end
		IsHovering = true
		Tweenservice:Create(Scale, Buttontweeninfo, { Scale = 1.06 }):Play()
	end)

	Button.MouseLeave:Connect(function()
		if IsActive() then
			return
		end
		IsHovering = false
		Tweenservice:Create(Scale, Buttontweeninfo, { Scale = 1 }):Play()
	end)

	Button.MouseButton1Down:Connect(function()
		if IsActive() then
			return
		end
		Tweenservice:Create(Scale, Buttontweeninfo, { Scale = 0.96 }):Play()
	end)

	Button.MouseButton1Up:Connect(function()
		if IsActive() then
			Tweenservice:Create(Scale, Buttontweeninfo, { Scale = Activebuttonscale }):Play()
			return
		end
		local Targetscale = IsHovering and 1.06 or 1
		Tweenservice:Create(Scale, Buttontweeninfo, { Scale = Targetscale }):Play()
	end)
end

function Computercontroller:IsOpen(): boolean
	return self.isOpen == true
end

function Computercontroller:CanOpen(): boolean
	local Cameracontroller = Core:GetController("InspectionCameraController")
	local Restorationcontroller = Core:GetController("RestorationController")
	return not self:IsOpen()
		and Cameracontroller:IsIntroCameraReady()
		and not Restorationcontroller:IsEditingObject()
end

function Computercontroller:SetHoveredComputer(Computer: Instance?)
	if self.hoveredComputer == Computer then
		return
	end

	self.hoveredComputer = Computer
	self.hoverHighlight.Adornee = Computer
	self.hoverHighlight.Enabled = Computer ~= nil and not self:IsOpen()
end

function Computercontroller:UpdateHoveredComputer()
	if not self:CanOpen() then
		self:SetHoveredComputer(nil)
		return
	end

	local Target = self.mouse and self.mouse.Target or nil
	self:SetHoveredComputer(FindComputerFromInstance(Target))
end

function Computercontroller:FocusCamera()
	local Camera = Workspace.CurrentCamera
	Camera.CameraType = Enum.CameraType.Scriptable
	Tweenservice:Create(Camera, Cameratweeninfo, {
		CFrame = self.cameraPart.CFrame,
	}):Play()
end

function Computercontroller:SetHudVisible(IsVisible: boolean)
	if self.hudCashFrame then
		self.hudCashFrame.Visible = IsVisible
	end
	if self.hudDayFrame then
		self.hudDayFrame.Visible = IsVisible
	end
end

function Computercontroller:SyncHeader()
	if self.cashText and self.hudCashText then
		self.cashText.Text = self.hudCashText.Text
	end
	if self.dayText and self.hudDayText then
		self.dayText.Text = self.hudDayText.Text
	end
	if self.timeText and self.hudTimeText then
		self.timeText.Text = self.hudTimeText.Text
	end
end

function Computercontroller:SetDisplayedComputerCash(Value: number)
	self.displayedComputerCash = Value
	if self.cashText then
		self.cashText.Text = FormatCurrency(Value)
	end
end

function Computercontroller:AnimateComputerCashTo(TargetValue: number)
	local Startvalue = self.displayedComputerCash or TargetValue
	local Delta = TargetValue - Startvalue
	if math.abs(Delta) < 0.005 then
		self:SetDisplayedComputerCash(TargetValue)
		return
	end

	self.computerCashAnimationId += 1
	local Animationid = self.computerCashAnimationId
	local Starttime = os.clock()
	local Targetcolor = Delta > 0 and Gaincolor or Losscolor

	if self.cashTextScale then
		Tweenservice:Create(self.cashTextScale, Pulseinfo, {
			Scale = 1.08,
		}):Play()
	end
	if self.cashText then
		Tweenservice:Create(self.cashText, Pulseinfo, {
			TextColor3 = Targetcolor,
		}):Play()
	end

	local Connection
	Connection = Runservice.RenderStepped:Connect(function()
		if self.computerCashAnimationId ~= Animationid then
			Connection:Disconnect()
			return
		end

		local Alpha = math.clamp((os.clock() - Starttime) / Countduration, 0, 1)
		local Eased = Tweenservice:GetValue(Alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		self:SetDisplayedComputerCash(Startvalue + Delta * Eased)

		if Alpha >= 1 then
			Connection:Disconnect()
			self:SetDisplayedComputerCash(TargetValue)
			if self.cashTextScale then
				Tweenservice:Create(self.cashTextScale, Pulseinfo, {
					Scale = 1,
				}):Play()
			end
			if self.cashText and self.baseComputerCashTextColor then
				Tweenservice:Create(self.cashText, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextColor3 = self.baseComputerCashTextColor,
				}):Play()
			end
		end
	end)
end

function Computercontroller:SetDailyProfitAppearance(Value: number)
	if not self.dailyProfitText then
		return
	end
	if Value > 0 then
		self.dailyProfitText.TextColor3 = Gaincolor
	elseif Value < 0 then
		self.dailyProfitText.TextColor3 = Losscolor
	else
		self.dailyProfitText.TextColor3 = self.baseDailyProfitTextColor
	end
end

function Computercontroller:ApplyStats(Stats)
	if not Stats then
		return
	end

	if self.itemsText then
		self.itemsText.Text = tostring(Stats.ItemsSold or 0)
	end
	if self.reputationText then
		self.reputationText.Text = tostring(Stats.Reputation or 0)
	end
	if self.dailyProfitText then
		self.dailyProfitText.Text = FormatProfit(Stats.DailyProfit or 0)
	end
	self:SetDailyProfitAppearance(Stats.DailyProfit or 0)
end

function Computercontroller:ShowSellDetails(Item)
	local Hasitem = Item ~= nil
	if self.sellDetailsFrame then
		self.sellDetailsFrame.Visible = true
	end

	if not Hasitem then
		self.selectedRestoredItemId = nil
		if self.sellDetailsNameText then self.sellDetailsNameText.Text = "No item selected" end
		if self.sellDetailsBoughtText then self.sellDetailsBoughtText.Text = "$0" end
		if self.sellDetailsRarityText then self.sellDetailsRarityText.Text = "-" end
		if self.sellDetailsRestorationText then self.sellDetailsRestorationText.Text = "0%" end
		if self.sellDetailsValueText then self.sellDetailsValueText.Text = "$0" end
		if self.sellDetailsProfitText then
			self.sellDetailsProfitText.Text = "$0"
			self.sellDetailsProfitText.TextColor3 = self.sellDetailBaseProfitTextColor or self.sellDetailsProfitText.TextColor3
		end
		if self.sellDetailsIcon and (self.sellDetailsIcon:IsA("ImageLabel") or self.sellDetailsIcon:IsA("ImageButton")) then
			self.sellDetailsIcon.Image = ""
		end
		if self.sellDetailsProgressBar then
			self.sellDetailsProgressBar.Size = UDim2.fromScale(0, 1)
		end
		if self.sellItemButton then
			self.sellItemButton.Active = false
			self.sellItemButton.AutoButtonColor = false
		end
		if self.sellAllButton then
			self.sellAllButton.Active = #self.restoredItems > 0
			self.sellAllButton.AutoButtonColor = #self.restoredItems > 0
		end
		return
	end

	self.selectedRestoredItemId = Item.Id
	if self.sellDetailsNameText then self.sellDetailsNameText.Text = tostring(Item.Name or "") end
	if self.sellDetailsBoughtText then self.sellDetailsBoughtText.Text = FormatCurrency(Item.PurchasePrice or 0) end
	if self.sellDetailsRarityText then self.sellDetailsRarityText.Text = tostring(Item.Rarity or "Common") end
	if self.sellDetailsRestorationText then
		self.sellDetailsRestorationText.Text = string.format("%d%%", Item.RestorationPercent or 0)
	end
	if self.sellDetailsValueText then self.sellDetailsValueText.Text = FormatCurrency(Item.CurrentValue or 0) end
	if self.sellDetailsProfitText then
		self.sellDetailsProfitText.Text = FormatProfit(Item.NetProfit or 0)
		self.sellDetailsProfitText.TextColor3 = if (Item.NetProfit or 0) > 0
			then Gaincolor
			elseif (Item.NetProfit or 0) < 0 then Losscolor
			else self.sellDetailBaseProfitTextColor or self.sellDetailsProfitText.TextColor3
	end
	if self.sellDetailsIcon and (self.sellDetailsIcon:IsA("ImageLabel") or self.sellDetailsIcon:IsA("ImageButton")) then
		self.sellDetailsIcon.Image = tostring(Item.ImageId or "")
	end
	if self.sellDetailsProgressBar then
		self.sellDetailsProgressBar.Size = UDim2.fromScale(math.clamp((Item.RestorationPercent or 0) / 100, 0, 1), 1)
	end
	if self.sellItemButton then
		self.sellItemButton.Active = true
		self.sellItemButton.AutoButtonColor = true
	end
	if self.sellAllButton then
		self.sellAllButton.Active = #self.restoredItems > 0
		self.sellAllButton.AutoButtonColor = #self.restoredItems > 0
	end
end

function Computercontroller:ApplyRestoredItems(Items)
	self.restoredItems = Items or {}
	local Selecteditem = nil

	for _, Child in ipairs(self.sellScrollingFrame:GetChildren()) do
		if Child ~= self.sellTemplate and not Child:IsA("UIGridLayout") then
			Child:Destroy()
		end
	end

	for _, Item in ipairs(self.restoredItems) do
		local Card = self.sellTemplate:Clone()
		Card.Name = "Item_" .. tostring(Item.Id or math.random(1, 999999))
		Card.Visible = true
		Card.Parent = self.sellScrollingFrame

		local RootButton = Card:FindFirstChild("Button")
		if RootButton and RootButton:IsA("GuiButton") then
			AnimateButton(RootButton, function()
				return false
			end)
			RootButton.Activated:Connect(function()
				self:ShowSellDetails(Item)
			end)
		end

		local SellButton = Card:FindFirstChild("SellButton", true)
		if SellButton and SellButton:IsA("GuiButton") then
			AnimateButton(SellButton, function()
				return false
			end)
			SellButton.Activated:Connect(function()
				local SoldItem = Remotemanager:InvokeServer("InventoryService", "SellRestoredItem", Item.Id)
				if SoldItem and self.selectedRestoredItemId == Item.Id then
					self.selectedRestoredItemId = nil
				end
			end)
		end

		local ButtonRoot = Card:FindFirstChild("Button")
		if ButtonRoot then
			local NameText = ButtonRoot:FindFirstChild("NameText", true)
			local PriceText = ButtonRoot:FindFirstChild("PriceText", true)
			local Icon = ButtonRoot:FindFirstChild("Icon", true)
			if NameText and (NameText:IsA("TextLabel") or NameText:IsA("TextButton") or NameText:IsA("TextBox")) then
				NameText.Text = tostring(Item.Name or "")
			end
			if PriceText and (PriceText:IsA("TextLabel") or PriceText:IsA("TextButton") or PriceText:IsA("TextBox")) then
				PriceText.Text = FormatCurrency(Item.CurrentValue or 0)
			end
			if Icon and (Icon:IsA("ImageLabel") or Icon:IsA("ImageButton")) then
				Icon.Image = tostring(Item.ImageId or "")
			end
		end

		if self.selectedRestoredItemId and Item.Id == self.selectedRestoredItemId then
			Selecteditem = Item
		end
	end

	if not Selecteditem and #self.restoredItems > 0 then
		Selecteditem = self.restoredItems[1]
	end
	self:ShowSellDetails(Selecteditem)

	task.defer(function()
		local ContentSize = self.sellGridLayout.AbsoluteContentSize
		self.sellScrollingFrame.CanvasSize = UDim2.fromOffset(0, ContentSize.Y)
	end)
end

function Computercontroller:UpdateRestoredCount()
	if not self.restoredText then
		return
	end

	local Unlockedcount = 0
	local Totalcount = 0
	for _, Entry in ipairs(self.indexEntries) do
		Totalcount += 1
		if Entry.Unlocked then
			Unlockedcount += 1
		end
	end

	self.restoredText.Text = string.format("Restored items  (%d/%d)", Unlockedcount, Totalcount)
end

function Computercontroller:ApplyIndexEntries(Entries)
	local Previousunlockbyobject = self.indexUnlockedByObject or {}
	self.indexEntries = Entries or {}
	self.indexUnlockedByObject = {}
	local Newlyunlocked = {}

	for _, Child in ipairs(self.indexScrollingFrame:GetChildren()) do
		if Child ~= self.indexTemplate and not Child:IsA("UIGridLayout") then
			Child:Destroy()
		end
	end

	for _, Entry in ipairs(self.indexEntries) do
		self.indexUnlockedByObject[Entry.ObjectKey] = Entry.Unlocked == true
		if self.hasLoadedIndexEntries and Entry.Unlocked == true and Previousunlockbyobject[Entry.ObjectKey] ~= true then
			table.insert(Newlyunlocked, tostring(Entry.Name or Entry.ObjectKey or "Unknown item"))
		end

		local Card = self.indexTemplate:Clone()
		Card.Name = "Index_" .. tostring(Entry.ObjectKey or Entry.Name or math.random(1, 999999))
		Card.Visible = true
		Card.Parent = self.indexScrollingFrame

		local RootButton = Card:FindFirstChild("Button")
		if RootButton and RootButton:IsA("GuiButton") then
			AnimateButton(RootButton, function()
				return false
			end)
		end

		local ButtonRoot = RootButton or Card
		local NameText = ButtonRoot:FindFirstChild("NameText", true)
		local RarityText = ButtonRoot:FindFirstChild("RarityText", true)
		local Icon = ButtonRoot:FindFirstChild("Icon", true)
		local IsUnlocked = Entry.Unlocked == true

		if NameText and (NameText:IsA("TextLabel") or NameText:IsA("TextButton") or NameText:IsA("TextBox")) then
			NameText.Text = tostring(Entry.Name or "")
			if NameText:IsA("GuiObject") then
				NameText.Visible = IsUnlocked
			end
		end

		if RarityText and (RarityText:IsA("TextLabel") or RarityText:IsA("TextButton") or RarityText:IsA("TextBox")) then
			RarityText.Text = tostring(Entry.Rarity or "Common")
		end

		if Icon and (Icon:IsA("ImageLabel") or Icon:IsA("ImageButton")) then
			local Unlockediconcolor = Icon.ImageColor3
			local Unlockedicontransparency = Icon.ImageTransparency
			Icon.Image = tostring(Entry.ImageId or "")
			Icon.ImageColor3 = if IsUnlocked then Unlockediconcolor else Lockediconcolor
			Icon.ImageTransparency = if IsUnlocked then Unlockedicontransparency else Lockedicontransparency
		end
	end

	if self.hasLoadedIndexEntries and #Newlyunlocked > 0 then
		local Messagecontroller = Core:GetController("MessageController")
		for _, Name in ipairs(Newlyunlocked) do
			Messagecontroller:Show(string.format("New index entry unlocked: %s", Name), Gaincolor)
		end
	end

	self.hasLoadedIndexEntries = true
	self:UpdateRestoredCount()

	task.defer(function()
		local ContentSize = self.indexGridLayout.AbsoluteContentSize
		self.indexScrollingFrame.CanvasSize = UDim2.fromOffset(0, ContentSize.Y)
	end)
end

function Computercontroller:ApplyNavButtonStyle(Button: GuiButton, IsActive: boolean)
	local Scale = EnsureScale(Button)
	local Targetscale = IsActive and Activebuttonscale or 1
	local Targetbackground = IsActive and Activebuttoncolor or self.navButtonDefaults[Button].BackgroundColor3

	Tweenservice:Create(Scale, Buttontweeninfo, { Scale = Targetscale }):Play()
	Tweenservice:Create(Button, Buttontweeninfo, { BackgroundColor3 = Targetbackground }):Play()

	local Stroke = self.navButtonDefaults[Button].Stroke
	if Stroke then
		Tweenservice:Create(Stroke, Buttontweeninfo, {
			Transparency = IsActive and 1 or self.navButtonDefaults[Button].StrokeTransparency,
		}):Play()
	end

	for _, TextObject in ipairs(self.navButtonDefaults[Button].Texts) do
		Tweenservice:Create(TextObject, Buttontweeninfo, { TextColor3 = IsActive and Activecontentcolor or self.navButtonDefaults[Button].TextColors[TextObject] }):Play()
	end

	for _, ImageObject in ipairs(self.navButtonDefaults[Button].Images) do
		Tweenservice:Create(ImageObject, Buttontweeninfo, { ImageColor3 = IsActive and Activecontentcolor or self.navButtonDefaults[Button].ImageColors[ImageObject] }):Play()
	end
end

function Computercontroller:SetPage(PageName: string)
	self.activePage = PageName
	self.homeFrame.Visible = PageName == "Home"
	self.indexFrame.Visible = PageName == "Index"
	self.sellFrame.Visible = PageName == "Sell"
	self:ApplyNavButtonStyle(self.homeButton, PageName == "Home")
	self:ApplyNavButtonStyle(self.indexButton, PageName == "Index")
	self:ApplyNavButtonStyle(self.sellNavButton, PageName == "Sell")
end

function Computercontroller:Open()
	if not self:CanOpen() then
		return
	end

	self.isOpen = true
	self:SetHoveredComputer(nil)
	self:SyncHeader()
	self:SetHudVisible(false)
	self.surfaceGui.Enabled = true
	self.frame.Visible = true
	self:SetPage("Home")
	Userinputservice.MouseIconEnabled = true
	self:FocusCamera()
end

function Computercontroller:Close()
	if not self:IsOpen() then
		return
	end

	self.isOpen = false
	self.frame.Visible = false
	self:SetHudVisible(true)
	Core:GetController("InspectionCameraController"):ShowIntroCamera()
	self:UpdateHoveredComputer()
end

function Computercontroller:Init()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.mouse = Players.LocalPlayer:GetMouse()
	self.computer = Workspace:WaitForChild("Computer")
	self.cameraPart = Workspace:WaitForChild("CamPartComputer") :: BasePart
	self.surfaceGui = self.computer:WaitForChild("SurfaceGui") :: SurfaceGui
	self.frame = self.surfaceGui:WaitForChild("Frame") :: Frame
	self.header = self.frame:WaitForChild("Header") :: Frame
	self.pageFrame = FindFrame(self.frame, "PageFrame")
	self.homeFrame = FindFrame(self.pageFrame, "HomeFrame")
	self.indexFrame = FindFrame(self.pageFrame, "IndexFrame")
	self.sellFrame = FindFrame(self.pageFrame, "SellFrame")
	self.statsFrame = FindFrame(self.homeFrame, "StatsFrame")
	self.indexScrollingFrame = FindScrollingFrame(self.indexFrame, "ScrollingFrame")
	self.indexTemplate = FindFrame(self.indexScrollingFrame, "Template")
	self.indexGridLayout = self.indexScrollingFrame:FindFirstChildOfClass("UIGridLayout")
	assert(self.indexGridLayout, "UIGridLayout introuvable dans IndexFrame.ScrollingFrame")
	self.sellScrollingFrame = FindScrollingFrame(self.sellFrame, "ScrollingFrame")
	self.sellTemplate = FindFrame(self.sellScrollingFrame, "Template")
	self.sellDetailsFrame = FindOptionalFrame(self.sellFrame, "StatsFrame")
	self.sellGridLayout = self.sellScrollingFrame:FindFirstChildOfClass("UIGridLayout")
	assert(self.sellGridLayout, "UIGridLayout introuvable dans SellFrame.ScrollingFrame")
	self.exitButton = FindButton(self.header, "ExitButton")
	self.homeButton = FindButton(self.frame, "HomeButton")
	self.indexButton = FindButton(self.frame, "IndexButton")
	self.sellNavButton = FindButton(self.frame, "SellButton")
	self.sellItemButton = FindOptionalButton(self.sellDetailsFrame, "SellButton")
	self.sellAllButton = FindOptionalButton(self.sellFrame, "SellAllButton")
	self.cashText = FindText(self.header, "CashText")
	self.dayText = FindText(self.header, "DayText")
	self.timeText = FindText(self.header, "TimeText")
	self.hud = Playergui:WaitForChild("HUD")
	self.hudCashFrame = self.hud:WaitForChild("CashFrame") :: GuiObject
	self.hudDayFrame = self.hud:WaitForChild("DayFrame") :: GuiObject
	self.hudCashText = FindText(self.hudCashFrame, "CashText")
	self.hudDayText = FindText(self.hudDayFrame, "DayText")
	self.hudTimeText = FindText(self.hudDayFrame, "TimeText")
	self.itemsText = FindOptionalText(self.statsFrame, "ItemsText")
	self.reputationText = FindOptionalText(self.statsFrame, "ReputationText")
	self.dailyProfitText = FindOptionalText(self.statsFrame, "DailyText")
	self.restoredText = FindOptionalText(self.indexFrame, "RestoredText")
	self.sellDetailsNameText = FindOptionalText(self.sellDetailsFrame, "NameText")
	self.sellDetailsBoughtText = FindOptionalText(self.sellDetailsFrame, "BoughtText")
	self.sellDetailsRarityText = FindOptionalText(self.sellDetailsFrame, "RarityText")
	self.sellDetailsRestorationText = FindOptionalText(self.sellDetailsFrame, "RestorationText")
	self.sellDetailsValueText = FindOptionalText(self.sellDetailsFrame, "ValueText")
	self.sellDetailsProfitText = FindOptionalText(self.sellDetailsFrame, "ProfitText")
	self.sellDetailsIcon = self.sellDetailsFrame and self.sellDetailsFrame:FindFirstChild("Icon", true) or nil
	local FrameBar = FindOptionalFrame(self.sellDetailsFrame, "FrameBar")
	self.sellDetailsProgressBar = FrameBar and FrameBar:FindFirstChild("Bar", true) or nil
	self.activePage = "Home"
	self.isOpen = false
	self.navButtonDefaults = {}
	self.indexEntries = {}
	self.indexUnlockedByObject = {}
	self.hasLoadedIndexEntries = false
	self.restoredItems = {}
	self.selectedRestoredItemId = nil
	self.hoverHighlight = Instance.new("Highlight")
	self.hoverHighlight.Name = "ComputerHoverHighlight"
	self.hoverHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	self.hoverHighlight.FillColor = HighlightFillcolor
	self.hoverHighlight.FillTransparency = 1
	self.hoverHighlight.OutlineColor = HighlightOutlinecolor
	self.hoverHighlight.OutlineTransparency = 0
	self.hoverHighlight.Enabled = false
	self.hoverHighlight.Parent = Workspace
	self.cashTextScale = self.cashText and EnsureScale(self.cashText) or nil
	self.baseComputerCashTextColor = self.cashText and self.cashText.TextColor3 or Color3.new(1, 1, 1)
	self.baseDailyProfitTextColor = self.dailyProfitText and self.dailyProfitText.TextColor3 or Color3.new(1, 1, 1)
	self.sellDetailBaseProfitTextColor = self.sellDetailsProfitText and self.sellDetailsProfitText.TextColor3 or Color3.new(1, 1, 1)
	self.computerCashAnimationId = 0

	self.surfaceGui.Enabled = true
	self.frame.Visible = false
	self.indexTemplate.Visible = false
	self.sellTemplate.Visible = false
	for _, Button in ipairs({ self.homeButton, self.indexButton, self.sellNavButton }) do
		local Stroke = Button:FindFirstChildOfClass("UIStroke")
		local Texts = {}
		local TextColors = {}
		local Images = {}
		local ImageColors = {}

		for _, Descendant in ipairs(Button:GetDescendants()) do
			if Descendant:IsA("TextLabel") or Descendant:IsA("TextButton") or Descendant:IsA("TextBox") then
				table.insert(Texts, Descendant)
				TextColors[Descendant] = Descendant.TextColor3
			elseif Descendant:IsA("ImageLabel") or Descendant:IsA("ImageButton") then
				table.insert(Images, Descendant)
				ImageColors[Descendant] = Descendant.ImageColor3
			end
		end

		self.navButtonDefaults[Button] = {
			BackgroundColor3 = Button.BackgroundColor3,
			Stroke = Stroke,
			StrokeTransparency = Stroke and Stroke.Transparency or 0,
			Texts = Texts,
			TextColors = TextColors,
			Images = Images,
			ImageColors = ImageColors,
		}
	end

	AnimateButton(self.exitButton, function()
		return false
	end)
	AnimateButton(self.homeButton, function()
		return self.activePage == "Home"
	end)
	AnimateButton(self.indexButton, function()
		return self.activePage == "Index"
	end)
	AnimateButton(self.sellNavButton, function()
		return self.activePage == "Sell"
	end)
	if self.sellItemButton then
		AnimateButton(self.sellItemButton, function()
			return false
		end)
	end
	if self.sellAllButton then
		AnimateButton(self.sellAllButton, function()
			return false
		end)
	end
	self.homeFrame.Visible = false
	self.indexFrame.Visible = false
	self.sellFrame.Visible = false
	self:SetPage("Home")
	self:SyncHeader()
	self:SetDisplayedComputerCash(Remotemanager:InvokeServer("CashService", "GetCash"))
	self:SetHudVisible(true)
	self:ApplyStats(Remotemanager:InvokeServer("StatsService", "GetStats"))
	self:ApplyIndexEntries(Remotemanager:InvokeServer("InventoryService", "GetIndexEntries"))
	self:ApplyRestoredItems(Remotemanager:InvokeServer("InventoryService", "GetRestoredItems"))
end

function Computercontroller:Start()
	self.indexGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		local ContentSize = self.indexGridLayout.AbsoluteContentSize
		self.indexScrollingFrame.CanvasSize = UDim2.fromOffset(0, ContentSize.Y)
	end)

	self.sellGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		local ContentSize = self.sellGridLayout.AbsoluteContentSize
		self.sellScrollingFrame.CanvasSize = UDim2.fromOffset(0, ContentSize.Y)
	end)

	Runservice.RenderStepped:Connect(function()
		if self:IsOpen() then
			self:SyncHeader()
		end
		self:UpdateHoveredComputer()
	end)

	Remotemanager:OnClientEvent("StatsService", "StatsUpdated", function(Stats)
		self:ApplyStats(Stats)
	end)

	Remotemanager:OnClientEvent("InventoryService", "RestoredItemsUpdated", function(Items)
		self:ApplyRestoredItems(Items)
	end)

	Remotemanager:OnClientEvent("InventoryService", "IndexUpdated", function(Entries)
		self:ApplyIndexEntries(Entries)
	end)

	Remotemanager:OnClientEvent("CashService", "CashUpdated", function(Value)
		self:AnimateComputerCashTo(Value)
	end)

	Userinputservice.InputBegan:Connect(function(Input, Processed)
		if Processed or not self:CanOpen() then
			return
		end
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if not self.hoveredComputer then
			return
		end

		self:Open()
	end)

	self.exitButton.Activated:Connect(function()
		self:Close()
	end)

	self.homeButton.Activated:Connect(function()
		self:SetPage("Home")
	end)

	self.indexButton.Activated:Connect(function()
		self:SetPage("Index")
	end)

	self.sellNavButton.Activated:Connect(function()
		self:SetPage("Sell")
	end)

	if self.sellItemButton then
		self.sellItemButton.Activated:Connect(function()
			if not self.selectedRestoredItemId then
				return
			end
			local SoldItem = Remotemanager:InvokeServer("InventoryService", "SellRestoredItem", self.selectedRestoredItemId)
			if SoldItem then
				self.selectedRestoredItemId = nil
			end
		end)
	end

	if self.sellAllButton then
		self.sellAllButton.Activated:Connect(function()
			Remotemanager:InvokeServer("InventoryService", "SellAllRestoredItems")
			self.selectedRestoredItemId = nil
		end)
	end
end

return Computercontroller
