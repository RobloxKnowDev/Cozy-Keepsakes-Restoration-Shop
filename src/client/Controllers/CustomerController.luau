local Guiservice = game:GetService("GuiService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Tweenservice = game:GetService("TweenService")
local Userinputservice = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

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
local ErrorMessageColor = Color3.fromRGB(255, 92, 92)
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

local function Isgamepad(Inputtype: Enum.UserInputType): boolean
	return Inputtype == Enum.UserInputType.Gamepad1
end

local function Formatcurrency(Value: number): string
	local Rounded = math.round(Value * 100) / 100
	if math.abs(Rounded - math.round(Rounded)) < 0.005 then
		return string.format("$%d", math.round(Rounded))
	end
	return string.format("$%.2f", Rounded)
end

local function GetOrCreateCloseButton(CustomerFrame: Frame): GuiButton
	local Existing = CustomerFrame:FindFirstChild("CloseButton")
	if Existing and Existing:IsA("GuiButton") then
		return Existing
	end

	local Button = Instance.new("TextButton")
	Button.Name = "CloseButton"
	Button.AnchorPoint = Vector2.new(1, 0)
	Button.Position = UDim2.new(1, -10, 0, 10)
	Button.Size = UDim2.fromOffset(36, 36)
	Button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	Button.Font = Enum.Font.GothamBold
	Button.Text = "X"
	Button.TextColor3 = Color3.new(1, 1, 1)
	Button.TextScaled = true
	Button.ZIndex = 20
	Button.Parent = CustomerFrame

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 8)
	Corner.Parent = Button
	return Button
end

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
	if not self.estimateButton then
		return
	end
	local HasEstimatedCurrentOffer = self.activeOfferId ~= nil and self.estimatedOfferId == self.activeOfferId
	local IsAvailable = (self.estimatesRemaining or 0) > 0 and not HasEstimatedCurrentOffer
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
	self.activeOfferId = nil
	self.estimatedOfferId = nil
	self.estimatedMaxPrice = nil
	self.isBusy = false
	self.gui.Enabled = false
	self.frame.Visible = false
	self.frame.Position = self.hiddenPosition
	self.frameScale.Scale = 0.96
	self.frame.BackgroundTransparency = 1
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
	if Isgamepad(Lastinputtype) then return end
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
	local HasCachedEstimate = self.estimatedOfferId == Offer.Id and self.estimatedMaxPrice ~= nil
	if self.estimatedOfferId ~= nil and self.estimatedOfferId ~= Offer.Id then
		self.estimatedOfferId = nil
		self.estimatedMaxPrice = nil
	end
	self.activeOfferId = Offer.Id
	self.gui.Enabled = true
	self.frame.Visible = true
	self.frame.Position = self.hiddenPosition
	self.frameScale.Scale = 0.96
	self.frame.BackgroundTransparency = 1


	if self.objectLabel then
		self.objectLabel.Text = Offer.ObjectName
	end

	if self.priceValueLabel then
		self.priceValueLabel.Text = string.format("$%d", Offer.Price)
	end

	if self.iconImage and (self.iconImage:IsA("ImageLabel") or self.iconImage:IsA("ImageButton")) then
		self.iconImage.Image = tostring(Offer.ImageId or "")
	end
	if HasCachedEstimate then
		self:RevealEstimate(self.estimatedMaxPrice)
	else
		self:HideEstimateText()
	end
	self:UpdateEstimateButtonAppearance()

	Tweenservice:Create(self.frame, Frametweeninfo, {
		Position = self.shownPosition,
		BackgroundTransparency = self.baseBackgroundTransparency,
	}):Play()
	Tweenservice:Create(self.frameScale, Frametweeninfo, {
		Scale = 1,
	}):Play()
	if Isgamepad(Userinputservice:GetLastInputType()) then Guiservice.SelectedObject = self.acceptButton end
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
	local Currentofferid = self.activeOfferId
	self.activeOfferId = nil
	local Tweeninfo = if Fast then Fastframetweeninfo else Frametweeninfo
	local Selectedobject = Guiservice.SelectedObject
	if Selectedobject and Selectedobject:IsDescendantOf(self.frame) then Guiservice.SelectedObject = nil end
	Tweenservice:Create(self.frame, Tweeninfo, {
		Position = self.hiddenPosition,
		BackgroundTransparency = 1,
	}):Play()
	local Scaletween = Tweenservice:Create(self.frameScale, Tweeninfo, {
		Scale = 0.96,
	})
	Scaletween:Play()
	Scaletween.Completed:Once(function()
		if self.activeOfferId == nil or self.activeOfferId == Currentofferid then
			self.gui.Enabled = false
			self.frame.Visible = false
		end
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
	local Response = Remotemanager:InvokeServer(Customerservicename, "RespondToOffer", self.activeOfferId, Decision)
	self.isBusy = false

	local WasAccepted = Response == true
	local Reason = nil
	if type(Response) == "table" then
		WasAccepted = Response.Success == true
		Reason = Response.Reason
	end

	if not WasAccepted then
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
		Core:GetController("RestorationController"):Enter()
	end
end

function Customercontroller:Init()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = Playergui:WaitForChild("CustomerUi") :: ScreenGui
	self.frame = self.gui:WaitForChild("CustomerFrame") :: Frame
	self.acceptButton = self.frame:WaitForChild("AcceptButton") :: GuiButton
	self.declineButton = self.frame:WaitForChild("DeclineButton") :: GuiButton
	self.closeButton = GetOrCreateCloseButton(self.frame)
	self.frameScale = EnsureScale(self.frame)
	self.shownPosition = self.frame.Position
	self.hiddenPosition = self.shownPosition + UDim2.fromOffset(0, 24)
	self.baseBackgroundTransparency = self.frame.BackgroundTransparency

	self.objectLabel = self.frame:WaitForChild("ObjectName")
	self.priceLabel = self.frame:WaitForChild("PriceLabel")
	self.priceValueLabel = self.frame:WaitForChild("PriceText")
	self.iconImage = self.frame:WaitForChild("Icon")
	self.estimateButton = self.frame:WaitForChild("EstimationButton") :: GuiButton
	self.estimatePriceText = self.frame:WaitForChild("EstimationText") :: TextLabel
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
	self.hoverHighlight = Instance.new("Highlight")
	self.hoverHighlight.Name = "CustomerHoverHighlight"
	self.hoverHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	self.hoverHighlight.FillColor = HighlightFillcolor
	self.hoverHighlight.FillTransparency = 1
	self.hoverHighlight.OutlineColor = HighlightOutlinecolor
	self.hoverHighlight.OutlineTransparency = 0
	self.hoverHighlight.Enabled = false
	self.hoverHighlight.Parent = Workspace

	if self.priceLabel then
		self.priceLabel.Text = "Price :"
	end

	AnimateButton(self.acceptButton)
	AnimateButton(self.declineButton)
	AnimateButton(self.estimateButton)
	AnimateButton(self.closeButton)

	self.acceptButton.Activated:Connect(function()
		self:Respond("Accept")
	end)

	self.declineButton.Activated:Connect(function()
		self:Respond("Decline")
	end)
	self.estimateButton.Activated:Connect(function()
		self:RequestPriceEstimate()
	end)
	self.closeButton.Activated:Connect(function()
		self:CloseOfferUi()
	end)

	self:ApplyUpgradeState(Remotemanager:InvokeServer("UpgradeService", "GetUpgrades"))
	self:HideInstant()
end

function Customercontroller:Start()
	Remotemanager:OnClientEvent("UpgradeService", "UpgradesUpdated", function(State)
		self:ApplyUpgradeState(State)
	end)

	local Offertoken = 0
	local function Applyoffer(Offer)
		Offertoken += 1
		local Token = Offertoken
		if Offer then
			local Isnewoffer = not self.pendingOffer or self.pendingOffer.Id ~= Offer.Id
			local Customer = Workspace:WaitForChild(Offer.CustomerName) :: Model
			if Token ~= Offertoken then
				return
			end
			Offer.Customer = Customer
			self.pendingOffer = Offer
			if Isnewoffer and Isgamepad(Userinputservice:GetLastInputType()) then
				Core:GetController("ComputerController"):FocusGamepadCustomer()
			end
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
