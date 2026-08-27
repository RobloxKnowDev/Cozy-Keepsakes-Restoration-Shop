local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Tweenservice = game:GetService("TweenService")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Rarityconfig = require(Replicatedstorage.Shared.Config.Rarity)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.ComputerController.Apps.Shared)

local Controller = {
	Name = "ExpositionController",
	Priority = 6,
}

type BlockerMode = "Disabled" | "Hidden"

local Buttontweeninfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Buttonhidetweeninfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local Buttonshowtweeninfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local Selectframeshowtweeninfo = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local Selectframehidetweeninfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local Fastselectframehidetweeninfo = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local Detailstweeninfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ErrorMessageColor = Color3.fromRGB(255, 92, 92)
local ReputationMessageColor = Color3.fromRGB(126, 255, 145)
local ReputationLossMessageColor = Color3.fromRGB(255, 138, 138)

local function FormatReputation(Value: number): string
	local Rounded = math.round(Value * 100) / 100
	if math.abs(Rounded - math.round(Rounded)) < 0.005 then return tostring(math.round(Rounded)) end
	return string.format("%.2f", Rounded)
end

function Controller:IsOpen(): boolean
	return self.isOpen
end

function Controller:IsSelectionOpen(): boolean
	return self.selectFrame.Visible
end

function Controller:GetBaseReputation(Item): number
	return math.round(math.max(tonumber(Item.Reputation) or 0, 0) * 100) / 100
end

function Controller:TweenButton(Button: GuiButton, Info: TweenInfo, ScaleValue: number): Tween
	local Currenttween = self.buttonTweens[Button]
	if Currenttween then Currenttween:Cancel() end
	local Tween = Tweenservice:Create(self.buttonScales[Button], Info, { Scale = ScaleValue })
	self.buttonTweens[Button] = Tween
	Tween:Play()
	return Tween
end

function Controller:ResetButton(Button: GuiButton)
	local Currenttween = self.buttonTweens[Button]
	if Currenttween then Currenttween:Cancel() end
	self.buttonTweens[Button] = nil
	self.buttonScales[Button].Scale = 1
	self.hoveredButtons[Button] = false
end

function Controller:RestoreButtonHover(Button: GuiButton)
	if Button.Active and self.hoveredButtons[Button] then
		self:TweenButton(Button, Buttontweeninfo, 1.06)
	end
end

function Controller:HideSlotButtons()
	self.slotsVisible = false
	for _, Slot in ipairs(self.slotButtons) do
		self:ResetButton(Slot.Button)
		Slot.Button.Visible = false
		Slot.Button.Active = false
		Slot.Button.Interactable = false
	end
end

function Controller:ShowSlotButtons()
	if self.slotsVisible then return end
	self.slotsVisible = true
	for _, Slot in ipairs(self.slotButtons) do
		Slot.Button.Visible = true
		self.buttonScales[Slot.Button].Scale = 0.82
		local Showtween = self:TweenButton(Slot.Button, Buttonshowtweeninfo, 1)
		Showtween.Completed:Once(function(State)
			if State == Enum.PlaybackState.Completed then self:RestoreButtonHover(Slot.Button) end
		end)
	end
	self:UpdateButtonAvailability()
end

function Controller:RefreshSlotButtons()
	if self.isOpen and self.slotsRevealReached and self.blockerMode ~= "Hidden" then
		self:ShowSlotButtons()
	else
		self:HideSlotButtons()
	end
end

function Controller:AnimateSlotChange(Slot)
	if not Slot.Button.Visible then return end
	self.buttonScales[Slot.Button].Scale = 0.82
	local Showtween = self:TweenButton(Slot.Button, Buttonshowtweeninfo, 1)
	Showtween.Completed:Once(function(State)
		if State == Enum.PlaybackState.Completed then self:RestoreButtonHover(Slot.Button) end
	end)
end

function Controller:ResolveBlockerMode(): BlockerMode?
	local Mode: BlockerMode? = nil
	for _, Blocker in pairs(self.blockers) do
		if Blocker == "Hidden" then return "Hidden" end
		Mode = "Disabled"
	end
	return Mode
end

function Controller:CanUseButtons(): boolean
	if self.blockerMode ~= nil or self.isTransitioning then return false end
	return self.isOpen or self.cameraController:IsIntroCameraReady()
end

function Controller:CanUseSelectionSlot(Slot): boolean
	if self.blockers.Selection ~= "Disabled"
		or not self.selectFrameOpen
		or self.selectPlacementPending
		or self.selectedSlotIndex ~= Slot.Index
		or not self.isOpen
		or self.isTransitioning
		or not Slot.Button.Visible
	then
		return false
	end
	for Source, Mode in pairs(self.blockers) do
		if Source ~= "Selection" and Mode ~= nil then return false end
	end
	return true
end

function Controller:UpdateButtonAvailability()
	if self.isTransitioning then return end
	local Currentbutton = if self.isOpen then self.reputationButtonL else self.reputationButtonR
	local Canuse = self:CanUseButtons()
	for _, Button in ipairs({ self.reputationButtonL, self.reputationButtonR }) do
		local Enabled = Canuse and Button == Currentbutton and Button.Visible
		Button.Active = Enabled
		Button.Interactable = Enabled
	end
	if not Canuse and self.hoveredButtons[Currentbutton] then
		self.hoveredButtons[Currentbutton] = false
		self:TweenButton(Currentbutton, Buttontweeninfo, 1)
	end
	for _, Slot in ipairs(self.slotButtons) do
		local Enabled = Slot.Button.Visible and ((Canuse and self.isOpen) or self:CanUseSelectionSlot(Slot))
		local Preservehover = not self.selectFrameOpen
			and self.blockers.Selection == "Disabled"
			and self.selectedSlotIndex == Slot.Index
		Slot.Button.Active = Enabled
		Slot.Button.Interactable = Enabled
		if not Enabled and self.hoveredButtons[Slot.Button] then
			if not Preservehover then self.hoveredButtons[Slot.Button] = false end
			self:TweenButton(Slot.Button, Buttontweeninfo, 1)
		end
	end
end

function Controller:RefreshButtons()
	local Mode = self:ResolveBlockerMode()
	if self.blockerMode == Mode then
		self:UpdateButtonAvailability()
		return
	end
	local Previousmode = self.blockerMode
	self.blockerMode = Mode
	self.transitionVersion += 1
	self.isTransitioning = false
	for _, Button in ipairs({ self.reputationButtonL, self.reputationButtonR }) do
		self:ResetButton(Button)
		Button.Visible = false
		Button.Active = false
		Button.Interactable = false
	end
	if Mode == "Hidden" then
		self:HideSlotButtons()
		return
	end

	local Button = if self.isOpen then self.reputationButtonL else self.reputationButtonR
	Button.Visible = true
	if Previousmode == "Hidden" then
		self.buttonScales[Button].Scale = 0.82
		local Showtween = self:TweenButton(Button, Buttonshowtweeninfo, 1)
		Showtween.Completed:Once(function(State)
			if State == Enum.PlaybackState.Completed then self:RestoreButtonHover(Button) end
		end)
	end
	self:RefreshSlotButtons()
	self:UpdateButtonAvailability()
end

function Controller:SetBlocker(Source: string, Mode: BlockerMode?)
	if self.blockers[Source] == Mode then return end
	if Mode == "Hidden" and Source ~= "Selection" and self.selectFrame.Visible then
		self:CloseSelectionFrame(true)
	end
	self.blockers[Source] = Mode
	self:RefreshButtons()
end

function Controller:SyncFrameBlockers()
	self:SetBlocker("Computer", if self.computerController:IsOpen() then "Hidden" else nil)
	self:SetBlocker("Customer", if self.customerController:IsVisible() then "Disabled" else nil)
	self:SetBlocker("Completion", if self.completionController:IsVisible() then "Disabled" else nil)
end

function Controller:CloseTopbarFrames()
	self.dailyRewardController:CloseForSwitch()
	self.settingController:CloseForSwitch()
end

function Controller:SetSelectionControlsEnabled(Enabled: boolean)
	local Canselect = Enabled and self.selectedDisplayItemId ~= nil
	self.selectCloseButton.Active = Enabled
	self.selectCloseButton.Interactable = Enabled
	self.selectDetailsSelectButton.Active = Canselect
	self.selectDetailsSelectButton.Interactable = Canselect
	self.selectDetailsSelectButton.AutoButtonColor = Canselect
	for _, Card in ipairs(self.selectCards) do
		Card.Button.Active = Enabled
		Card.Button.Interactable = Enabled
		Card.SelectButton.Active = Enabled
		Card.SelectButton.Interactable = Enabled
	end
end

function Controller:ShowSelectionDetails(Item, Animate: boolean?)
	if self.selectProgressTween then self.selectProgressTween:Cancel() end
	if not Item then
		self.selectedDisplayItemId = nil
		self.selectDetailsNameText.Text = "No item selected"
		self.selectDetailsRarityText.Text = "-"
		self.selectDetailsRarityText.TextColor3 = Color3.fromRGB(255, 255, 255)
		self.selectDetailsRestorationText.Text = "0%"
		self.selectDetailsValueText.Text = "$0"
		self.selectDetailsReputationText.Text = "0"
		self.selectDetailsIcon.Image = ""
		self.selectDetailsProgressBar.Size = UDim2.fromScale(0, 1)
		self.selectDetailsScale.Scale = 1
		self:SetSelectionControlsEnabled(self.selectFrameOpen and not self.selectPlacementPending)
		return
	end

	self.selectedDisplayItemId = Item.Id
	local Rarity = Rarityconfig[tostring(Item.Rarity or "Common")]
	self.selectDetailsNameText.Text = tostring(Item.Name or "")
	self.selectDetailsRarityText.Text = Rarity.Name
	self.selectDetailsRarityText.TextColor3 = Rarity.Color
	self.selectDetailsRestorationText.Text = string.format("%d%%", Item.RestorationPercent or 0)
	self.selectDetailsValueText.Text = Shared.FormatCurrency(Item.CurrentValue or 0)
	self.selectDetailsReputationText.Text = "+" .. FormatReputation(self:GetBaseReputation(Item))
	self.selectDetailsIcon.Image = tostring(Item.ImageId or "")
	local Targetsize = UDim2.fromScale(math.clamp((Item.RestorationPercent or 0) / 100, 0, 1), 1)
	self.selectProgressTween = Tweenservice:Create(self.selectDetailsProgressBar, Detailstweeninfo, { Size = Targetsize })
	self.selectProgressTween:Play()
	if Animate then
		self.selectDetailsScale.Scale = 0.96
		Tweenservice:Create(self.selectDetailsScale, Detailstweeninfo, { Scale = 1 }):Play()
	end
	self:SetSelectionControlsEnabled(self.selectFrameOpen and not self.selectPlacementPending)
end

function Controller:ApplySelectionItems(Items)
	local Sorteditems = {}
	for _, Item in ipairs(Items or {}) do table.insert(Sorteditems, Item) end
	table.sort(Sorteditems, function(Left, Right)
		local Leftreputation = self:GetBaseReputation(Left)
		local Rightreputation = self:GetBaseReputation(Right)
		if Leftreputation == Rightreputation then return (tonumber(Left.Id) or 0) > (tonumber(Right.Id) or 0) end
		return Leftreputation > Rightreputation
	end)
	self.selectItems = Sorteditems
	for _, Child in ipairs(self.selectScrollingFrame:GetChildren()) do
		if Child ~= self.selectTemplate and Child ~= self.selectGridLayout then Child:Destroy() end
	end
	table.clear(self.selectCards)

	local Selecteditem
	for Order, Item in ipairs(Sorteditems) do
		local Card = self.selectTemplate:Clone()
		Card.Name = "Item_" .. tostring(Item.Id)
		Card.LayoutOrder = Order
		Card.Visible = true
		Card.Parent = self.selectScrollingFrame
		local Button = Card:WaitForChild("Button") :: GuiButton
		local Selectbutton = Button:WaitForChild("SelectButton") :: GuiButton
		Button:WaitForChild("NameText").Text = tostring(Item.Name or "")
		Button:WaitForChild("ReputationText").Text = "+" .. FormatReputation(self:GetBaseReputation(Item)) .. " Reputation"
		Button:WaitForChild("Icon").Image = tostring(Item.ImageId or "")
		local Carddata = { Button = Button, SelectButton = Selectbutton }
		table.insert(self.selectCards, Carddata)
		Shared.AnimateButton(Button, function() return not Button.Active end)
		Shared.AnimateButton(Selectbutton, function() return not Selectbutton.Active end)
		Button.Activated:Connect(function() self:ShowSelectionDetails(Item, true) end)
		Selectbutton.Activated:Connect(function() self:PlaceDisplayItem(Item.Id) end)
		if self.selectedDisplayItemId == Item.Id then Selecteditem = Item end
	end
	self:ShowSelectionDetails(Selecteditem, false)
	self:SetSelectionControlsEnabled(self.selectFrameOpen and not self.selectPlacementPending)
	task.defer(function()
		self.selectScrollingFrame.CanvasSize = UDim2.fromOffset(0, self.selectGridLayout.AbsoluteContentSize.Y)
	end)
end

function Controller:ApplyDisplayItems(State, Keepselectionopen: boolean?)
	if State.Revision < self.displayItemsRevision then return end
	self.displayItemsRevision = State.Revision
	table.clear(self.displayItemsBySlot)
	for _, Item in ipairs(State.Items) do
		self.displayItemsBySlot[Item.SlotIndex] = Item
	end

	for _, Slot in ipairs(self.slotButtons) do
		local Previousoccupied = Slot.Occupied
		local Previousowned = Slot.Owned
		local Displayitem = self.displayItemsBySlot[Slot.Index]
		Slot.Occupied = Displayitem ~= nil
		Slot.Owned = Displayitem ~= nil and Displayitem.OwnerUserId == Players.LocalPlayer.UserId
		Slot.Text.Text = if Slot.Occupied then "x" else "+"
		local Canremove = Slot.Occupied and Slot.Owned
		Slot.Icon.Visible = not Slot.Unlocked and not Canremove
		Slot.Text.Visible = Slot.Unlocked or Canremove
		if Slot.Occupied ~= Previousoccupied and (Slot.Unlocked or Slot.Owned or Previousowned) then self:AnimateSlotChange(Slot) end
	end
	if not Keepselectionopen
		and self.selectFrameOpen
		and not self.selectPlacementPending
		and self.selectedSlotIndex
		and self.displayItemsBySlot[self.selectedSlotIndex]
	then
		self:CloseSelectionFrame(false)
	end

end

function Controller:SetSelectionFramePosition(SlotIndex: number)
	local Xscale = if SlotIndex % 3 == 0 then 0.25 else 0.75
	local Position = self.selectFrameBasePosition
	self.selectFrame.Position = UDim2.new(Xscale, Position.X.Offset, Position.Y.Scale, Position.Y.Offset)
end

function Controller:OpenSelectionFrame(SlotIndex: number)
	self:CloseTopbarFrames()
	if self.selectFrameOpen or self.blockerMode ~= nil then return end
	self.selectionRequestId += 1
	self.selectFrameAnimationId += 1
	if self.selectFrameTween then self.selectFrameTween:Cancel() end
	self.selectedSlotIndex = SlotIndex
	self.selectedDisplayItemId = nil
	self.selectPlacementPending = false
	self.selectFrameOpen = true
	self:SetSelectionFramePosition(SlotIndex)
	self.selectScrollingFrame.CanvasPosition = Vector2.zero
	self:ShowSelectionDetails(nil, false)
	self.selectFrame.Visible = true
	self.selectFrameScale.Scale = 0.9
	self:SetSelectionControlsEnabled(true)
	self:SetBlocker("Selection", "Disabled")
	self.selectFrameTween = Tweenservice:Create(self.selectFrameScale, Selectframeshowtweeninfo, { Scale = 1 })
	self.selectFrameTween:Play()
end

function Controller:CloseSelectionFrame(Instant: boolean?, Fast: boolean?)
	if not self.selectFrame.Visible then return end
	self.selectionRequestId += 1
	self.selectFrameAnimationId += 1
	local Animationid = self.selectFrameAnimationId
	local Slot = if self.selectedSlotIndex then self.slotButtons[self.selectedSlotIndex] else nil
	if self.selectFrameTween then self.selectFrameTween:Cancel() end
	self.selectFrameOpen = false
	self.selectPlacementPending = false
	self:SetSelectionControlsEnabled(false)
	self:ShowSelectionDetails(nil, false)
	self:UpdateButtonAvailability()
	if Instant then
		self.selectFrame.Visible = false
		self.selectFrameScale.Scale = 1
		self.selectedSlotIndex = nil
		self:SetBlocker("Selection", nil)
		if Slot then self:RestoreButtonHover(Slot.Button) end
		return
	end
	local Tweeninfo = if Fast then Fastselectframehidetweeninfo else Selectframehidetweeninfo
	self.selectFrameTween = Tweenservice:Create(self.selectFrameScale, Tweeninfo, { Scale = 0.9 })
	self.selectFrameTween:Play()
	self.selectFrameTween.Completed:Once(function(State)
		if State ~= Enum.PlaybackState.Completed or self.selectFrameAnimationId ~= Animationid then return end
		self.selectFrame.Visible = false
		self.selectFrameScale.Scale = 1
		self.selectedSlotIndex = nil
		self:SetBlocker("Selection", nil)
		if Slot then self:RestoreButtonHover(Slot.Button) end
	end)
end

function Controller:PlaceDisplayItem(ItemId: number)
	if not self.selectFrameOpen or self.selectPlacementPending or not self.selectedSlotIndex then return end
	local Requestid = self.selectionRequestId
	local Slotindex = self.selectedSlotIndex
	self.selectPlacementPending = true
	self:SetSelectionControlsEnabled(false)
	self:UpdateButtonAvailability()
	local Success, Response = pcall(function()
		return Remotemanager:InvokeServer("ExpositionService", "PlaceDisplayItem", Slotindex, ItemId)
	end)
	local Iscurrentrequest = self.selectionRequestId == Requestid
	if Iscurrentrequest then
		self.selectPlacementPending = false
		self:UpdateButtonAvailability()
	end
	if not Iscurrentrequest or not self.selectFrameOpen or self.selectedSlotIndex ~= Slotindex then return end
	if not Success then
		self:SetSelectionControlsEnabled(true)
		Core:GetController("MessageController"):Show("Unable to display this item", ErrorMessageColor)
		return
	end
	if type(Response) == "table" and Response.Success == true then
		if type(Response.DisplayItems) == "table" then self:ApplyDisplayItems(Response.DisplayItems, true) end
		local Grantedreputation = tonumber(Response.GrantedReputation) or 0
		local Message = if Grantedreputation > 0
			then "+" .. FormatReputation(Grantedreputation) .. " Reputation"
			else "Item added to display"
		Core:GetController("MessageController"):Show(Message, ReputationMessageColor)
		self:CloseSelectionFrame(false)
		return
	end
	self:SetSelectionControlsEnabled(true)
	local Reason = type(Response) == "table" and Response.Reason or "PlacementFailed"
	if Reason == "SlotOccupied" then self:CloseSelectionFrame(false) end
	local Message = if Reason == "SlotOccupied"
		then "This display slot is already occupied"
		elseif Reason == "SlotLocked"
		then "Upgrade Display Space to unlock this slot"
		elseif Reason == "ItemUnavailable"
		then "This item is no longer available"
		else "Unable to display this item"
	Core:GetController("MessageController"):Show(Message, ErrorMessageColor)
end

function Controller:RemoveDisplayItem(Slotindex: number)
	if self.displayActionPending then return end
	local Slot = self.slotButtons[Slotindex]
	if not Slot.Owned then
		Core:GetController("MessageController"):Show("This display item belongs to another player", ErrorMessageColor)
		return
	end

	self.displayActionPending = true
	self:SetBlocker("DisplayAction", "Disabled")
	local Success, Response = pcall(function()
		return Remotemanager:InvokeServer("ExpositionService", "RemoveDisplayItem", Slotindex)
	end)
	self.displayActionPending = false
	if Success and type(Response) == "table" and Response.Success == true then
		if type(Response.DisplayItems) == "table" then self:ApplyDisplayItems(Response.DisplayItems) end
		self:SetBlocker("DisplayAction", nil)
		local Removedreputation = tonumber(Response.RemovedReputation) or 0
		local Message = if Removedreputation > 0
			then "-" .. FormatReputation(Removedreputation) .. " Reputation"
			else "Item returned to inventory"
		local Color = if Removedreputation > 0 then ReputationLossMessageColor else ReputationMessageColor
		Core:GetController("MessageController"):Show(Message, Color)
		return
	end

	self:SetBlocker("DisplayAction", nil)
	local Reason = if Success and type(Response) == "table" then Response.Reason else "RemovalFailed"
	local Message = if Reason == "SlotEmpty"
		then "This display slot is already empty"
		elseif Reason == "NotOwner"
		then "This display item belongs to another player"
		elseif Reason == "Busy"
		then "Please wait before changing this display slot"
		else "Unable to return this item to inventory"
	Core:GetController("MessageController"):Show(Message, ErrorMessageColor)
end

function Controller:BindButtonAnimation(Button: GuiButton)
	Button.MouseEnter:Connect(function()
		self.hoveredButtons[Button] = true
		if not Button.Active then return end
		self:TweenButton(Button, Buttontweeninfo, 1.06)
	end)
	Button.MouseLeave:Connect(function()
		self.hoveredButtons[Button] = false
		if self.isTransitioning or not Button.Active then return end
		self:TweenButton(Button, Buttontweeninfo, 1)
	end)
	Button.MouseButton1Down:Connect(function()
		self:CloseTopbarFrames()
		if not Button.Active then return end
		self:TweenButton(Button, Buttontweeninfo, 0.96)
	end)
	Button.MouseButton1Up:Connect(function()
		if not Button.Active then return end
		self:TweenButton(Button, Buttontweeninfo, if self.hoveredButtons[Button] then 1.06 else 1)
	end)
end

function Controller:SwapButtons(ButtonToHide: GuiButton, ButtonToShow: GuiButton)
	self.transitionVersion += 1
	local Version = self.transitionVersion
	self.isTransitioning = true
	self.reputationButtonL.Active = false
	self.reputationButtonL.Interactable = false
	self.reputationButtonR.Active = false
	self.reputationButtonR.Interactable = false

	local Hidescale = self.buttonScales[ButtonToHide]
	local Showscale = self.buttonScales[ButtonToShow]
	local Hidetween = self:TweenButton(ButtonToHide, Buttonhidetweeninfo, 0.82)
	Hidetween.Completed:Once(function(State)
		if State ~= Enum.PlaybackState.Completed or self.transitionVersion ~= Version then return end
		ButtonToHide.Visible = false
		Hidescale.Scale = 1
		self.hoveredButtons[ButtonToHide] = false
		ButtonToShow.Visible = true
		Showscale.Scale = 0.82
		local Showtween = self:TweenButton(ButtonToShow, Buttonshowtweeninfo, 1)
		Showtween.Completed:Once(function(Showstate)
			if Showstate ~= Enum.PlaybackState.Completed or self.transitionVersion ~= Version then return end
			Showscale.Scale = 1
			self.isTransitioning = false
			self:UpdateButtonAvailability()
			self:RestoreButtonHover(ButtonToShow)
			for _, Slot in ipairs(self.slotButtons) do
				self:RestoreButtonHover(Slot.Button)
			end
		end)
	end)
end

function Controller:Open()
	self:CloseTopbarFrames()
	self:SyncFrameBlockers()
	if self.isOpen or not self:CanUseButtons() then return end
	self.expositionRequestId += 1
	local RequestId = self.expositionRequestId
	self.slotsRevealReached = false
	self:HideSlotButtons()
	local function RevealSlots()
		if self.expositionRequestId ~= RequestId or self.slotsRevealReached then return end
		self.slotsRevealReached = true
		self:RefreshSlotButtons()
	end
	if not self.cameraController:ShowExpositionCamera(RevealSlots, RevealSlots) then return end
	self.isOpen = true
	self:SwapButtons(self.reputationButtonR, self.reputationButtonL)
end

function Controller:Close()
	self:SyncFrameBlockers()
	if not self.isOpen or not self:CanUseButtons() then return end
	if not self.cameraController:ShowIntroCameraFromExposition() then return end
	self.expositionRequestId += 1
	self.slotsRevealReached = false
	self.isOpen = false
	self:HideSlotButtons()
	self:SwapButtons(self.reputationButtonL, self.reputationButtonR)
end

function Controller:PrepareForRestoration()
	if self.restorationPrepared then return end
	self:CloseSelectionFrame(true)
	self.restorationPrepared = true
	self.wasOpenBeforeRestoration = self.isOpen
	self.isOpen = false
	self:SetBlocker("Restoration", "Hidden")
end

function Controller:CancelRestoration()
	if not self.restorationPrepared then return end
	self.restorationPrepared = false
	self.isOpen = self.wasOpenBeforeRestoration == true
	self.wasOpenBeforeRestoration = nil
	self:SetBlocker("Restoration", nil)
end

function Controller:CompleteRestoration()
	self.restorationPrepared = false
	self.wasOpenBeforeRestoration = nil
	self.expositionRequestId += 1
	self.slotsRevealReached = false
	self.isOpen = false
	self:HideSlotButtons()
	self:SetBlocker("Restoration", nil)
end

function Controller:ApplyUpgradeState(State)
	local Level = math.clamp(math.floor(State.DisplaySpace.CurrentValue), 0, #self.slotButtons)
	self.displaySpaceLevel = Level
	for _, Slot in ipairs(self.slotButtons) do
		local Wasunlocked = Slot.Unlocked
		Slot.Unlocked = Slot.Index <= Level
		local Canremove = Slot.Occupied and Slot.Owned
		Slot.Icon.Visible = not Slot.Unlocked and not Canremove
		Slot.Text.Visible = Slot.Unlocked or Canremove
		if Slot.Unlocked and not Wasunlocked and Slot.Button.Visible then
			self.buttonScales[Slot.Button].Scale = 0.82
			local Showtween = self:TweenButton(Slot.Button, Buttonshowtweeninfo, 1)
			Showtween.Completed:Once(function(State)
				if State == Enum.PlaybackState.Completed then self:RestoreButtonHover(Slot.Button) end
			end)
		end
	end
	if self.selectFrameOpen and self.selectedSlotIndex and self.selectedSlotIndex > Level then
		self:CloseSelectionFrame(true)
	end
	self:UpdateButtonAvailability()
end

function Controller:Init()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local Hud = Playergui:WaitForChild("HUD")
	local Reputationfolder = Hud:WaitForChild("ReputationFolder")
	local Expositionui = Playergui:WaitForChild("ExpositionUi") :: ScreenGui
	local Slotsfolder = Expositionui:WaitForChild("SlotsButton")
	local Selectframe = Expositionui:WaitForChild("SelectFrame") :: Frame
	local Selectscrollingframe = Selectframe:WaitForChild("ScrollingFrame") :: ScrollingFrame
	local Selectdetailsframe = Selectframe:WaitForChild("StatsFrame") :: Frame
	Expositionui.Enabled = true
	self.reputationButtonL = Reputationfolder:WaitForChild("ReputationButtonL") :: GuiButton
	self.reputationButtonR = Reputationfolder:WaitForChild("ReputationButtonR") :: GuiButton
	self.selectFrame = Selectframe
	self.selectFrameBasePosition = Selectframe.Position
	self.selectFrameScale = Shared.EnsureScale(Selectframe)
	self.selectScrollingFrame = Selectscrollingframe
	self.selectGridLayout = Selectscrollingframe:WaitForChild("UIGridLayout") :: UIGridLayout
	self.selectTemplate = Selectscrollingframe:WaitForChild("Template") :: GuiObject
	self.selectDetailsFrame = Selectdetailsframe
	self.selectDetailsScale = Shared.EnsureScale(Selectdetailsframe)
	self.selectDetailsSelectButton = Selectdetailsframe:WaitForChild("SelectButton") :: GuiButton
	self.selectDetailsIcon = Selectdetailsframe:WaitForChild("Icon") :: ImageLabel
	self.selectDetailsNameText = Selectdetailsframe:WaitForChild("NameText") :: TextLabel
	self.selectDetailsRarityText = Selectdetailsframe:WaitForChild("RarityText") :: TextLabel
	self.selectDetailsRestorationText = Selectdetailsframe:WaitForChild("RestorationText") :: TextLabel
	self.selectDetailsValueText = Selectdetailsframe:WaitForChild("ValueText") :: TextLabel
	self.selectDetailsReputationText = Selectdetailsframe:WaitForChild("ReputationText") :: TextLabel
	self.selectDetailsProgressBar = Selectdetailsframe:WaitForChild("FrameBar"):WaitForChild("Bar") :: GuiObject
	self.selectCloseButton = Selectframe:WaitForChild("CloseButton") :: GuiButton
	self.buttonScales = {}
	self.buttonTweens = {}
	self.hoveredButtons = {}
	self.slotButtons = {}
	self.animatedButtons = { self.reputationButtonL, self.reputationButtonR }
	self.selectCards = {}
	self.selectItems = {}
	self.displayItemsBySlot = {}
	self.displayItemsRevision = -1
	self.blockers = {}
	self.blockerMode = nil
	self.displaySpaceLevel = 0
	self.slotsVisible = false
	self.slotsRevealReached = false
	self.expositionRequestId = 0
	self.selectFrameOpen = false
	self.selectPlacementPending = false
	self.displayActionPending = false
	self.selectFrameAnimationId = 0
	self.selectionRequestId = 0
	self.selectedSlotIndex = nil
	self.selectedDisplayItemId = nil
	self.isOpen = false
	self.isTransitioning = false
	self.restorationPrepared = false
	self.transitionVersion = 0

	for Index = 1, 9 do
		local Button = Slotsfolder:WaitForChild("Button" .. Index) :: GuiButton
		local Slot = {
			Index = Index,
			Button = Button,
			Icon = Button:WaitForChild("Icon") :: GuiObject,
			Text = Button:WaitForChild("Text") :: TextLabel,
			Unlocked = false,
			Occupied = false,
			Owned = false,
		}
		Slot.Icon.Visible = true
		Slot.Text.Text = "+"
		Slot.Text.Visible = false
		Button.Visible = false
		Button.Active = false
		Button.Interactable = false
		table.insert(self.slotButtons, Slot)
		table.insert(self.animatedButtons, Button)
	end

	for _, Button in ipairs(self.animatedButtons) do
		local Scale = Instance.new("UIScale")
		Scale.Name = "ExpositionScale"
		Scale.Parent = Button
		self.buttonScales[Button] = Scale
		self.hoveredButtons[Button] = false
	end

	self.reputationButtonL.Visible = false
	self.reputationButtonL.Active = false
	self.reputationButtonL.Interactable = false
	self.reputationButtonR.Visible = true
	self.reputationButtonR.Active = false
	self.reputationButtonR.Interactable = false
	self.selectGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	self.selectTemplate.Visible = false
	self.selectFrame.Visible = false
	self.selectFrameScale.Scale = 1
	self:ShowSelectionDetails(nil, false)
end

function Controller:Start()
	self.cameraController = Core:GetController("InspectionCameraController")
	self.computerController = Core:GetController("ComputerController")
	self.customerController = Core:GetController("CustomerController")
	self.dailyRewardController = Core:GetController("DailyRewardController")
	self.settingController = Core:GetController("SettingController")
	self.completionController = Core:GetController("CompletionController")
	for _, Button in ipairs(self.animatedButtons) do self:BindButtonAnimation(Button) end
	Shared.AnimateButton(self.selectCloseButton, function() return not self.selectCloseButton.Active end)
	Shared.AnimateButton(self.selectDetailsSelectButton, function() return not self.selectDetailsSelectButton.Active end)
	self.reputationButtonR.Activated:Connect(function() self:Open() end)
	self.reputationButtonL.Activated:Connect(function() self:Close() end)
	self.selectCloseButton.Activated:Connect(function() self:CloseSelectionFrame(false) end)
	self.selectDetailsSelectButton.Activated:Connect(function()
		if self.selectedDisplayItemId then self:PlaceDisplayItem(self.selectedDisplayItemId) end
	end)
	for _, Slot in ipairs(self.slotButtons) do
		Slot.Button.Activated:Connect(function()
			self:SyncFrameBlockers()
			if not Slot.Button.Active then return end
			if self.selectFrameOpen and self.selectedSlotIndex == Slot.Index then
				self:CloseSelectionFrame(false)
				return
			end
			if not Slot.Unlocked and not Slot.Owned then
				Core:GetController("MessageController"):Show("Upgrade Display Space to unlock more slots", ErrorMessageColor)
				return
			end
			if Slot.Occupied then
				self:RemoveDisplayItem(Slot.Index)
				return
			end
			self:OpenSelectionFrame(Slot.Index)
		end)
	end
	self.selectGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.selectScrollingFrame.CanvasSize = UDim2.fromOffset(0, self.selectGridLayout.AbsoluteContentSize.Y)
	end)
	Remotemanager:OnClientEvent("InventoryService", "RestoredItemsUpdated", function(Items)
		self:ApplySelectionItems(Items)
	end)
	Remotemanager:OnClientEvent("UpgradeService", "UpgradesUpdated", function(State)
		self:ApplyUpgradeState(State)
	end)
	Remotemanager:OnClientEvent("ExpositionService", "DisplayItemsUpdated", function(State)
		self:ApplyDisplayItems(State)
	end)
	self:ApplySelectionItems(Remotemanager:InvokeServer("InventoryService", "GetRestoredItems"))
	self:ApplyUpgradeState(Remotemanager:InvokeServer("UpgradeService", "GetUpgrades"))
	self:ApplyDisplayItems(Remotemanager:InvokeServer("ExpositionService", "GetDisplayItems"))
	self:SyncFrameBlockers()
	self:UpdateButtonAvailability()
	Runservice.RenderStepped:Connect(function()
		self:SyncFrameBlockers()
		self:UpdateButtonAvailability()
	end)
end

return Controller
