local Guiservice = game:GetService("GuiService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Tweenservice = game:GetService("TweenService")
local Userinputservice = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)
local Formatcurrency = require(Replicatedstorage.Shared.Utils.CurrencyFormatter)
local Objectconfig = require(Replicatedstorage.Shared.Config.Object)
local Rarityconfig = require(Replicatedstorage.Shared.Config.Rarity)
local Uigradient = require(Replicatedstorage.Shared.Utils.UiGradient)

local Customercontroller = {
	Name = "CustomerController",
	Priority = 2,
}

local Customerservicename = "CustomerService"
local Frametweeninfo = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local Fastframetweeninfo = TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local Buttontweeninfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Estimationtweeninfo = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HighlightFillcolor = Color3.fromRGB(255, 232, 163)
local HighlightOutlinecolor = Color3.fromRGB(255, 255, 255)
local ErrorMessageColor = Color3.fromRGB(255, 0, 4)
local DisabledEstimateColor = Color3.fromRGB(115, 115, 115)
local PointerRayOffsets = { Vector2.zero }
local TouchRayOffsets = {
	Vector2.zero,
	Vector2.new(-36, 0),
	Vector2.new(36, 0),
	Vector2.new(0, -36),
	Vector2.new(0, 36),
	Vector2.new(-30, -30),
	Vector2.new(30, -30),
	Vector2.new(-30, 30),
	Vector2.new(30, 30),
	Vector2.new(-52, 0),
	Vector2.new(52, 0),
	Vector2.new(0, -52),
	Vector2.new(0, 52),
}

function Customercontroller:HideEstimateText()
	if not self.estimatePriceText then
		return
	end
	self.estimateAnimationId = (self.estimateAnimationId or 0) + 1
	self.estimatePriceText.Visible = false
	self.estimatePriceText.TextTransparency = 1
	self.estimatePriceText.TextStrokeTransparency = 1
	self.estimateTextScale.Scale = 0.82
end

function Customercontroller:RevealEstimate(MaxPrice: number)
	self.estimateAnimationId += 1
	self.estimatePriceText.Text = Formatcurrency(MaxPrice)
	self.estimatePriceText.Visible = true
	self.estimatePriceText.TextTransparency = 1
	self.estimatePriceText.TextStrokeTransparency = 1
	self.estimateTextScale.Scale = 0.82

	Tweenservice:Create(self.estimatePriceText, Estimationtweeninfo, {
		TextTransparency = self.baseEstimateTextTransparency,
		TextStrokeTransparency = self.baseEstimateStrokeTransparency,
	}):Play()
	Tweenservice:Create(self.estimateTextScale, Estimationtweeninfo, { Scale = 1 }):Play()
end

function Customercontroller:UpdateEstimateButtonAppearance()
	local HasEstimatedCurrentOffer = self.activeOfferId ~= nil and self.estimatedOfferId == self.activeOfferId
	local IsAvailable = self.estimatesRemaining > 0 and not HasEstimatedCurrentOffer
	self.estimateCountText.Text = string.format("x%d", self.estimatesRemaining)
	self.estimateButton.Visible = self:IsVisible()
	self.estimateButton.Interactable = not HasEstimatedCurrentOffer
	self.estimateButton.Active = true
	self.estimateButton.AutoButtonColor = IsAvailable
	for ImageObject, DefaultColor in pairs(self.estimateImageColors or {}) do
		Tweenservice:Create(ImageObject, Buttontweeninfo, {
			ImageColor3 = if IsAvailable then DefaultColor else DisabledEstimateColor,
		}):Play()
	end
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

local function AnimateButton(Button: GuiButton)
	local Scale = EnsureScale(Button)
	local IsHovering = false

	Button.MouseEnter:Connect(function()
		IsHovering = true
		Tweenservice:Create(Scale, Buttontweeninfo, { Scale = 1.06 }):Play()
	end)

	Button.MouseLeave:Connect(function()
		IsHovering = false
		Tweenservice:Create(Scale, Buttontweeninfo, { Scale = 1 }):Play()
	end)

	Button.MouseButton1Down:Connect(function()
		Tweenservice:Create(Scale, Buttontweeninfo, { Scale = 0.96 }):Play()
	end)

	Button.MouseButton1Up:Connect(function()
		local Targetscale = IsHovering and 1.06 or 1
		Tweenservice:Create(Scale, Buttontweeninfo, { Scale = Targetscale }):Play()
	end)
end

function Customercontroller:HideInstant()
	self.hideId += 1
	self.activeOfferId = nil
	self.estimatedOfferId = nil
	self.estimatedMaxPrice = nil
	self.isBusy = false
	self.offerOpen = false
	self.gui.Enabled = false
	self.blackFrame.Visible = false
	self.frame.Visible = false
	self.frame.Position = self.hiddenPosition
	self.frameScale.Scale = 0.96
	local Selectedobject = Guiservice.SelectedObject
	if Selectedobject and Selectedobject:IsDescendantOf(self.frame) then Guiservice.SelectedObject = nil end
	self:HideEstimateText()
end

function Customercontroller:IsVisible(): boolean
	return self.gui.Enabled and self.frame.Visible
end

function Customercontroller:IsFrontCustomer(Customer: Model?): boolean
	return Customer ~= nil
		and Customer:GetAttribute("QueueCustomerInstance") == true
		and Customer:GetAttribute("IsFrontCustomer") == true
		and Customer:GetAttribute("ArrivedAtSlot1") == true
end

function Customercontroller:CanInteract(): boolean
	local Computercontroller = Core:GetController("ComputerController")
	local Cameracontroller = Core:GetController("InspectionCameraController")
	local Restorationcontroller = Core:GetController("RestorationController")
	return not self:IsVisible()
		and not self.isBusy
		and not Computercontroller:IsOpen()
		and Cameracontroller:IsIntroCameraReady()
		and not Restorationcontroller:IsEditingObject()
end

function Customercontroller:SetHoveredCustomer(Customer: Model?)
	if self.hoveredCustomer == Customer then
		return
	end

	self.hoveredCustomer = Customer
	self.hoverHighlight.Adornee = Customer
	self.hoverHighlight.Enabled = Customer ~= nil
end

function Customercontroller:GetInteractionCustomer(): Model?
	local Offer = self.pendingOffer
	local Customer = if Offer then Offer.Customer else nil
	return if self:IsFrontCustomer(Customer) then Customer else nil
end

function Customercontroller:GetCustomerAtPosition(Screenposition: Vector2?, Expandtouch: boolean?): Model?
	local Customer = self:GetInteractionCustomer()
	if not Customer then return nil end
	local Camera = Workspace.CurrentCamera
	local Position = Screenposition or Userinputservice:GetMouseLocation()
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Customer }
	for _, Offset in ipairs(if Expandtouch then TouchRayOffsets else PointerRayOffsets) do
		local Rayposition = Position + Offset
		local Ray = Camera:ViewportPointToRay(Rayposition.X, Rayposition.Y)
		if Workspace:Raycast(Ray.Origin, Ray.Direction * 500, Params) then
			return Customer
		end
		if Expandtouch then
			local Insetray = Camera:ScreenPointToRay(Rayposition.X, Rayposition.Y)
			if Workspace:Raycast(Insetray.Origin, Insetray.Direction * 500, Params) then
				return Customer
			end
		end
	end
	return nil
end

function Customercontroller:TryInteractAtPosition(Screenposition: Vector2?, Expandtouch: boolean?): boolean
	if self:IsVisible() or not self:CanInteract() then return false end
	local Clickedcustomer = self:GetCustomerAtPosition(Screenposition, Expandtouch)
	if not Clickedcustomer or not self.pendingOffer then return false end
	Core:GetController("FeedbackController"):UiClick()
	self:SetHoveredCustomer(Clickedcustomer)
	self:ShowPendingOffer()
	return true
end

function Customercontroller:UpdateHoveredCustomer()
	if not self:CanInteract() then
		self:SetHoveredCustomer(nil)
		return
	end

	local Lastinputtype = Userinputservice:GetLastInputType()
	if Lastinputtype == Enum.UserInputType.Touch then
		self:SetHoveredCustomer(nil)
		return
	end
	self:SetHoveredCustomer(self:GetCustomerAtPosition(nil))
end

function Customercontroller:ShowPendingOffer()
	if not self.pendingOffer or self:IsVisible() then
		return
	end
	Core:GetController("DailyRewardController"):CloseForSwitch()
	Core:GetController("SettingController"):CloseForSwitch()

	self:ShowOffer(self.pendingOffer)
end

function Customercontroller:ShowOffer(Offer)
	self.hideId += 1
	local HasCachedEstimate = self.estimatedOfferId == Offer.Id and self.estimatedMaxPrice ~= nil
	if self.estimatedOfferId ~= nil and self.estimatedOfferId ~= Offer.Id then
		self.estimatedOfferId = nil
		self.estimatedMaxPrice = nil
	end
	self.activeOfferId = Offer.Id
	self.activeOfferPrice = tonumber(Offer.Price) or 0
	self.activeOffer = Offer
	self.offerOpen = true
	self.gui.Enabled = true
	self.blackFrame.Visible = true
	self.frame.Visible = true
	self.frame.Position = self.hiddenPosition
	self.frameScale.Scale = 0.96

	local Rarity = Rarityconfig[Objectconfig.Object[Offer.ObjectKey].Rarity]
	self.objectLabel.Text = Offer.ObjectName
	self.rarityText.Text = Rarity.Name
	self.rarityGradient.Color = Rarity.Gradient
	self.buyPriceText.Text = if self.activeOfferPrice > 0 then Formatcurrency(Offer.Price) else "Free"
	self.iconImage.Image = tostring(Offer.ImageId or "")
	if HasCachedEstimate then
		self:RevealEstimate(self.estimatedMaxPrice)
	else
		self:HideEstimateText()
	end
	self:UpdateEstimateButtonAppearance()

	Tweenservice:Create(self.frame, Frametweeninfo, {
		Position = self.shownPosition,
	}):Play()
	Tweenservice:Create(self.frameScale, Frametweeninfo, {
		Scale = 1,
	}):Play()
end

function Customercontroller:ApplyUpgradeState(State)
	self.estimatesRemaining = tonumber(State and State.EstimatesRemaining) or 0
	self:UpdateEstimateButtonAppearance()
end

function Customercontroller:RequestPriceEstimate()
	if not self.activeOfferId or self.isEstimating or self.estimatedOfferId == self.activeOfferId then
		return
	end
	if (self.estimatesRemaining or 0) <= 0 then
		Core:GetController("MessageController"):Show("Upgrade Price Estimation to get more estimates", ErrorMessageColor)
		return
	end
	local Offerid = self.activeOfferId
	self.isEstimating = true
	local Response = Remotemanager:InvokeServer(Customerservicename, "RequestPriceEstimate", Offerid)
	self.isEstimating = false
	if self.activeOfferId ~= Offerid then
		self:UpdateEstimateButtonAppearance()
		return
	end
	if type(Response) == "table" and Response.Success == true then
		self.estimatedOfferId = Offerid
		self.estimatedMaxPrice = tonumber(Response.MaxPrice) or 0
		self:RevealEstimate(self.estimatedMaxPrice)
		self:UpdateEstimateButtonAppearance()
		return
	end
	if type(Response) == "table" and Response.Reason == "NoEstimatesRemaining" then
		Core:GetController("MessageController"):Show("No price estimates remaining today", ErrorMessageColor)
	end
end

function Customercontroller:HideAnimated(Fast: boolean?)
	self.hideId += 1
	local Hideid = self.hideId
	self.activeOfferId = nil
	self.offerOpen = false
	local Tweeninfo = if Fast then Fastframetweeninfo else Frametweeninfo
	self.blackFrame.Visible = false
	local Selectedobject = Guiservice.SelectedObject
	if Selectedobject and Selectedobject:IsDescendantOf(self.frame) then Guiservice.SelectedObject = nil end
	Tweenservice:Create(self.frame, Tweeninfo, {
		Position = self.hiddenPosition,
	}):Play()
	local Scaletween = Tweenservice:Create(self.frameScale, Tweeninfo, {
		Scale = 0.96,
	})
	Scaletween:Play()
	Scaletween.Completed:Once(function()
		if self.hideId ~= Hideid then
			return
		end
		self.gui.Enabled = false
		self.frame.Visible = false
	end)
end

function Customercontroller:CloseOfferUi(Fast: boolean?)
	if not self:IsVisible() or self.isBusy then
		return
	end
	self:SetHoveredCustomer(nil)
	self:HideAnimated(Fast)
end

function Customercontroller:Respond(Decision: string)
	if self.isBusy or not self.activeOfferId then
		return
	end

	self.isBusy = true
	local Offerid = self.activeOfferId
	local Offer = self.activeOffer
	local Hidden = Decision ~= "Accept"
		or Core:GetController("CashController"):GetCash() >= (self.activeOfferPrice or 0)
	if Decision == "Accept" then
		local Feedback = Core:GetController("FeedbackController")
		if Core:GetController("CashController"):GetCash() >= (self.activeOfferPrice or 0) then
			Feedback:Confirm()
		else
			Feedback:UiClick()
		end
	else
		Core:GetController("FeedbackController"):Fail()
	end
	if Hidden then
		self:HideAnimated(true)
	end
	local Response = Remotemanager:InvokeServer(Customerservicename, "RespondToOffer", Offerid, Decision)
	self.isBusy = false

	local WasAccepted = Response == true
	local Reason = nil
	if type(Response) == "table" then
		WasAccepted = Response.Success == true
		Reason = Response.Reason
	end

	if not WasAccepted then
		if Hidden and self.pendingOffer then
			self:ShowOffer(self.pendingOffer)
		end
		if Reason == "NotEnoughCash" then
			Core:GetController("MessageController"):Show("Not enough money", ErrorMessageColor)
		elseif Reason == "EmergencyOfferPresented" then
			Core:GetController("MessageController"):Show("You cannot afford this item. Restore this free skateboard to recover.", ErrorMessageColor)
		end
		return
	end

	self.pendingOffer = nil
	self:HideInstant()
	if Decision == "Accept" then
		local Definition = Objectconfig.Object[tostring(Offer.ObjectKey)]
		Core:GetController("FeedbackController"):Purchase(
			tostring(Offer.ObjectName),
			tostring(Offer.ImageId or ""),
			Rarityconfig[tostring(Definition.Rarity or "Common")].Gradient
		)
		Core:GetController("RestorationController"):Enter()
	end
end

function Customercontroller:Init()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = Playergui:WaitForChild("CustomerUi") :: ScreenGui
	self.frame = self.gui:WaitForChild("Frame") :: Frame
	self.blackFrame = self.gui:WaitForChild("BlackFrame") :: GuiObject
	self.buyButton = self.frame:WaitForChild("BuyButton") :: GuiButton
	self.buyButton:SetAttribute("SilentClick", true)
	self.buyPriceText = self.buyButton:WaitForChild("Text") :: TextLabel
	self.declineButton = self.frame:WaitForChild("DeclineButton") :: GuiButton
	self.declineButton:SetAttribute("SilentClick", true)
	self.closeButton = self.frame:WaitForChild("CloseButton") :: GuiButton
	self.frameScale = EnsureScale(self.frame)
	self.shownPosition = self.frame.Position
	self.hiddenPosition = self.shownPosition + UDim2.fromOffset(0, 24)

	self.objectLabel = self.frame:WaitForChild("ObjectNameText") :: TextLabel
	self.rarityText = self.frame:WaitForChild("RarityText") :: TextLabel
	self.rarityGradient = Uigradient.Ensure(self.rarityText)
	self.iconImage = self.frame:WaitForChild("Icon") :: ImageLabel
	self.estimateButton = self.frame:WaitForChild("PriceEstimationButton") :: GuiButton
	self.estimateCountText = self.estimateButton:WaitForChild("Text") :: TextLabel
	self.estimatePriceText = self.frame:WaitForChild("EstimationPriceText") :: TextLabel
	self.estimateTextScale = EnsureScale(self.estimatePriceText)
	self.baseEstimateTextTransparency = self.estimatePriceText.TextTransparency
	self.baseEstimateStrokeTransparency = self.estimatePriceText.TextStrokeTransparency
	self.estimateAnimationId = 0
	self.estimateImageColors = {}
	if self.estimateButton:IsA("ImageButton") then
		self.estimateImageColors[self.estimateButton] = self.estimateButton.ImageColor3
	end
	for _, Descendant in ipairs(self.estimateButton:GetDescendants()) do
		if Descendant:IsA("ImageLabel") or Descendant:IsA("ImageButton") then
			self.estimateImageColors[Descendant] = Descendant.ImageColor3
		end
	end
	self.estimatesRemaining = 0
	self.isEstimating = false
	self.hideId = 0
	self.hoverHighlight = Instance.new("Highlight")
	self.hoverHighlight.Name = "CustomerHoverHighlight"
	self.hoverHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	self.hoverHighlight.FillColor = HighlightFillcolor
	self.hoverHighlight.FillTransparency = 1
	self.hoverHighlight.OutlineColor = HighlightOutlinecolor
	self.hoverHighlight.OutlineTransparency = 0
	self.hoverHighlight.Enabled = false
	self.hoverHighlight.Parent = Workspace

	AnimateButton(self.buyButton)
	AnimateButton(self.declineButton)
	AnimateButton(self.estimateButton)
	AnimateButton(self.closeButton)

	Core:GetController("GamepadController"):OnActivated(self.buyButton, function()
		self:Respond("Accept")
	end)

	Core:GetController("GamepadController"):OnActivated(self.declineButton, function()
		self:Respond("Decline")
	end)
	Core:GetController("GamepadController"):OnActivated(self.estimateButton, function()
		self:RequestPriceEstimate()
	end)
	Core:GetController("GamepadController"):OnActivated(self.closeButton, function()
		self:CloseOfferUi()
	end)

	self:ApplyUpgradeState(Remotemanager:InvokeServer("UpgradeService", "GetUpgrades"))
	self:HideInstant()
end

function Customercontroller:Start()
	Core:GetController("GamepadController"):RegisterMenu({
		Priority = 20,
		IsOpen = function()
			return self.offerOpen == true
		end,
		Close = function()
			self:CloseOfferUi()
		end,
	})
	Remotemanager:OnClientEvent("UpgradeService", "UpgradesUpdated", function(State)
		self:ApplyUpgradeState(State)
	end)

	local Offertoken = 0
	local function Applyoffer(Offer)
		Offertoken += 1
		local Token = Offertoken
		if Offer then

			local Customer = Workspace:WaitForChild(Offer.CustomerName) :: Model
			if Token ~= Offertoken then
				return
			end
			Offer.Customer = Customer
			self.pendingOffer = Offer

			if self:IsVisible() then
				self:ShowOffer(Offer)
			end
		else
			self.pendingOffer = nil
			self:SetHoveredCustomer(nil)
			self:HideInstant()
		end
	end
	Remotemanager:OnClientEvent(Customerservicename, "OfferUpdated", Applyoffer)
	task.spawn(function()
		local Offer = Remotemanager:InvokeServer(Customerservicename, "GetPendingOffer")
		if Offertoken == 0 then
			Applyoffer(Offer)
		end
	end)

	Runservice.RenderStepped:Connect(function()
		self:UpdateHoveredCustomer()
	end)
end

return Customercontroller
