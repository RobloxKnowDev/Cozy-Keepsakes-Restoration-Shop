local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Daynightconfig = require(ReplicatedStorage.Shared.Config.DayNight)
local Objectconfig = require(ReplicatedStorage.Shared.Config.Object)
local Rarityconfig = require(ReplicatedStorage.Shared.Config.Rarity)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local Customerservice = {
	Name = "CustomerService",
	Priority = 15,
	Remotes = {
		OfferUpdated = "Event",
		GetPendingOffer = "Function",
		RespondToOffer = "Function",
		RequestPriceEstimate = "Function",
	},
}

local QueueFolderName = "SpawnCustomer"
local TurnTweenDuration = 0.35
local SlotTurnDegrees = -90
local FastEntryIndex = 1
local WalkInStuds = 12
local WalkInFadeDuration = 0.4
local Verbosespawnlogs = true
local MaxFriendProfiles = 60
local PrefetchedFriendCount = 3
local FallbackCustomerTemplate = "1"
type CustomerOffer = {
	Id: number,
	ObjectKey: string,
	ObjectName: string,
	ImageId: string,
	BasePrice: number,
	Price: number,
	MaxValue: number,
	MaxReputation: number,
	Mutation: string,
	Emergency: boolean,
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
local ArrivedCustomersToday = 0
local FriendProfiles: { { Id: number, Name: string } } = {}
local FriendCursor = 0
local DescriptionsByUserId: { [number]: HumanoidDescription } = {}

local function Spawnlog(Message: string)
	if Verbosespawnlogs then
		print("[Customer] " .. Message)
	end
end

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

local function PendingCustomerCount(): number
	local Count = 0
	for _, Customer in pairs(OccupiedSlots) do
		if Customer.Parent and Customer:GetAttribute("CountedAtSlot1") ~= true then
			Count += 1
		end
	end
	return Count
end

local function CanSpawnMoreCustomersToday(): boolean
	SyncDayState()
	return ArrivedCustomersToday + PendingCustomerCount() < GetMaxCustomersPerDay()
end

local function CollectQueueAttachments()
	table.clear(AttachmentsByIndex)
	table.clear(QueueIndexes)
	HighestQueueIndex = 0

	local Folder = Workspace:WaitForChild("Map"):WaitForChild("Slot1"):WaitForChild(QueueFolderName)

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
	for _, Rarity in ipairs(Rarityconfig.Order) do
		ObjectsByRarity[Rarity] = {}
	end

	for ObjectKey, Definition in pairs(Objectconfig.Object) do
		local Rarity = Definition.Rarity
		if Rarity ~= "Exclusive" then
			table.insert(ObjectsByRarity[Rarity], ObjectKey)
		end
	end

	for _, Rarity in ipairs(Rarityconfig.Order) do
		table.sort(ObjectsByRarity[Rarity])
	end
end

local function GetTargetCFrame(Attachment: Attachment): CFrame
	return Attachment.WorldCFrame
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

local function TweenCustomerTurn(Customer: Model, Degrees: number, Duration: number, OnComplete: (() -> ())?)
	local StartCFrame = Customer:GetPivot()
	local Angle = Instance.new("NumberValue")
	local Connection = Angle:GetPropertyChangedSignal("Value"):Connect(function()
		if Customer.Parent then
			Customer:PivotTo(StartCFrame * CFrame.Angles(0, math.rad(Angle.Value), 0))
		end
	end)
	local Tween = TweenService:Create(Angle, TweenInfo.new(Duration, Enum.EasingStyle.Linear), {
		Value = Degrees,
	})
	Tween.Completed:Once(function()
		Connection:Disconnect()
		if Customer.Parent then
			Customer:PivotTo(StartCFrame * CFrame.Angles(0, math.rad(Degrees), 0))
			if OnComplete then
				OnComplete()
			end
		end
		Angle:Destroy()
	end)
	Tween:Play()
end

local function NormalizeCustomerParts(Customer: Model)
	for _, Descendant in ipairs(Customer:GetDescendants()) do
		if Descendant:IsA("BasePart") then
			Descendant.Anchored = false
			Descendant.CanCollide = false
		end
	end
end

local function GetFriendDescription(UserId: number): HumanoidDescription?
	local Cached = DescriptionsByUserId[UserId]
	if Cached then
		return Cached
	end
	local Success, Description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(UserId)
	end)
	if not Success then
		return nil
	end
	DescriptionsByUserId[UserId] = Description
	return Description
end

local function LoadFriendProfiles(Player: Player)
	local Success, Pages = pcall(function()
		return Players:GetFriendsAsync(Player.UserId)
	end)
	if not Success then
		return
	end

	local Profiles = {}
	while #Profiles < MaxFriendProfiles do
		for _, Entry in ipairs(Pages:GetCurrentPage()) do
			table.insert(Profiles, { Id = Entry.Id, Name = tostring(Entry.DisplayName or Entry.Username) })
		end
		if Pages.IsFinished then
			break
		end
		if not pcall(function() Pages:AdvanceToNextPageAsync() end) then
			break
		end
	end

	for Index = #Profiles, 2, -1 do
		local Swap = math.random(Index)
		Profiles[Index], Profiles[Swap] = Profiles[Swap], Profiles[Index]
	end
	FriendProfiles = Profiles
	FriendCursor = 0

	for Index = 1, math.min(PrefetchedFriendCount, #Profiles) do
		GetFriendDescription(Profiles[Index].Id)
	end
end

local function ApplyFriendAppearance(Customer: Model)
	if #FriendProfiles == 0 then
		return
	end
	local Humanoid = Customer:FindFirstChildWhichIsA("Humanoid")
	if not Humanoid then
		return
	end

	FriendCursor = FriendCursor % #FriendProfiles + 1
	local Profile = FriendProfiles[FriendCursor]
	Customer:SetAttribute("FriendUserId", Profile.Id)
	Customer:SetAttribute("FriendName", Profile.Name)

	local function Apply()
		local Description = GetFriendDescription(Profile.Id)
		if not Description or not Customer.Parent or not Humanoid.Parent then
			Spawnlog(string.format("skin %s SKIPPED for %s", Profile.Name, Customer.Name))
			return
		end
		local Success, Error = pcall(function()
			Humanoid:ApplyDescription(Description:Clone())
		end)
		Spawnlog(string.format(
			"skin %s on %s: %s",
			Profile.Name,
			Customer.Name,
			if Success then "ok" else tostring(Error)
		))
		NormalizeCustomerParts(Customer)
	end

	task.spawn(Apply)
end

local function CreateCustomerInstance(): Model
	local Template = Customerfolder:WaitForChild(FallbackCustomerTemplate) :: Model
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

	NormalizeCustomerParts(Customer)

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
	local function FinishArrival()
		Customer:PivotTo(GetTargetCFrame(Attachment))
		if Humanoid then
			Humanoid:Move(Vector3.zero)
			Humanoid.AutoRotate = not ShouldTurnAtArrival
		end
		if ShouldTurnAtArrival then
			TweenCustomerTurn(Customer, SlotTurnDegrees, TurnTweenDuration, function()
				Customer:SetAttribute("TurnedAtSlot1", true)
				MarkCustomerArrivedAtSlot1(Customer)
				if OnComplete then
					OnComplete()
				end
			end)
		elseif OnComplete then
			OnComplete()
		end
	end
	if not Humanoid then
		warn(string.format("CustomerService: %s has no Humanoid, teleporting instead", Customer.Name))
		FinishArrival()
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
			Connection = Humanoid.MoveToFinished:Connect(function()
				Reached = true
				Connection:Disconnect()
				if Customer.Parent then
					FinishArrival()
				end
			end)

			task.wait(4)
			if not Reached and Customer.Parent then
				Connection:Disconnect()
				FinishArrival()
			end
		end)
	end

	StartMove()
end

local function GetEntryCFrame(Index: number): CFrame
	local Back = AttachmentsByIndex[HighestQueueIndex]
	if Index < HighestQueueIndex then
		return Back.WorldCFrame
	end
	local Ahead = AttachmentsByIndex[HighestQueueIndex - 1]
	if not Ahead then
		return Back.WorldCFrame
	end
	local Direction = Back.WorldPosition - Ahead.WorldPosition
	if Direction.Magnitude <= 0.001 then
		return Back.WorldCFrame
	end
	return Back.WorldCFrame + Direction.Unit * WalkInStuds
end

local function FadeCustomerIn(Customer: Model)
	local Transparencies: { [Instance]: number } = {}
	for _, Descendant in ipairs(Customer:GetDescendants()) do
		if Descendant:IsA("BasePart") or Descendant:IsA("Decal") then
			Transparencies[Descendant] = Descendant.Transparency
			Descendant.Transparency = 1
		end
	end
	for Descendant, Transparency in pairs(Transparencies) do
		TweenService:Create(Descendant, TweenInfo.new(WalkInFadeDuration), { Transparency = Transparency }):Play()
	end
end

local function SpawnCustomerAt(Index: number)
	local Attachment = AttachmentsByIndex[Index]
	if not Attachment then
		Spawnlog(string.format("spawn %d REFUSED: no attachment (highest=%d)", Index, HighestQueueIndex))
		return
	end
	if OccupiedSlots[Index] then
		Spawnlog(string.format("spawn %d REFUSED: slot occupied", Index))
		return
	end
	if not IsBusinessHours() then
		Spawnlog(string.format("spawn %d REFUSED: closed (clock=%.2f)", Index, Lighting.ClockTime))
		return
	end
	if not CanSpawnMoreCustomersToday() then
		Spawnlog(string.format(
			"spawn %d REFUSED: daily cap (arrived=%d pending=%d max=%d)",
			Index,
			ArrivedCustomersToday,
			PendingCustomerCount(),
			GetMaxCustomersPerDay()
		))
		return
	end

	Spawnlog(string.format("spawn %d accepted", Index))
	local Customer = CreateCustomerInstance()
	Spawnlog(string.format("spawn %d instance ready: %s", Index, Customer.Name))
	OccupiedSlots[Index] = Customer

	if Index == 1 then
		Customer:PivotTo(GetTargetCFrame(Attachment) * CFrame.Angles(0, math.rad(SlotTurnDegrees), 0))
		ApplyFriendAppearance(Customer)
		Customer:SetAttribute("ArrivedAtSlot1", true)
		Customer:SetAttribute("TurnedAtSlot1", true)
		local Humanoid = Customer:FindFirstChildWhichIsA("Humanoid")
		if Humanoid then
			Humanoid.AutoRotate = false
		end
		MarkCustomerArrivedAtSlot1(Customer)
		RefreshFrontCustomerAttribute()
		task.defer(function()
			PresentFrontOffer()
		end)
		return
	end

	Customer:PivotTo(GetEntryCFrame(Index) * CFrame.Angles(0, math.pi, 0))
	ApplyFriendAppearance(Customer)
	FadeCustomerIn(Customer)
	RefreshFrontCustomerAttribute()
	MoveCustomerTo(Customer, Attachment)
end

local function SpawnNextCustomer()
	if not next(OccupiedSlots) then
		Spawnlog("next: queue empty")
		SpawnCustomerAt(math.min(FastEntryIndex, HighestQueueIndex))
		return
	end
	if not OccupiedSlots[HighestQueueIndex] then
		Spawnlog("next: filling back slot")
		SpawnCustomerAt(HighestQueueIndex)
		return
	end
	Spawnlog("next: queue already full")
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

local function GetOfferPayload(Offer: CustomerOffer?)
	if not Offer then
		return nil
	end
	local Customer = GetFrontCustomer() :: Model
	return {
		Id = Offer.Id,
		CustomerName = Customer.Name,
		ObjectKey = Offer.ObjectKey,
		ObjectName = Offer.ObjectName,
		ImageId = Offer.ImageId,
		Price = Offer.Price,
		Emergency = Offer.Emergency,
	}
end

local function BroadcastOffer(Offer: CustomerOffer?)
	Remotemanager:FireAllClients(Customerservice.Name, "OfferUpdated", GetOfferPayload(Offer))
end

local function GetOfferLuck(Reputation: number): number
	local Progress = math.min(math.max(Reputation, 0) / Rarityconfig.FullLuckReputation, 1) ^ Rarityconfig.LuckCurve
	return 1 + (Rarityconfig.MaximumLuck - 1) * Progress
end

local function GetOfferChances(Reputation: number)
	local Luck = GetOfferLuck(Reputation)
	local Chances = {}
	for Index, Rarity in ipairs(Rarityconfig.Order) do
		Chances[Rarity] = Rarityconfig[Rarity].Weight * Luck ^ (Index - 1)
	end
	return Chances
end

local function ChooseObjectKey(Player: Player): string
	if Core:GetService("TutorialService"):IsActive(Player) then
		return Objectconfig.Offer.TutorialObject
	end
	local Reputation = Core:GetService("StatsService"):GetStats(Player).Reputation
	local Chances = GetOfferChances(Reputation)
	local Totalchance = 0
	for _, Rarity in ipairs(Rarityconfig.Order) do
		local Chance = Chances[Rarity] or 0
		if Chance > 0 and #ObjectsByRarity[Rarity] > 0 then
			Totalchance += Chance
		end
	end

	local Roll = math.random() * Totalchance
	local Accumulatedchance = 0
	for _, Rarity in ipairs(Rarityconfig.Order) do
		local Chance = Chances[Rarity] or 0
		local Objectpool = ObjectsByRarity[Rarity]
		if Chance > 0 and #Objectpool > 0 then
			Accumulatedchance += Chance
			if Roll < Accumulatedchance then
				return Objectpool[math.random(1, #Objectpool)]
			end
		end
	end

	error("CustomerService: no object available for offers")
end

local function ChooseCustomerRequest(Player: Player): CustomerOffer
	local ObjectKey = ChooseObjectKey(Player)
	local Definition = Objectconfig.Object[ObjectKey]

	local Maxprice = math.max(
		tonumber(Definition.PriceMaxValue) or tonumber(Definition.MaxPrice) or tonumber(Definition.MaxValue) or 0,
		0
	)
	local Minprice = math.max(math.min(tonumber(Definition.PriceMinValue) or Maxprice, Maxprice), 0)
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
		Mutation = Maximums.Mutation,
		Emergency = false,
	}
end

local function ChooseEmergencyRequest(): CustomerOffer
	local ObjectKey = Objectconfig.Offer.EmergencyObject
	local Definition = Objectconfig.Object[ObjectKey]
	local Maximums = Core:GetService("RestorationService"):GenerateObjectMaximums(ObjectKey)
	OfferSerial += 1
	return {
		Id = OfferSerial,
		ObjectKey = ObjectKey,
		ObjectName = Definition.Name or ObjectKey,
		ImageId = tostring(Definition.IdImage or ""),
		BasePrice = 0,
		Price = 0,
		MaxValue = Maximums.MaxValue,
		MaxReputation = Maximums.MaxReputation,
		Mutation = Maximums.Mutation,
		Emergency = true,
	}
end

local function GetAffordableOfferThreshold(Player: Player): number
	local Cheapestprice = math.huge
	for _, Definition in pairs(Objectconfig.Object) do
		if Definition.Rarity ~= "Exclusive" then
			local Maxprice = math.max(
				tonumber(Definition.PriceMaxValue) or tonumber(Definition.MaxPrice) or tonumber(Definition.MaxValue) or 0,
				0
			)
			local Minprice = math.max(math.min(tonumber(Definition.PriceMinValue) or Maxprice, Maxprice), 0)
			local Affordableprice = Minprice + (Maxprice - Minprice) * Objectconfig.Offer.EmergencyPriceMargin
			Cheapestprice = math.min(Cheapestprice, Affordableprice)
		end
	end
	local UpgradeDiscount = Core:GetService("UpgradeService"):GetValue(Player, "PurchaseDiscount")
	local VIPDiscount = Core:GetService("MonetizationService"):GetVIPCustomerDiscount(Player)
	local DiscountPercent = math.clamp(UpgradeDiscount + VIPDiscount, 0, 100)
	return math.max(math.round(Cheapestprice * (1 - DiscountPercent / 100)), 0)
end

function Customerservice:RefreshPendingOfferPrice(Player: Player)
	if not PendingOffer then
		return
	end
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
	local QueueReady = true
	local QueuedMoves: { () -> () } = {}
	if FrontCustomer and FrontCustomer:GetAttribute("TurnedAtSlot1") == true then
		FrontCustomer:SetAttribute("TurnedAtSlot1", false)
		QueueReady = false
		TweenCustomerTurn(FrontCustomer, -SlotTurnDegrees, TurnTweenDuration, function()
			QueueReady = true
			for _, Callback in ipairs(QueuedMoves) do
				Callback()
			end
		end)
	end

	local function StartQueueMove(Callback: () -> ())
		if not QueueReady then
			table.insert(QueuedMoves, Callback)
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

	StartQueueMove(SpawnNextCustomer)
end

local function ClearPendingOffer()
	PendingOffer = nil
	BroadcastOffer(nil)
end

local function CanPresentOffer(): boolean
	local Restorationservice = Core:GetService("RestorationService")
	return not PendingOffer and not Restorationservice:HasActiveSession() and not Restorationservice:HasActiveObject()
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
	if not Core:GetService("TutorialService"):CanTakeNewObject(Player) then
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
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(LoadFriendProfiles, Player)
	end
	Players.PlayerAdded:Connect(function(Player)
		task.spawn(LoadFriendProfiles, Player)
		task.defer(function()
			self:RefreshCustomerLimit()
		end)
	end)
	Players.PlayerRemoving:Connect(function()
		FriendProfiles = {}
		FriendCursor = 0
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
			Mutation = PendingOffer.Mutation,
		}
	end)

	Remotemanager:OnServerInvoke(self.Name, "GetPendingOffer", function()
		return GetOfferPayload(PendingOffer)
	end)

	Remotemanager:OnServerInvoke(self.Name, "RespondToOffer", function(Player, OfferId, Decision)
		local FrontCustomer = GetFrontCustomer()
		if
			not PendingOffer
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
				if Cashservice:CanSpendCash(Player, GetAffordableOfferThreshold(Player)) then
					return {
						Success = false,
						Reason = "NotEnoughCash",
					}
				end
				PendingOffer = ChooseEmergencyRequest()
				BroadcastOffer(PendingOffer)
				return {
					Success = false,
					Reason = "EmergencyOfferPresented",
				}
			end
			Core:GetService("InventoryService"):AddPurchasedItem(Player, PendingOffer.ObjectKey, {
				MaxValue = PendingOffer.MaxValue,
				MaxReputation = PendingOffer.MaxReputation,
				Mutation = PendingOffer.Mutation,
			}, PendingOffer.Price)
			Core:GetService("TutorialService"):MarkObjectBought(Player)
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
	SpawnNextCustomer()
end

function Customerservice:Start()
	if HighestQueueIndex <= 0 or not AttachmentsByIndex[0] then
		return
	end

	SpawnCustomerAt(1)

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
