local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Daynightconfig = require(ReplicatedStorage.Shared.Config.DayNight)
local Objectconfig = require(ReplicatedStorage.Shared.Config.Object)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local Customerservice = {
	Name = "CustomerService",
	Priority = 15,
	Remotes = {
		OfferUpdated = "Event",
		RespondToOffer = "Function",
		RequestPriceEstimate = "Function",
	},
}

local QueueFolderName = "SpawnCustomer"
local TurnTweenDuration = 0.35
type CustomerOffer = {
	Id: number,
	ObjectKey: string,
	ObjectName: string,
	ImageId: string,
	BasePrice: number,
	Price: number,
	MaxValue: number,
	MaxReputation: number,
}

local AttachmentsByIndex: { [number]: Attachment } = {}
local OccupiedSlots: { [number]: Model } = {}
local QueueIndexes: { number } = {}
local HighestQueueIndex = 0
local CustomerSerial = 0
local OfferSerial = 0
local Customerfolder: Folder
local ObjectsByRarity: { [string]: { string } } = {}
local PendingOffer: CustomerOffer? = nil
local RefreshFrontCustomerAttribute: () -> ()
local PresentFrontOffer: () -> ()
local CurrentDay = 1
local SpawnedCustomersToday = 0
local ArrivedCustomersToday = 0

local function GetShopPlayer(): Player?
	return Players:GetPlayers()[1]
end

local function GetMaxCustomersPerDay(): number
	local Player = GetShopPlayer()
	if not Player then
		return 0
	end
	return math.max(math.floor(Core:GetService("UpgradeService"):GetValue(Player, "DailyCustomers")), 0)
end

local function ReplicateCustomerCount()
	Lighting:SetAttribute("CustomersToday", ArrivedCustomersToday)
	Lighting:SetAttribute("MaxCustomersPerDay", GetMaxCustomersPerDay())
end

local function SyncDayState()
	local Day = Lighting:GetAttribute("Day") or 1
	if Day ~= CurrentDay then
		CurrentDay = Day
		SpawnedCustomersToday = 0
		ArrivedCustomersToday = 0
	end
	ReplicateCustomerCount()
end

local function MarkCustomerArrivedAtSlot1(Customer: Model)
	Customer:SetAttribute("ArrivedAtSlot1", true)
	if Customer:GetAttribute("CountedAtSlot1") == true then
		return
	end

	Customer:SetAttribute("CountedAtSlot1", true)
	ArrivedCustomersToday += 1
	ReplicateCustomerCount()
end

local function IsBusinessHours(): boolean
	local ClockTime = Lighting.ClockTime
	return ClockTime >= Daynightconfig.DayStartHour and ClockTime < Daynightconfig.NightStartHour
end

local function CanSpawnMoreCustomersToday(): boolean
	SyncDayState()
	return SpawnedCustomersToday < GetMaxCustomersPerDay()
end

local function CollectQueueAttachments()
	table.clear(AttachmentsByIndex)
	table.clear(QueueIndexes)
	HighestQueueIndex = 0

	local Folder = Workspace:WaitForChild(QueueFolderName)

	for _, Child in ipairs(Folder:GetChildren()) do
		if Child:IsA("Attachment") then
			local Index = tonumber(Child.Name)
			if Index then
				AttachmentsByIndex[Index] = Child
				if Index > 0 then
					table.insert(QueueIndexes, Index)
					HighestQueueIndex = math.max(HighestQueueIndex, Index)
				end
			end
		end
	end

	table.sort(QueueIndexes, function(Left, Right)
		return Left > Right
	end)

end

local function CollectOfferObjects()
	for _, Rarity in ipairs(Objectconfig.Offer.Rarities) do
		ObjectsByRarity[Rarity] = {}
	end

	for ObjectKey, Definition in pairs(Objectconfig.Object) do
		local Rarity = Definition.Rarity
		if Rarity ~= "Exclusive" then
			table.insert(ObjectsByRarity[Rarity], ObjectKey)
		end
	end

	for _, Rarity in ipairs(Objectconfig.Offer.Rarities) do
		table.sort(ObjectsByRarity[Rarity])
	end
end

local function GetTargetCFrame(Attachment: Attachment): CFrame
	return Attachment.WorldCFrame
end

local function GetPivotWithPosition(Pivot: CFrame, Position: Vector3): CFrame
	local _, _, _, R00, R01, R02, R10, R11, R12, R20, R21, R22 = Pivot:GetComponents()
	return CFrame.new(Position.X, Position.Y, Position.Z, R00, R01, R02, R10, R11, R12, R20, R21, R22)
end

local function FacePosition(Customer: Model, Position: Vector3)
	local Pivot = Customer:GetPivot()
	local CurrentPosition = Pivot.Position
	local FlatTarget = Vector3.new(Position.X, CurrentPosition.Y, Position.Z)
	local Direction = FlatTarget - CurrentPosition
	if Direction.Magnitude <= 0.001 then
		return
	end

	Customer:PivotTo(CFrame.lookAt(CurrentPosition, FlatTarget))
end

local function TweenCustomerFacing(Customer: Model, TargetCFrame: CFrame, Duration: number): (() -> ())?
	local RotationValue = Instance.new("CFrameValue")
	RotationValue.Value = Customer:GetPivot()

	local Connection = RotationValue:GetPropertyChangedSignal("Value"):Connect(function()
		if not Customer.Parent then
			return
		end

		Customer:PivotTo(GetPivotWithPosition(RotationValue.Value, Customer:GetPivot().Position))
	end)

	local Tween = TweenService:Create(RotationValue, TweenInfo.new(Duration, Enum.EasingStyle.Linear), {
		Value = TargetCFrame,
	})
	Tween:Play()

	return function()
		Tween:Cancel()
		Connection:Disconnect()
		RotationValue:Destroy()
	end
end

local function TweenCustomerTurn(Customer: Model, Degrees: number, Duration: number)
	local TargetCFrame = Customer:GetPivot() * CFrame.Angles(0, math.rad(Degrees), 0)
	local StopTween = TweenCustomerFacing(Customer, TargetCFrame, Duration)
	task.delay(Duration, function()
		if StopTween then
			StopTween()
		end
	end)
end

local function CreateCustomerInstance(): Model
	local Customercount = #Customerfolder:GetChildren()
	local Template = Customerfolder:WaitForChild(tostring(math.random(1, Customercount))) :: Model
	local Customer = Template:Clone()

	CustomerSerial += 1
	Customer.Name = string.format("Customer_%d", CustomerSerial)
	Customer:SetAttribute("QueueCustomerInstance", true)
	Customer:SetAttribute("IsFrontCustomer", false)
	Customer:SetAttribute("ArrivedAtSlot1", false)
	Customer.Parent = Workspace

	if not Customer.PrimaryPart then
		local Root = Customer:FindFirstChild("HumanoidRootPart")
		if Root and Root:IsA("BasePart") then
			Customer.PrimaryPart = Root
		else
			local FirstPart = Customer:FindFirstChildWhichIsA("BasePart", true)
			if FirstPart then
				Customer.PrimaryPart = FirstPart
			end
		end
	end

	for _, Descendant in ipairs(Customer:GetDescendants()) do
		if Descendant:IsA("BasePart") then
			Descendant.Anchored = false
			Descendant.CanCollide = false
		end
	end

	local Humanoid = Customer:FindFirstChildWhichIsA("Humanoid")
	if Humanoid then
		Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		Humanoid.BreakJointsOnDeath = false
	end

	return Customer
end

local function MoveCustomerTo(Customer: Model, Attachment: Attachment, OnComplete: (() -> ())?)
	local Humanoid = Customer:FindFirstChildWhichIsA("Humanoid")
	local ShouldTurnAtArrival = Attachment.Name == "1"
	Customer:SetAttribute("ArrivedAtSlot1", false)
	if not Humanoid then
		warn(string.format("CustomerService: %s n'a pas de Humanoid, déplacement instantané utilisé", Customer.Name))
		Customer:PivotTo(GetTargetCFrame(Attachment))
		if ShouldTurnAtArrival then
			TweenCustomerTurn(Customer, 90, TurnTweenDuration)
			Customer:SetAttribute("TurnedAtSlot1", true)
			MarkCustomerArrivedAtSlot1(Customer)
		end
		if OnComplete then
			OnComplete()
		end
		return
	end

	local function StartMove()
		local TargetPosition = Attachment.WorldPosition
		Humanoid.AutoRotate = true
		FacePosition(Customer, TargetPosition)
		Humanoid:MoveTo(TargetPosition)

		task.spawn(function()
			local Reached = false
			local Connection
			Connection = Humanoid.MoveToFinished:Connect(function(DidReach)
				Reached = true
				Connection:Disconnect()
				if not DidReach and Customer.Parent then
					Customer:PivotTo(GetTargetCFrame(Attachment))
				end

				if Customer.Parent then
					Humanoid.AutoRotate = true
					if ShouldTurnAtArrival then
						TweenCustomerTurn(Customer, 90, TurnTweenDuration)
						Customer:SetAttribute("TurnedAtSlot1", true)
						MarkCustomerArrivedAtSlot1(Customer)
					end
				end
				if OnComplete and Customer.Parent then
					OnComplete()
				end
			end)

			task.wait(4)
			if not Reached and Customer.Parent then
				Connection:Disconnect()
				Customer:PivotTo(GetTargetCFrame(Attachment))
				Humanoid.AutoRotate = true
				if ShouldTurnAtArrival then
					TweenCustomerTurn(Customer, 90, TurnTweenDuration)
					Customer:SetAttribute("TurnedAtSlot1", true)
					MarkCustomerArrivedAtSlot1(Customer)
				end
				if OnComplete then
					OnComplete()
				end
			end
		end)
	end

	StartMove()
end

local function SpawnCustomerAt(Index: number)
	local Attachment = AttachmentsByIndex[Index]
	if not Attachment or OccupiedSlots[Index] then
		return
	end
	if not IsBusinessHours() or not CanSpawnMoreCustomersToday() then
		return
	end

	local Customer = CreateCustomerInstance()
	Customer:PivotTo(GetTargetCFrame(Attachment))
	Customer:SetAttribute("ArrivedAtSlot1", Index == 1)
	OccupiedSlots[Index] = Customer
	SpawnedCustomersToday += 1
	if Index == 1 then
		MarkCustomerArrivedAtSlot1(Customer)
	end
	RefreshFrontCustomerAttribute()
	if Index == 1 then
		task.defer(function()
			PresentFrontOffer()
		end)
	end
end

local function DespawnCustomer(Customer: Model)
	Customer:Destroy()
end

local function GetFrontCustomer(): Model?
	return OccupiedSlots[1]
end

RefreshFrontCustomerAttribute = function()
	for Index, Customer in pairs(OccupiedSlots) do
		if Customer and Customer.Parent then
			Customer:SetAttribute("IsFrontCustomer", Index == 1)
		end
	end
end

local function BroadcastOffer(Offer: CustomerOffer?)
	if not Offer then
		Remotemanager:FireAllClients(Customerservice.Name, "OfferUpdated", nil)
		return
	end
	Remotemanager:FireAllClients(Customerservice.Name, "OfferUpdated", {
		Id = Offer.Id,
		ObjectKey = Offer.ObjectKey,
		ObjectName = Offer.ObjectName,
		ImageId = Offer.ImageId,
		Price = Offer.Price,
	})
end

local function GetOfferChances(Reputation: number)
	local Reputationtiers = Objectconfig.Offer.ReputationTiers
	local Chances = Reputationtiers[1].Chances
	for _, Tier in ipairs(Reputationtiers) do
		if Reputation < Tier.MinimumReputation then
			break
		end
		Chances = Tier.Chances
	end
	return Chances
end

local function ChooseObjectKey(Player: Player): string
	local Reputation = Core:GetService("StatsService"):GetStats(Player).Reputation
	local Chances = GetOfferChances(Reputation)
	local Totalchance = 0
	for _, Rarity in ipairs(Objectconfig.Offer.Rarities) do
		local Chance = Chances[Rarity] or 0
		if Chance > 0 and #ObjectsByRarity[Rarity] > 0 then
			Totalchance += Chance
		end
	end

	local Roll = math.random() * Totalchance
	local Accumulatedchance = 0
	for _, Rarity in ipairs(Objectconfig.Offer.Rarities) do
		local Chance = Chances[Rarity] or 0
		local Objectpool = ObjectsByRarity[Rarity]
		if Chance > 0 and #Objectpool > 0 then
			Accumulatedchance += Chance
			if Roll < Accumulatedchance then
				return Objectpool[math.random(1, #Objectpool)]
			end
		end
	end

	error("CustomerService: aucun objet disponible pour les offres")
end

local function ChooseCustomerRequest(Player: Player): CustomerOffer
	local ObjectKey = ChooseObjectKey(Player)
	local Definition = Objectconfig.Object[ObjectKey]

	local Maxprice = math.max(tonumber(Definition.PriceMaxValue) or tonumber(Definition.MaxPrice) or tonumber(Definition.MaxValue) or 0, 0)
	local Minprice = math.max(
		math.min(
			tonumber(Definition.PriceMinValue) or Maxprice,
			Maxprice
		),
		0
	)
	OfferSerial += 1
	local UpgradeDiscount = Core:GetService("UpgradeService"):GetValue(Player, "PurchaseDiscount")
	local VIPDiscount = Core:GetService("MonetizationService"):GetVIPCustomerDiscount(Player)
	local DiscountPercent = math.clamp(UpgradeDiscount + VIPDiscount, 0, 100)
	local BasePrice = math.random(Minprice, math.max(Minprice, Maxprice))
	local DiscountedPrice = math.max(math.round(BasePrice * (1 - DiscountPercent / 100)), 0)
	local Maximums = Core:GetService("RestorationService"):GenerateObjectMaximums(ObjectKey)

	return {
		Id = OfferSerial,
		ObjectKey = ObjectKey,
		ObjectName = Definition.Name or ObjectKey,
		ImageId = tostring(Definition.IdImage or ""),
		BasePrice = BasePrice,
		Price = DiscountedPrice,
		MaxValue = Maximums.MaxValue,
		MaxReputation = Maximums.MaxReputation,
	}
end

function Customerservice:RefreshPendingOfferPrice(Player: Player)
	if not PendingOffer then return end
	local UpgradeDiscount = Core:GetService("UpgradeService"):GetValue(Player, "PurchaseDiscount")
	local VIPDiscount = Core:GetService("MonetizationService"):GetVIPCustomerDiscount(Player)
	local DiscountPercent = math.clamp(UpgradeDiscount + VIPDiscount, 0, 100)
	PendingOffer.Price = math.max(math.round(PendingOffer.BasePrice * (1 - DiscountPercent / 100)), 0)
	BroadcastOffer(PendingOffer)
end

local function AdvanceQueue()
	if HighestQueueIndex <= 0 or not AttachmentsByIndex[0] then
		return
	end

	local NewOccupiedSlots: { [number]: Model } = {}
	local FrontCustomer = OccupiedSlots[1]
	local QueueDelay = 0
	if FrontCustomer and FrontCustomer:GetAttribute("TurnedAtSlot1") == true then
		FrontCustomer:SetAttribute("TurnedAtSlot1", false)
		TweenCustomerTurn(FrontCustomer, -90, TurnTweenDuration)
		QueueDelay = TurnTweenDuration
	end

	local function StartQueueMove(Callback: () -> ())
		if QueueDelay > 0 then
			task.delay(QueueDelay, Callback)
			return
		end
		Callback()
	end

	for _, Index in ipairs(QueueIndexes) do
		local Customer = OccupiedSlots[Index]
		if not Customer then
			continue
		end

		local NextIndex = Index - 1
		local TargetAttachment = AttachmentsByIndex[NextIndex]
		if not TargetAttachment then
			NewOccupiedSlots[Index] = Customer
			continue
		end

		if NextIndex == 0 then
			StartQueueMove(function()
				MoveCustomerTo(Customer, TargetAttachment, function()
					DespawnCustomer(Customer)
				end)
			end)
		else
			NewOccupiedSlots[NextIndex] = Customer
			StartQueueMove(function()
				MoveCustomerTo(Customer, TargetAttachment, function()
					if NextIndex == 1 then
						PresentFrontOffer()
					end
				end)
			end)
		end
	end

	OccupiedSlots = NewOccupiedSlots
	RefreshFrontCustomerAttribute()

	if not OccupiedSlots[HighestQueueIndex] then
		StartQueueMove(function()
			SpawnCustomerAt(HighestQueueIndex)
		end)
	end
end

local function ClearPendingOffer()
	PendingOffer = nil
	BroadcastOffer(nil)
end

local function CanPresentOffer(): boolean
	local Restorationservice = Core:GetService("RestorationService")
	return not PendingOffer
		and not Restorationservice:HasActiveSession()
		and not Restorationservice:HasActiveObject()
end

PresentFrontOffer = function()
	if not CanPresentOffer() then
		return
	end
	local FrontCustomer = GetFrontCustomer()
	if not FrontCustomer or FrontCustomer:GetAttribute("ArrivedAtSlot1") ~= true then
		return
	end

	local Player = GetShopPlayer()
	if not Player then
		return
	end
	PendingOffer = ChooseCustomerRequest(Player)
	if PendingOffer then
		BroadcastOffer(PendingOffer)
	end
end

function Customerservice:Init()
	CollectQueueAttachments()
	CollectOfferObjects()
	Customerfolder = ReplicatedStorage:WaitForChild("Asset"):WaitForChild("Customer") :: Folder
	SyncDayState()
	Lighting:GetAttributeChangedSignal("Day"):Connect(SyncDayState)
	Players.PlayerAdded:Connect(function()
		task.defer(function()
			self:RefreshCustomerLimit()
		end)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			self:RefreshCustomerLimit()
		end)
	end)

	Remotemanager:OnServerInvoke(self.Name, "RequestPriceEstimate", function(Player, OfferId)
		if not PendingOffer or PendingOffer.Id ~= tonumber(OfferId) then
			return { Success = false, Reason = "OfferUnavailable" }
		end
		if not Core:GetService("UpgradeService"):ConsumePriceEstimate(Player) then
			return { Success = false, Reason = "NoEstimatesRemaining" }
		end
		return {
			Success = true,
			MaxPrice = PendingOffer.MaxValue,
		}
	end)

	Remotemanager:OnServerInvoke(self.Name, "RespondToOffer", function(Player, OfferId, Decision)
		local FrontCustomer = GetFrontCustomer()
		if not PendingOffer
			or PendingOffer.Id ~= OfferId
			or not FrontCustomer
			or FrontCustomer:GetAttribute("ArrivedAtSlot1") ~= true
		then
			return {
				Success = false,
				Reason = "OfferUnavailable",
			}
		end

		local NormalizedDecision = string.lower(tostring(Decision))
		if NormalizedDecision == "accept" then
			local Cashservice = Core:GetService("CashService")
			if not Cashservice:SpendCash(Player, PendingOffer.Price) then
				return {
					Success = false,
					Reason = "NotEnoughCash",
				}
			end
			local Restorationservice = Core:GetService("RestorationService")
			local Restorationobject = Restorationservice:PrepareObject(PendingOffer.ObjectKey, Player, {
				MaxValue = PendingOffer.MaxValue,
				MaxReputation = PendingOffer.MaxReputation,
			})
			Restorationobject:SetAttribute("PurchasePrice", PendingOffer.Price)
			local ExitAttachment = AttachmentsByIndex[0]
			OccupiedSlots[1] = nil
			FrontCustomer:SetAttribute("IsFrontCustomer", false)
			FrontCustomer:SetAttribute("ArrivedAtSlot1", false)
			RefreshFrontCustomerAttribute()
			ClearPendingOffer()
			if ExitAttachment then
				MoveCustomerTo(FrontCustomer, ExitAttachment, function()
					DespawnCustomer(FrontCustomer)
				end)
			else
				DespawnCustomer(FrontCustomer)
			end
			return {
				Success = true,
			}
		end

	if NormalizedDecision == "decline" then
		local ExitAttachment = AttachmentsByIndex[0]
		OccupiedSlots[1] = nil
		FrontCustomer:SetAttribute("IsFrontCustomer", false)
		FrontCustomer:SetAttribute("ArrivedAtSlot1", false)
		RefreshFrontCustomerAttribute()
		ClearPendingOffer()
		if ExitAttachment then
			MoveCustomerTo(FrontCustomer, ExitAttachment, function()
				DespawnCustomer(FrontCustomer)
			end)
		else
			DespawnCustomer(FrontCustomer)
		end
		AdvanceQueue()
		return {
			Success = true,
		}
	end

		return {
			Success = false,
			Reason = "InvalidDecision",
		}
	end)
end

function Customerservice:RefreshCustomerLimit()
	ReplicateCustomerCount()
	if HighestQueueIndex <= 0 or not AttachmentsByIndex[0] then
		return
	end
	if IsBusinessHours()
		and CanSpawnMoreCustomersToday()
		and not OccupiedSlots[HighestQueueIndex]
	then
		SpawnCustomerAt(HighestQueueIndex)
	end
end

function Customerservice:Start()
	if HighestQueueIndex <= 0 or not AttachmentsByIndex[0] then
		return
	end

	if IsBusinessHours() and CanSpawnMoreCustomersToday() then
		SpawnCustomerAt(HighestQueueIndex)
	end

	task.spawn(function()
		while true do
			task.wait(5)
			SyncDayState()
			if PendingOffer then
				continue
			end
			if not IsBusinessHours() then
				continue
			end

			local Restorationservice = Core:GetService("RestorationService")
			if Restorationservice:HasActiveSession() or Restorationservice:HasActiveObject() then
				continue
			end

			if GetFrontCustomer() then
				PresentFrontOffer()
			else
				AdvanceQueue()
			end
		end
	end)
end

return Customerservice
