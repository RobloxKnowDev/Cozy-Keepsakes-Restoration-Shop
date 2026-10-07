local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Tweenservice = game:GetService("TweenService")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Rarityconfig = require(Replicatedstorage.Shared.Config.Rarity)
local Mutationconfig = require(Replicatedstorage.Shared.Config.Mutation)
local Uigradient = require(Replicatedstorage.Shared.Utils.UiGradient)
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
local Slotrotatetweeninfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Selectframeshowtweeninfo = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local Selectframehidetweeninfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local Fastselectframehidetweeninfo = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local Detailstweeninfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ErrorMessageGradient = Rarityconfig.Mythic.Gradient
local UnknownText = "???"
local ReputationMessageGradient = Rarityconfig.Common.Gradient

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

function Controller:RotateSlotText(Slot, Animate: boolean?)
	local Currenttween = self.slotTextTweens[Slot.Text]
	if Currenttween then Currenttween:Cancel() end
	local Rotation = if Slot.Occupied then 45 else 0
	if not Animate then
		self.slotTextTweens[Slot.Text] = nil
		Slot.Text.Rotation = Rotation
		return
	end
	local Tween = Tweenservice:Create(Slot.Text, Slotrotatetweeninfo, { Rotation = Rotation })
	self.slotTextTweens[Slot.Text] = Tween
	Tween:Play()
end

function Controller:HideSlotButtons()
	self.slotsVisible = false
	for _, Slot in ipairs(self.slotButtons) do
		self:ResetButton(Slot.Button)
		self:RotateSlotText(Slot)
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
	if self.isTransitioning then return false end
	for Source, Mode in pairs(self.blockers) do
		if Source ~= "Selection" and Mode ~= nil then return false end
	end
	return self.isOpen or self.cameraController:IsIntroCameraReady()
end

function Controller:CanUseSelectionSlot(Slot): boolean
	if self.blockers.Selection ~= "Disabled"
		or not self.selectFrameOpen
		or self.selectPlacementPending
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
	local Currentbutton = if self.isOpen then self.reputationButtonR else self.reputationButtonL
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

	local Button = if self.isOpen then self.reputationButtonR else self.reputationButtonL
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
	self.donationController:CloseForSwitch()
end

function Controller:SetSelectionControlsEnabled(Enabled: boolean)
	local Cardsenabled = Enabled and not self.infoFrame.Visible
	self.selectCloseButton.Active = Enabled
	self.selectCloseButton.Interactable = Enabled
	self.infoCloseButton.Active = Enabled
	self.infoCloseButton.Interactable = Enabled
	if self.equipBestButton.Active ~= Cardsenabled then
		self.equipBestButton.Active = Cardsenabled
		self.equipBestButton.Interactable = Cardsenabled
		if not Cardsenabled then Shared.ApplyActiveScale(self.equipBestButton, false) end
	end
	for _, Card in ipairs(self.selectCards) do
		for _, Button in ipairs(Card.Buttons) do
			if Button.Active ~= Cardsenabled then
				Button.Active = Cardsenabled
				Button.Interactable = Cardsenabled
				if not Cardsenabled then Shared.ApplyActiveScale(Button, false) end
			end
		end
	end
end

function Controller:RefreshSelectionControls()
	self:SetSelectionControlsEnabled(self.selectFrameOpen and not self.selectPlacementPending)
end

function Controller:FillItemStats(Frame: GuiObject, Item)
	Frame:WaitForChild("Icon").Image = tostring(Item.ImageId or "")
	Frame:WaitForChild("CashText").Text = Shared.FormatCurrency(Item.CurrentValue or 0)
	Frame:WaitForChild("ReputationText").Text = tostring(self:GetBaseReputation(Item))
end

function Controller:FillItemProgress(Frame: GuiObject, Item)
	local Framebar = Frame:WaitForChild("FrameBar")
	local Percent = math.clamp(tonumber(Item.RestorationPercent) or 0, 0, 100)
	Framebar:WaitForChild("PourcentageText").Text = string.format("%d%%", Percent)
	Framebar:WaitForChild("Bar").Size = UDim2.fromScale(Percent / 100, 1)
end

function Controller:SetCardOpen(Card, Item, Open: boolean)
	if self.openCard and self.openCard ~= Card then
		self.openCard.Button.Visible = true
		self.openCard.ButtonOpen.Visible = false
		self.openCard.Frame.ZIndex = 1
	end
	self.openCard = if Open then Card else nil
	self.openCardItemId = if Open then Item.Id else nil
	Card.Button.Visible = not Open
	Card.ButtonOpen.Visible = Open
	Card.Frame.ZIndex = if Open then 10 else 1
	self:UpdateSelectionCanvas()
	if Open then self:ScrollToOpenCard() end
end

function Controller:GetOpenCardBottom(): number
	local Buttonopen = self.openCard.ButtonOpen
	return Buttonopen.AbsolutePosition.Y + Buttonopen.AbsoluteSize.Y
		- self.selectScrollingFrame.AbsolutePosition.Y
		+ self.selectScrollingFrame.CanvasPosition.Y
end

function Controller:UpdateSelectionCanvas()
	local Bottom = self.selectGridLayout.AbsoluteContentSize.Y
	if self.openCard then
		Bottom = math.max(Bottom, self:GetOpenCardBottom())
	end
	self.selectScrollingFrame.CanvasSize = UDim2.fromOffset(0, Bottom)
end

function Controller:ScrollToOpenCard()
	local Scrolling = self.selectScrollingFrame
	local Target = self:GetOpenCardBottom() - Scrolling.AbsoluteWindowSize.Y
	if Target > Scrolling.CanvasPosition.Y then
		Tweenservice:Create(Scrolling, Detailstweeninfo, { CanvasPosition = Vector2.new(0, Target) }):Play()
	end
end

function Controller:ShowItemInfo(Item, Animate: boolean?)
	self.infoItemId = Item.Id
	local Rarity = Rarityconfig[tostring(Item.Rarity or "Common")]
	local Mutation = if Item.Revealed then Mutationconfig[tostring(Item.Mutation or "Normal")] else nil
	local Hasmutation = Mutation ~= nil and Mutation ~= Mutationconfig.Normal
	self:FillItemStats(self.infoCard, Item)
	self:FillItemProgress(self.infoCard, Item)
	self.infoNameText.Text = tostring(Item.Name or "")
	self.infoRarityText.Text = Rarity.Name
	self.infoRarityGradient.Color = Rarity.Gradient
	self.infoMutationText.Text = if Mutation then Mutation.Name else UnknownText
	self.infoMutationGradient.Color = if Hasmutation then Mutation.Gradient else self.infoMutationBaseGradient
	self.infoMutationFrameGradient.Color = if Hasmutation then Mutation.BackgroundGradient else self.infoMutationFrameBaseGradient
	self.infoReputationText.Text = tostring(self:GetBaseReputation(Item))
	local Rainbow = Hasmutation and Item.Mutation == "Rainbow"
	self.selectRainbowGradients = if Rainbow then { self.infoMutationGradient, self.infoMutationFrameGradient } else nil
	self.blackFrame.Visible = true
	self.infoFrame.Visible = true
	if Animate then
		self.infoScale.Scale = 0.96
		Tweenservice:Create(self.infoScale, Detailstweeninfo, { Scale = 1 }):Play()
	end
	self:RefreshSelectionControls()
end

function Controller:CloseItemInfo()
	self.infoItemId = nil
	self.selectRainbowGradients = nil
	self.infoFrame.Visible = false
	self.blackFrame.Visible = false
	self.infoScale.Scale = 1
	self:RefreshSelectionControls()
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
	if not self.selectFrame.Visible then
		self.selectDirty = true
		return
	end
	self:RenderSelectionItems()
end

function Controller:CreateSelectionCard(Item, Isopen: boolean, Enabled: boolean)
	local Card = self.selectTemplate:Clone()
	Card.Name = "Item_" .. tostring(Item.Id)
	Card.Visible = true
	Card.ZIndex = if Isopen then 10 else 1
	local Button = Card:WaitForChild("Button") :: GuiButton
	local Buttonopen = Card:WaitForChild("ButtonOpen") :: GuiButton
	local Infobutton = Buttonopen:WaitForChild("InfoButton") :: GuiButton
	local Equipbutton = Buttonopen:WaitForChild("EquipButton") :: GuiButton
	Button.Visible = not Isopen
	Buttonopen.Visible = Isopen
	local Carddata = {
		Frame = Card,
		Button = Button,
		ButtonOpen = Buttonopen,
		InfoButton = Infobutton,
		EquipButton = Equipbutton,
		Buttons = { Button, Buttonopen, Infobutton, Equipbutton },
		Item = Item,
	}
	for _, Target in ipairs(Carddata.Buttons) do
		Target.Active = Enabled
		Target.Interactable = Enabled
		Shared.AnimateButton(Target, function() return not Target.Active end)
	end
	local Gamepad = Core:GetController("GamepadController")
	Gamepad:OnActivated(Button, function() self:SetCardOpen(Carddata, Carddata.Item, true) end)
	Gamepad:OnActivated(Buttonopen, function() self:SetCardOpen(Carddata, Carddata.Item, false) end)
	Gamepad:OnActivated(Infobutton, function() self:ShowItemInfo(Carddata.Item, true) end)
	Gamepad:OnActivated(Equipbutton, function() self:PlaceDisplayItem(Carddata.Item.Id) end)
	return Carddata
end

function Controller:RenderSelectionItems()
	self.selectDirty = false
	local Itemsbyid = {}
	for _, Item in ipairs(self.selectItems) do
		Itemsbyid[Item.Id] = Item
	end
	for Id, Carddata in pairs(self.selectCardsById) do
		if not Itemsbyid[Id] then
			Carddata.Frame:Destroy()
			self.selectCardsById[Id] = nil
		end
	end
	table.clear(self.selectCards)
	self.openCard = nil

	local Cardsenabled = self.selectFrameOpen and not self.selectPlacementPending and not self.infoFrame.Visible
	local Infoitem
	for Order, Item in ipairs(self.selectItems) do
		local Carddata = self.selectCardsById[Item.Id]
		local Isnew = Carddata == nil
		if Isnew then
			Carddata = self:CreateSelectionCard(Item, self.openCardItemId == Item.Id, Cardsenabled)
			self.selectCardsById[Item.Id] = Carddata
		end
		Carddata.Item = Item
		Carddata.Frame.LayoutOrder = Order
		self:FillItemStats(Carddata.Button, Item)
		self:FillItemProgress(Carddata.Button, Item)
		self:FillItemStats(Carddata.ButtonOpen, Item)
		Carddata.ButtonOpen:WaitForChild("ObjectNameText").Text = tostring(Item.Name or "")
		if Isnew then
			Carddata.Frame.Parent = self.selectScrollingFrame
		end
		table.insert(self.selectCards, Carddata)
		if self.openCardItemId == Item.Id then self.openCard = Carddata end
		if self.infoItemId == Item.Id then Infoitem = Item end
	end
	if not self.openCard then self.openCardItemId = nil end
	if self.infoItemId then
		if Infoitem then self:ShowItemInfo(Infoitem, false) else self:CloseItemInfo() end
	end
	self:RefreshSelectionControls()

	task.defer(function()
		self:UpdateSelectionCanvas()
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
		local Canremove = Slot.Occupied and Slot.Owned
		Slot.Icon.Visible = not Slot.Unlocked and not Canremove
		Slot.Text.Visible = Slot.Unlocked or Canremove
		if Slot.Occupied ~= Previousoccupied then self:RotateSlotText(Slot, Slot.Button.Visible) end
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

function Controller:OpenSelectionFrame(SlotIndex: number)
	self:CloseTopbarFrames()
	if self.selectFrameOpen or self.blockerMode ~= nil then return end
	self.selectionRequestId += 1
	self.selectFrameAnimationId += 1
	if self.selectFrameTween then self.selectFrameTween:Cancel() end
	self.selectedSlotIndex = SlotIndex

	self.selectPlacementPending = false
	self.selectFrameOpen = true
	if self.selectDirty then self:RenderSelectionItems() end
	self.selectScrollingFrame.CanvasPosition = Vector2.zero
	if self.openCard then
		self.openCard.Button.Visible = true
		self.openCard.ButtonOpen.Visible = false
		self.openCard.Frame.ZIndex = 1
	end
	self.openCard = nil
	self.openCardItemId = nil
	self:UpdateSelectionCanvas()
	self:CloseItemInfo()
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
	self:CloseItemInfo()
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
		Core:GetController("MessageController"):Show("Unable to display this item", ErrorMessageGradient)
		return
	end
	if type(Response) == "table" and Response.Success == true then
		if type(Response.DisplayItems) == "table" then self:ApplyDisplayItems(Response.DisplayItems, true) end
		local Grantedreputation = tonumber(Response.GrantedReputation) or 0
		local Message = if Grantedreputation > 0
			then "+" .. FormatReputation(Grantedreputation) .. " Reputation"
			else "Item added to display"
		Core:GetController("FeedbackController"):PlaySound("SlotItem", 0.15)
		Core:GetController("MessageController"):Show(Message, ReputationMessageGradient)
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
	Core:GetController("MessageController"):Show(Message, ErrorMessageGradient)
end

function Controller:RemoveDisplayItem(Slotindex: number)
	if self.displayActionPending then return end
	local Slot = self.slotButtons[Slotindex]
	if not Slot.Owned then
		Core:GetController("MessageController"):Show("This display item belongs to another player", ErrorMessageGradient)
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
		Core:GetController("FeedbackController"):Fail()
		local Removedreputation = tonumber(Response.RemovedReputation) or 0
		local Message = if Removedreputation > 0
			then "-" .. FormatReputation(Removedreputation) .. " Reputation"
			else "Item returned to inventory"
		local Gradient = if Removedreputation > 0 then ErrorMessageGradient else ReputationMessageGradient
		Core:GetController("MessageController"):Show(Message, Gradient)
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
	Core:GetController("MessageController"):Show(Message, ErrorMessageGradient)
end

function Controller:EquipBest()
	if not self.selectFrameOpen or self.selectPlacementPending then return end
	local Requestid = self.selectionRequestId
	self.selectPlacementPending = true
	self:SetSelectionControlsEnabled(false)
	self:SetBlocker("EquipBest", "Disabled")
	local Success, Response = pcall(function()
		return Remotemanager:InvokeServer("ExpositionService", "EquipBest")
	end)
	self:SetBlocker("EquipBest", nil)
	local Iscurrentrequest = self.selectionRequestId == Requestid
	if Iscurrentrequest then
		self.selectPlacementPending = false
		self:UpdateButtonAvailability()
	end
	if Success and type(Response) == "table" and Response.Success == true then
		if type(Response.DisplayItems) == "table" then self:ApplyDisplayItems(Response.DisplayItems, Iscurrentrequest and (tonumber(Response.Changed) or 0) > 0) end
		local Grantedreputation = tonumber(Response.GrantedReputation) or 0
		if (tonumber(Response.Changed) or 0) > 0 then
			local Message = if Grantedreputation > 0
				then "+" .. FormatReputation(Grantedreputation) .. " Reputation"
				else "Best items equipped"
			Core:GetController("FeedbackController"):PlaySound("SlotItem", 0.15)
			Core:GetController("MessageController"):Show(Message, ReputationMessageGradient)
			if Iscurrentrequest then self:CloseSelectionFrame(false) end
			return
		end
		if Iscurrentrequest then self:RefreshSelectionControls() end
		if (tonumber(Response.Kept) or 0) > 0 then
			Core:GetController("MessageController"):Show("Your best items are already on display", ReputationMessageGradient)
		else
			Core:GetController("MessageController"):Show("No restored items to display", ErrorMessageGradient)
		end
		return
	end
	if Iscurrentrequest then self:SetSelectionControlsEnabled(true) end
	local Reason = if Success and type(Response) == "table" then Response.Reason else "EquipFailed"
	local Message = if Reason == "Busy"
		then "Please wait before changing your display"
		else "Unable to equip your best items"
	Core:GetController("MessageController"):Show(Message, ErrorMessageGradient)
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
	self:SwapButtons(self.reputationButtonL, self.reputationButtonR)
end

function Controller:Close()
	self:SyncFrameBlockers()
	if not self.isOpen or not self:CanUseButtons() then return end
	if self.selectFrame.Visible then self:CloseSelectionFrame(true) end
	if not self.cameraController:ShowIntroCameraFromExposition() then return end
	self.expositionRequestId += 1
	self.slotsRevealReached = false
	self.isOpen = false
	self:HideSlotButtons()
	self:SwapButtons(self.reputationButtonR, self.reputationButtonL)

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
	local Selectframe = Expositionui:WaitForChild("ExpositionFrame") :: Frame
	local Selectscrollingframe = Selectframe:WaitForChild("ScrollingFrame") :: ScrollingFrame
	local Infoframe = Selectframe:WaitForChild("InfoFrame") :: Frame
	local Statsframe = Infoframe:WaitForChild("StatsFrame") :: Frame
	local Mutationframe = Statsframe:WaitForChild("MutationFrame") :: Frame
	local Reputationframe = Statsframe:WaitForChild("ReputationFrame") :: Frame
	Expositionui.Enabled = true
	self.reputationButtonL = Reputationfolder:WaitForChild("ReputationButtonL") :: GuiButton
	self.reputationButtonR = Reputationfolder:WaitForChild("ReputationButtonR") :: GuiButton
	self.selectFrame = Selectframe
	self.selectFrameScale = Shared.EnsureScale(Selectframe)
	self.selectScrollingFrame = Selectscrollingframe
	self.selectGridLayout = Selectscrollingframe:WaitForChild("UIGridLayout") :: UIGridLayout
	self.selectTemplate = Selectscrollingframe:WaitForChild("Template") :: GuiObject
	self.selectCloseButton = Selectframe:WaitForChild("CloseButton") :: GuiButton
	self.equipBestButton = Selectframe:WaitForChild("EquipBestButton") :: GuiButton
	self.blackFrame = Selectframe:WaitForChild("BlackFrame") :: GuiObject
	self.infoFrame = Infoframe
	self.infoScale = Shared.EnsureScale(Infoframe)
	self.infoCloseButton = Infoframe:WaitForChild("CloseButton") :: GuiButton
	self.infoCard = Infoframe:WaitForChild("Button") :: GuiObject
	self.infoNameText = Infoframe:WaitForChild("ObjectNameText") :: TextLabel
	self.infoRarityText = Infoframe:WaitForChild("RarityText") :: TextLabel
	self.infoRarityGradient = Uigradient.Ensure(self.infoRarityText)
	self.infoMutationText = Mutationframe:WaitForChild("MutationText") :: TextLabel
	self.infoMutationGradient = Uigradient.Ensure(self.infoMutationText)
	self.infoMutationFrameGradient = Uigradient.Ensure(Mutationframe)
	self.infoMutationBaseGradient = self.infoMutationGradient.Color
	self.infoMutationFrameBaseGradient = self.infoMutationFrameGradient.Color
	self.infoReputationText = Reputationframe:WaitForChild("ReputationText") :: TextLabel
	self.buttonScales = {}
	self.buttonTweens = {}
	self.slotTextTweens = {}
	self.hoveredButtons = {}
	self.slotButtons = {}
	self.animatedButtons = { self.reputationButtonL, self.reputationButtonR }
	self.selectCards = {}
	self.selectCardsById = {}
	self.selectDirty = false
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
	self.openCard = nil
	self.openCardItemId = nil
	self.infoItemId = nil
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
		Slot.Text.Rotation = 0
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

	self.reputationButtonL.Visible = true
	self.reputationButtonL.Active = false
	self.reputationButtonL.Interactable = false
	self.reputationButtonR.Visible = false
	self.reputationButtonR.Active = false
	self.reputationButtonR.Interactable = false
	self.selectGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	self.selectTemplate.Visible = false
	self.selectFrame.Visible = false
	self.selectFrameScale.Scale = 1
	self.infoFrame.Visible = false
	self.blackFrame.Visible = false
	self:SetSelectionControlsEnabled(false)
end

function Controller:Start()
	local Gamepad = Core:GetController("GamepadController")
	Gamepad:RegisterMenu({
		Priority = 35,
		IsOpen = function()
			return self.infoFrame.Visible
		end,
		Close = function()
			self:CloseItemInfo()
		end,
	})
	Gamepad:RegisterMenu({
		Priority = 30,
		IsOpen = function()
			return self.selectFrameOpen == true
		end,
		Close = function()
			self:CloseSelectionFrame(false)
		end,
	})
	Gamepad:RegisterMenu({
		Priority = 15,
		IsOpen = function()
			return self:IsOpen()
		end,
		Close = function()
			self:Close()
		end,
	})
	Gamepad:BindShortcut(Enum.KeyCode.ButtonX, function()
		self:Open()
	end)
	self.cameraController = Core:GetController("InspectionCameraController")
	self.computerController = Core:GetController("ComputerController")
	self.customerController = Core:GetController("CustomerController")
	self.dailyRewardController = Core:GetController("DailyRewardController")
	self.settingController = Core:GetController("SettingController")
	self.donationController = Core:GetController("DonationController")
	self.completionController = Core:GetController("CompletionController")
	Runservice.Heartbeat:Connect(function()
		local Sequence = Core:GetController("MutationController"):GetGradient("Rainbow")
		for _, Gradient in ipairs(self.selectRainbowGradients or {}) do
			Gradient.Color = Sequence
		end
	end)
	for _, Button in ipairs(self.animatedButtons) do self:BindButtonAnimation(Button) end
	Shared.AnimateButton(self.selectCloseButton, function() return not self.selectCloseButton.Active end)
	Shared.AnimateButton(self.infoCloseButton, function() return not self.infoCloseButton.Active end)
	Shared.AnimateButton(self.equipBestButton, function() return not self.equipBestButton.Active end)
	Core:GetController("GamepadController"):OnActivated(self.reputationButtonL, function() self:Open() end)
	Core:GetController("GamepadController"):OnActivated(self.reputationButtonR, function() self:Close() end)
	Core:GetController("GamepadController"):OnActivated(self.selectCloseButton, function() self:CloseSelectionFrame(false) end)
	Core:GetController("GamepadController"):OnActivated(self.infoCloseButton, function() self:CloseItemInfo() end)
	Core:GetController("GamepadController"):OnActivated(self.equipBestButton, function() self:EquipBest() end)
	for _, Slot in ipairs(self.slotButtons) do
		Core:GetController("GamepadController"):OnActivated(Slot.Button, function()
			self:SyncFrameBlockers()
			if not Slot.Button.Active then return end
			local Wasopen = self.selectFrameOpen
			if Wasopen and self.selectedSlotIndex == Slot.Index then
				self:CloseSelectionFrame(false)
				return
			end
			if not Slot.Unlocked and not Slot.Owned then
				Core:GetController("MessageController"):Show("Upgrade Display Space to unlock more slots", ErrorMessageGradient)
				return
			end
			if Slot.Occupied then
				self:RemoveDisplayItem(Slot.Index)
				return
			end
			if Wasopen then self:CloseSelectionFrame(true) end
			self:OpenSelectionFrame(Slot.Index)
		end)
	end
	self.selectGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self:UpdateSelectionCanvas()
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
