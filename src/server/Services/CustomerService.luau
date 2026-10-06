local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pathfindingservice = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Customerconfig = require(ReplicatedStorage.Shared.Config.Customer)
local Daynightconfig = require(ReplicatedStorage.Shared.Config.DayNight)
local Objectconfig = require(ReplicatedStorage.Shared.Config.Object)
local Rarityconfig = require(ReplicatedStorage.Shared.Config.Rarity)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Streetroute = require(ReplicatedStorage.Shared.Utils.StreetRoute)

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

local MaxFriendProfiles = 60
local Wardrobesize = 12
local FallbackCustomerTemplate = "1"
local Customerspershop = 3
local Walkspeed = NumberRange.new(5.5, 8)
local Spawngap = NumberRange.new(1.5, 4)
local Streethalfwidth = 15
local Lanecross = 2.5
local Stepdistance = NumberRange.new(5, 11)
local Lateraldrift = NumberRange.new(-2, 2)
local Swervechance = 0.15
local Swervedrift = NumberRange.new(-3.5, 3.5)
local Glancechance = 0.025
local Glancewait = NumberRange.new(0.5, 1.2)
local Maxstops = 2
local Detourchance = 0.12
local Detourwait = NumberRange.new(3, 7)
local Windowchance = 0.12
local Windowwait = NumberRange.new(1.5, 4)
local Windowlead = 3
local Windowspread = NumberRange.new(-2, 2)
local Windowinset = NumberRange.new(0.3, 1.2)
local Approachdistance = NumberRange.new(6, 12)
local Approachlateral = NumberRange.new(0.45, 0.75)
local Hesitatechance = 0.4
local Hesitatewait = NumberRange.new(0.8, 2)
local Lookbackchance = 0.5
local Lookbackwait = NumberRange.new(0.5, 1)
local Overshootchance = 0.15
local Overshootdistance = NumberRange.new(4, 7)
local Overshootwait = NumberRange.new(0.4, 0.9)
local Leavepause = 0.6
local Instantspawndistance = 24
local Exitdistance = 10
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
type ShopStop = {
	Shop: Instance,
	Along: number,
	Side: number,
	Path: { Vector3 },
	Door: number,
	Facing: Vector3,
}
type Trip = {
	Points: { Vector3 },
	Holds: { number },
	Looks: { [number]: Vector3 },
}
type PlannedVisit = {
	Trip: Trip,
	Speed: number,
	Arrival: number,
}
type ShopState = {
	Player: Player,
	Shop: Model,
	Visitor: Folder?,
	FrontCustomer: Folder?,
	PendingOffer: CustomerOffer?,
	Plannedvisit: PlannedVisit?,
	Arrivaltask: thread?,
	NextCustomerAt: number,
	ArrivedToday: number,
	NeedsInstantCustomer: boolean,
	Directcustomer: boolean,
}
type Passerby = {
	Direction: number,
	Band: NumberRange,
	To: number,
	Detours: { [Instance]: number },
	Despawn: thread,
}

local Shopsfolder: Folder
local Streetfolder: Folder
local Streetstart = Vector3.zero
local Streetfinish = Vector3.zero
local Streetlength = 0
local Streetside = Vector3.zero
local Forwardband = NumberRange.new(-Lanecross, Streethalfwidth)
local Backwardband = NumberRange.new(-Streethalfwidth, Lanecross)
local Fullband = NumberRange.new(-Streethalfwidth, Streethalfwidth)
local Shopstops: { [string]: ShopStop } = {}
local States: { [Player]: ShopState } = {}
local Pendingskips: { [Player]: number } = {}
local Offerbags: { [Player]: { [string]: { string } } } = {}
local Commonstreaks: { [Player]: number } = {}
local Passerbys: { [Folder]: Passerby } = {}
local Passersby = 0
local CustomerSerial = 0
local OfferSerial = 0
local Customertemplate: Model
local Wardrobeworkshop: Folder
local ObjectsByRarity: { [string]: { string } } = {}
local CurrentDay = 1
local Stopsready = false

local function Setpendingskips(Player: Player, Count: number)
	Pendingskips[Player] = Count
	Player:SetAttribute("PendingSkips", Count)
end

local function GetMaxCustomersPerDay(Player: Player): number
	return math.max(math.floor(Core:GetService("UpgradeService"):GetValue(Player, "DailyCustomers")), 0)
end

local function ReplicateCustomerCount(State: ShopState)
	State.Player:SetAttribute("CustomersToday", State.ArrivedToday)
	State.Player:SetAttribute("MaxCustomersPerDay", GetMaxCustomersPerDay(State.Player))
end

local function SyncDayState()
	local Day = Lighting:GetAttribute("Day") or 1
	if Day ~= CurrentDay then
		CurrentDay = Day
		for _, State in pairs(States) do
			State.ArrivedToday = 0
			State.NeedsInstantCustomer = true
		end
	end
	for _, State in pairs(States) do
		ReplicateCustomerCount(State)
	end
end

local function CountArrivedCustomer(State: ShopState)
	State.ArrivedToday += 1
	ReplicateCustomerCount(State)
end

local function IsBusinessHours(): boolean
	local ClockTime = Lighting.ClockTime
	return ClockTime >= Daynightconfig.DayStartHour and ClockTime < Daynightconfig.NightStartHour
end

local function CanSpawnMoreCustomersToday(State: ShopState): boolean
	SyncDayState()
	return State.ArrivedToday < GetMaxCustomersPerDay(State.Player)
end

local function CollectOfferObjects()
	for _, Rarity in ipairs(Rarityconfig.Order) do
		ObjectsByRarity[Rarity] = {}
	end

	for ObjectKey, Definition in pairs(Objectconfig.Object) do
		table.insert(ObjectsByRarity[Definition.Rarity], ObjectKey)
	end

	for _, Rarity in ipairs(Rarityconfig.Order) do
		table.sort(ObjectsByRarity[Rarity])
	end
end

local function Randomin(Range: NumberRange): number
	return Range.Min + math.random() * (Range.Max - Range.Min)
end

local function Floorpoint(Position: Vector3): Vector3
	local Result = Workspace:Raycast(Position + Vector3.new(0, 2, 0), Vector3.new(0, -50, 0))
	return if Result then Result.Position else Position
end

local function Streetposition(Along: number, Lateral: number): Vector3
	return Streetstart:Lerp(Streetfinish, Along / Streetlength) + Streetside * Lateral
end

local function Alongof(Position: Vector3): number
	return math.clamp((Position - Streetstart):Dot(Streetfinish - Streetstart) / Streetlength, 0, Streetlength)
end

local function Lateralof(Position: Vector3): number
	return (Position - Streetposition(Alongof(Position), 0)):Dot(Streetside)
end

local function Newtrip(): Trip
	return { Points = {}, Holds = {}, Looks = {} }
end

local function Go(Trip: Trip, Point: Vector3, Hold: number, Look: Vector3?)
	table.insert(Trip.Points, Point)
	table.insert(Trip.Holds, Hold)
	Trip.Looks[#Trip.Points] = Look
end

local function Walkto(Trip: Trip, From: number, To: number, Direction: number, Lateral: number, Band: NumberRange, Goal: number?): number
	local Along = From
	local Limit = if Goal then Fullband else Band
	while (To - Along) * Direction > Stepdistance.Max do
		local Step = Randomin(Stepdistance)
		Along += Direction * Step
		if Goal then
			Lateral += (Goal - Lateral) * Step / ((To - Along) * Direction + Step)
		end
		local Drift = if math.random() < Swervechance then Swervedrift else Lateraldrift
		Lateral = math.clamp(Lateral + Randomin(Drift), Limit.Min, Limit.Max)
		local Point = Streetposition(Along, Lateral)
		if math.random() < Glancechance then
			local Side = if math.random(2) == 1 then 1 else -1
			Go(Trip, Point, Randomin(Glancewait), Streetposition(Along + Direction * 3, Side * (Streethalfwidth + 6)))
		else
			Go(Trip, Point, 0)
		end
	end
	return Lateral
end

local function Finishroute(Trip: Trip, To: number, Direction: number, Lateral: number)
	Go(Trip, Streetposition(To, Lateral), 0)
	Go(Trip, Streetposition(To + Direction * Exitdistance, Lateral), 0)
end

local function Buildshopstop(Shop: Instance): ShopStop
	local Counter = Floorpoint((Shop:WaitForChild("Attachement"):WaitForChild("Customer") :: Attachment).WorldPosition)
	local Along = Alongof(Counter)
	local Street = Streetposition(Along, 0)
	local Side = math.sign(Lateralof(Counter))
	local Path = Pathfindingservice:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = false })
	local Computed = pcall(function()
		Path:ComputeAsync(Street, Counter)
	end)
	local Points = { Counter }
	if Computed and Path.Status == Enum.PathStatus.Success then
		Points = {}
		for Index, Waypoint in ipairs(Path:GetWaypoints()) do
			if Index > 1 then
				table.insert(Points, Waypoint.Position)
			end
		end
	else
		warn("CustomerService: no walking path into " .. Shop.Name .. ", customers walk straight to the counter")
	end
	local Door = #Points
	for Index, Point in ipairs(Points) do
		if Lateralof(Point) * Side >= Streethalfwidth * Approachlateral.Max then
			Door = Index
			break
		end
	end
	local Camera = (Shop:WaitForChild("Camera"):WaitForChild("CamPart") :: BasePart).Position
	return {
		Shop = Shop,
		Along = Along,
		Side = Side,
		Path = Points,
		Door = Door,
		Facing = Vector3.new(Camera.X, Counter.Y, Camera.Z),
	}
end

local function Stopsalong(Direction: number): { ShopStop }
	local Stops = {}
	for _, Stop in pairs(Shopstops) do
		table.insert(Stops, Stop)
	end
	table.sort(Stops, function(Left, Right)
		return Left.Along * Direction < Right.Along * Direction
	end)
	return Stops
end

local function Windowstop(Trip: Trip, Stop: ShopStop, Direction: number): (number, number)
	local Along = math.clamp(Stop.Along + Randomin(Windowspread), 0, Streetlength)
	local Lateral = Stop.Side * (Streethalfwidth - Randomin(Windowinset))
	local Point = Streetposition(Along, Lateral)
	Go(Trip, Point, Randomin(Windowwait), Stop.Facing)
	if math.random() < Lookbackchance then
		Go(Trip, Point - Streetside * (Stop.Side * 0.3), Randomin(Lookbackwait), Streetposition(Along + Direction * 12, Lateral))
	end
	return Along, Lateral
end

local function Entershop(Trip: Trip, Stop: ShopStop, From: number, Direction: number, Hesitate: boolean, Overshoot: boolean)
	local Approach = math.min(Randomin(Approachdistance), math.abs(Stop.Along - From) * 0.6)
	Go(Trip, Streetposition(Stop.Along - Direction * Approach, Stop.Side * Streethalfwidth * Randomin(Approachlateral)), 0)
	if Overshoot then
		local Past = math.clamp(Stop.Along + Direction * Randomin(Overshootdistance), 0, Streetlength)
		Go(Trip, Streetposition(Past, Stop.Side * Streethalfwidth * Randomin(Approachlateral)), Randomin(Overshootwait), Stop.Facing)
	end
	if Hesitate then
		local Front = Streetposition(Stop.Along + Randomin(Windowspread) * 0.5, Stop.Side * Streethalfwidth * Randomin(Approachlateral))
		Go(Trip, Front, Randomin(Hesitatewait), Stop.Facing)
		if math.random() < Lookbackchance then
			Go(Trip, Front - Streetside * (Stop.Side * 0.3), Randomin(Lookbackwait), Streetposition(Stop.Along - Direction * 12, 0))
		end
	end
	for Index = Stop.Door, #Stop.Path do
		Go(Trip, Stop.Path[Index], 0)
	end
end

local function Leaveshop(Trip: Trip, Stop: ShopStop, Direction: number): (number, number)
	for Index = #Stop.Path - 1, Stop.Door, -1 do
		Go(Trip, Stop.Path[Index], 0)
	end
	local Along = math.clamp(Stop.Along + Direction * Randomin(Approachdistance), 0, Streetlength)
	local Lateral = Stop.Side * Streethalfwidth * Randomin(Approachlateral)
	Go(Trip, Streetposition(Along, Lateral), 0)
	return Along, Lateral
end

local function Createcustomer(Speed: number): Folder
	CustomerSerial += 1
	local Customer = Instance.new("Folder")
	Customer.Name = string.format("Customer_%d", CustomerSerial)
	Customer:SetAttribute("Speed", Speed)
	return Customer
end

local function Route(Customer: Folder, Trip: Trip, Start: number)
	Customer:SetAttribute("Route", Streetroute.Encode(Trip.Points, Trip.Holds, Trip.Looks))
	Customer:SetAttribute("RouteStart", Start)
end

local function Despawnatend(Customer: Folder, Trip: Trip, Start: number, Speed: number, Onremoved: (() -> ())?): thread
	local Delay = Start + Streetroute.TimeTo(Trip.Points, Trip.Holds, Speed, #Trip.Points - 1) - Workspace:GetServerTimeNow()
	return task.delay(Delay, function()
		if Onremoved then
			Onremoved()
		end
		Customer:Destroy()
	end)
end

local function Forgetpasserby(Customer: Folder)
	Passersby -= 1
	Passerbys[Customer] = nil
end

local function Spawnpasserby()
	local Forward = math.random(2) == 1
	local Direction = if Forward then 1 else -1
	local Band = if Forward then Forwardband else Backwardband
	local From = if Forward then 0 else Streetlength
	local To = Streetlength - From
	local Lateral = Randomin(Band)
	local Trip = Newtrip()
	Go(Trip, Streetposition(From, Lateral), 0)
	local Shopservice = Core:GetService("ShopService")
	local Detours: { [Instance]: number } = {}
	local Stops = 0
	for _, Stop in ipairs(Stopsalong(Direction)) do
		if Stops < Maxstops and (Stop.Along - From) * Direction > Windowlead then
			local Roll = math.random()
			if Roll < Detourchance and not Shopservice:GetOwner(Stop.Shop) then
				Lateral = Walkto(Trip, From, Stop.Along - Direction * Approachdistance.Max, Direction, Lateral, Band, Stop.Side * Streethalfwidth * Approachlateral.Min)
				Detours[Stop.Shop] = #Trip.Points + 1
				Entershop(Trip, Stop, From, Direction, math.random() < Hesitatechance, false)
				Trip.Holds[#Trip.Points] = Randomin(Detourwait)
				Trip.Looks[#Trip.Points] = Stop.Facing
				From, Lateral = Leaveshop(Trip, Stop, Direction)
				Stops += 1
			elseif Roll < Detourchance + Windowchance then
				Lateral = Walkto(Trip, From, Stop.Along - Direction * Windowlead, Direction, Lateral, Band, Stop.Side * (Streethalfwidth - Windowinset.Max))
				From, Lateral = Windowstop(Trip, Stop, Direction)
				Stops += 1
			end
		end
	end
	Lateral = Walkto(Trip, From, To, Direction, Lateral, Band, if Stops > 0 then Randomin(Band) else nil)
	Finishroute(Trip, To, Direction, Lateral)
	local Speed = Randomin(Walkspeed)
	local Start = Workspace:GetServerTimeNow()
	local Customer = Createcustomer(Speed)
	Route(Customer, Trip, Start)
	Customer.Parent = Streetfolder
	Passersby += 1
	for Shop, Index in pairs(Detours) do
		Detours[Shop] = Start + Streetroute.TimeTo(Trip.Points, Trip.Holds, Speed, Index)
	end
	Passerbys[Customer] = {
		Direction = Direction,
		Band = Band,
		To = To,
		Detours = Detours,
		Despawn = Despawnatend(Customer, Trip, Start, Speed, function()
			Forgetpasserby(Customer)
		end),
	}
end

local function Skipdetours(Shop: Instance)
	local Now = Workspace:GetServerTimeNow()
	for Customer, Passerby in pairs(Passerbys) do
		local Enter = Passerby.Detours[Shop]
		if Enter and Enter > Now then
			local Speed = Customer:GetAttribute("Speed")
			local Points, Holds, Looks = Streetroute.Decode(Customer:GetAttribute("Route"))
			local Position = Streetroute.Sample(Points, Holds, Looks, Speed, Now - Customer:GetAttribute("RouteStart"))
			local Trip = Newtrip()
			Go(Trip, Position, 0)
			local Lateral = Walkto(
				Trip,
				Alongof(Position),
				Passerby.To,
				Passerby.Direction,
				Lateralof(Position),
				Passerby.Band,
				Randomin(Passerby.Band)
			)
			Finishroute(Trip, Passerby.To, Passerby.Direction, Lateral)
			Route(Customer, Trip, Now)
			task.cancel(Passerby.Despawn)
			Passerby.Detours = {}
			Passerby.Despawn = Despawnatend(Customer, Trip, Now, Speed, function()
				Forgetpasserby(Customer)
			end)
		end
	end
end

local function Runtraffic()
	while true do
		task.wait(Randomin(Spawngap))
		local Occupiedshops = 0
		for _ in pairs(States) do
			Occupiedshops += 1
		end
		if IsBusinessHours() and Passersby < Customerspershop * Occupiedshops then
			Spawnpasserby()
		end
	end
end

local function Planvisit(State: ShopState, Instant: boolean): PlannedVisit
	local Stop = Shopstops[State.Shop.Name]
	local Forward = math.random(2) == 1
	local Direction = if Forward then 1 else -1
	local Band = if Forward then Forwardband else Backwardband
	local From = if Forward then 0 else Streetlength
	if Instant then
		From = math.clamp(Stop.Along - Direction * Instantspawndistance, 0, Streetlength)
	end
	local Trip = Newtrip()
	local Lateral = Randomin(Band)
	Go(Trip, Streetposition(From, Lateral), 0)
	Walkto(Trip, From, Stop.Along - Direction * Approachdistance.Max, Direction, Lateral, Band, Stop.Side * Streethalfwidth * Approachlateral.Min)
	Entershop(Trip, Stop, From, Direction, math.random() < Hesitatechance, math.random() < Overshootchance)
	Trip.Looks[#Trip.Points] = Stop.Facing
	local Speed = Randomin(Walkspeed)
	return {
		Trip = Trip,
		Speed = Speed,
		Arrival = Streetroute.TimeTo(Trip.Points, Trip.Holds, Speed, #Trip.Points),
	}
end

local function Buildwardrobe(Player: Player)
	local Wardrobe = Instance.new("ScreenGui")
	Wardrobe.Name = "CustomerWardrobe"
	Wardrobe.ResetOnSpawn = false
	Wardrobe.Parent = Player:WaitForChild("PlayerGui")
	local Success, Pages = pcall(function()
		return Players:GetFriendsAsync(Player.UserId)
	end)
	if not Success then
		return
	end

	local Friends = {}
	while #Friends < MaxFriendProfiles do
		for _, Entry in ipairs(Pages:GetCurrentPage()) do
			table.insert(Friends, Entry.Id)
		end
		if Pages.IsFinished or not pcall(function() Pages:AdvanceToNextPageAsync() end) then
			break
		end
	end
	for Index = #Friends, 2, -1 do
		local Swap = math.random(Index)
		Friends[Index], Friends[Swap] = Friends[Swap], Friends[Index]
	end

	for Index = 1, math.min(#Friends, Wardrobesize) do
		local Described, Description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserIdAsync(Friends[Index])
		end)
		if not Player.Parent then
			return
		end
		if Described then
			local Customer = Customertemplate:Clone()
			for _, Child in ipairs(Customer:GetChildren()) do
				if Child:IsA("Clothing") or Child:IsA("ShirtGraphic") or Child:IsA("Accessory") or Child:IsA("LocalScript") then
					Child:Destroy()
				end
			end
			Customer.Parent = Wardrobeworkshop
			local Applied = pcall(function()
				(Customer:WaitForChild("Humanoid") :: Humanoid):ApplyDescriptionAsync(Description:Clone())
			end)
			if Applied then
				Customer.Parent = Wardrobe
			else
				Customer:Destroy()
			end
		end
	end
end

local function GetSpawnInterval(Player: Player): number
	return Customerconfig.GetInterval(Core:GetService("UpgradeService"):GetValue(Player, "CooldownReduction"))
end

local function SetNextCustomerAt(State: ShopState, Timestamp: number)
	State.NextCustomerAt = Timestamp
	State.Player:SetAttribute("NextCustomerAt", Timestamp)
end

local function ArmCustomerTimer(State: ShopState)
	local Interval = GetSpawnInterval(State.Player)
	State.Player:SetAttribute("CustomerInterval", Interval)
	State.Plannedvisit = Planvisit(State, false)
	SetNextCustomerAt(State, Workspace:GetServerTimeNow() + Interval)
end

local function GetOfferPayload(State: ShopState)
	local Offer = State.PendingOffer
	if not Offer then
		return nil
	end
	local Customer = State.FrontCustomer :: Folder
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

local function BroadcastOffer(State: ShopState)
	Remotemanager:FireClient(Customerservice.Name, "OfferUpdated", State.Player, GetOfferPayload(State))
end

local function GetOfferChances(Reputation: number)
	local Tiers = Rarityconfig.Tiers
	local Lower = Tiers[1]
	local Upper = Tiers[1]
	for _, Tier in ipairs(Tiers) do
		Upper = Tier
		if Tier.Reputation > Reputation then
			break
		end
		Lower = Tier
	end
	local Progress = if Upper == Lower then 0 else (Reputation - Lower.Reputation) / (Upper.Reputation - Lower.Reputation)
	local Chances = {}
	for _, Rarity in ipairs(Rarityconfig.Order) do
		Chances[Rarity] = Lower[Rarity] + (Upper[Rarity] - Lower[Rarity]) * Progress
	end
	return Chances
end

local function Shufflebag(Rarity: string, Lastobject: string?): { string }
	local Bag = table.clone(ObjectsByRarity[Rarity])
	for Index = #Bag, 2, -1 do
		local Swap = math.random(Index)
		Bag[Index], Bag[Swap] = Bag[Swap], Bag[Index]
	end
	if Bag[#Bag] == Lastobject then
		Bag[1], Bag[#Bag] = Bag[#Bag], Bag[1]
	end
	return Bag
end

local function Drawfrombag(Player: Player, Rarity: string): string
	local Bags = Offerbags[Player]
	local Bag = Bags[Rarity] or Shufflebag(Rarity, nil)
	local ObjectKey = table.remove(Bag) :: string
	Bags[Rarity] = if #Bag > 0 then Bag else Shufflebag(Rarity, ObjectKey)
	return ObjectKey
end

local function Takefrombag(Player: Player, ObjectKey: string)
	local Rarity = Objectconfig.Object[ObjectKey].Rarity
	local Bags = Offerbags[Player]
	local Bag = Bags[Rarity] or Shufflebag(Rarity, nil)
	local Index = table.find(Bag, ObjectKey)
	if Index then
		table.remove(Bag, Index)
	end
	Bags[Rarity] = if #Bag > 0 then Bag else Shufflebag(Rarity, ObjectKey)
end

local function Loadbags(Saved: { [string]: { string } }): { [string]: { string } }
	local Bags = {}
	for _, Rarity in ipairs(Rarityconfig.Order) do
		local Bag = {}
		for _, ObjectKey in ipairs(Saved[Rarity] or {}) do
			if table.find(ObjectsByRarity[Rarity], ObjectKey) and not table.find(Bag, ObjectKey) then
				table.insert(Bag, ObjectKey)
			end
		end
		if #Bag > 0 then
			Bags[Rarity] = Bag
		end
	end
	return Bags
end

local function ChooseObjectKey(Player: Player): string
	if Core:GetService("TutorialService"):IsActive(Player) then
		Takefrombag(Player, Objectconfig.Offer.TutorialObject)
		return Objectconfig.Offer.TutorialObject
	end
	local Reputation = Core:GetService("StatsService"):GetStats(Player).Reputation
	local Chances = GetOfferChances(Reputation)
	if Commonstreaks[Player] >= Rarityconfig.MaxCommonStreak then
		Chances.Common = 0
	end
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
				Commonstreaks[Player] = if Rarity == "Common" then Commonstreaks[Player] + 1 else 0
				return Drawfrombag(Player, Rarity)
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

local function ChooseEmergencyRequest(Player: Player): CustomerOffer
	local ObjectKey = Objectconfig.Offer.EmergencyObject
	Takefrombag(Player, ObjectKey)
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
		local Maxprice = math.max(
			tonumber(Definition.PriceMaxValue) or tonumber(Definition.MaxPrice) or tonumber(Definition.MaxValue) or 0,
			0
		)
		local Minprice = math.max(math.min(tonumber(Definition.PriceMinValue) or Maxprice, Maxprice), 0)
		local Affordableprice = Minprice + (Maxprice - Minprice) * Objectconfig.Offer.EmergencyPriceMargin
		Cheapestprice = math.min(Cheapestprice, Affordableprice)
	end
	local UpgradeDiscount = Core:GetService("UpgradeService"):GetValue(Player, "PurchaseDiscount")
	local VIPDiscount = Core:GetService("MonetizationService"):GetVIPCustomerDiscount(Player)
	local DiscountPercent = math.clamp(UpgradeDiscount + VIPDiscount, 0, 100)
	return math.max(math.round(Cheapestprice * (1 - DiscountPercent / 100)), 0)
end

function Customerservice:RefreshPendingOfferPrice(Player: Player)
	local State = States[Player]
	if not State or not State.PendingOffer then
		return
	end
	local Offer = State.PendingOffer :: CustomerOffer
	local UpgradeDiscount = Core:GetService("UpgradeService"):GetValue(Player, "PurchaseDiscount")
	local VIPDiscount = Core:GetService("MonetizationService"):GetVIPCustomerDiscount(Player)
	local DiscountPercent = math.clamp(UpgradeDiscount + VIPDiscount, 0, 100)
	Offer.Price = math.max(math.round(Offer.BasePrice * (1 - DiscountPercent / 100)), 0)
	BroadcastOffer(State)
end

local function ClearPendingOffer(State: ShopState)
	State.PendingOffer = nil
	BroadcastOffer(State)
end

local function CanPresentOffer(State: ShopState): boolean
	local Restorationservice = Core:GetService("RestorationService")
	return not State.PendingOffer
		and not Restorationservice:HasActiveSession(State.Player)
		and not Restorationservice:HasActiveObject(State.Player)
end

local function PresentFrontOffer(State: ShopState)
	if not CanPresentOffer(State) or not State.FrontCustomer then
		return
	end
	if not Core:GetService("TutorialService"):CanTakeNewObject(State.Player) or States[State.Player] ~= State then
		return
	end
	State.PendingOffer = ChooseCustomerRequest(State.Player)
	BroadcastOffer(State)
end

local function Arrive(State: ShopState, Customer: Folder)
	State.Arrivaltask = nil
	if State.Visitor ~= Customer then
		return
	end
	State.FrontCustomer = Customer
	SetNextCustomerAt(State, 0)
	PresentFrontOffer(State)
end

local function Schedulearrival(State: ShopState, Customer: Folder, Arrival: number)
	if State.Arrivaltask then
		task.cancel(State.Arrivaltask)
	end
	SetNextCustomerAt(State, Arrival)
	State.Arrivaltask = task.delay(Arrival - Workspace:GetServerTimeNow(), Arrive, State, Customer)
end

local function Dispatchvisitor(State: ShopState, Visit: PlannedVisit, Arrival: number)
	local Customer = Createcustomer(Visit.Speed)
	Route(Customer, Visit.Trip, Arrival - Visit.Arrival)
	Customer.Parent = Streetfolder
	State.Visitor = Customer
	CountArrivedCustomer(State)
	Schedulearrival(State, Customer, Arrival)
end

local function Skipwait(State: ShopState): boolean
	local Arrival = Workspace:GetServerTimeNow() + Customerconfig.SkipArrivalSeconds
	if State.FrontCustomer or State.NextCustomerAt <= Arrival + Customerconfig.SkipMarginSeconds then
		return false
	end
	local Visitor = State.Visitor
	if Visitor then
		Visitor:SetAttribute("RouteStart", Visitor:GetAttribute("RouteStart") - (State.NextCustomerAt - Arrival))
		Schedulearrival(State, Visitor, Arrival)
	else
		Dispatchvisitor(State, State.Plannedvisit :: PlannedVisit, Arrival)
	end
	return true
end

local function Walkaway(State: ShopState)
	local Customer = State.FrontCustomer :: Folder
	State.FrontCustomer = nil
	State.Visitor = nil
	local Stop = Shopstops[State.Shop.Name]
	local Forward = math.random(2) == 1
	local Direction = if Forward then 1 else -1
	local Band = if Forward then Forwardband else Backwardband
	local To = if Forward then Streetlength else 0
	local Trip = Newtrip()
	Go(Trip, Stop.Path[#Stop.Path], Leavepause, Stop.Facing)
	local From, Lateral = Leaveshop(Trip, Stop, Direction)
	Lateral = Walkto(Trip, From, To, Direction, Lateral, Band, Randomin(Band))
	Finishroute(Trip, To, Direction, Lateral)
	local Start = Workspace:GetServerTimeNow()
	Route(Customer, Trip, Start)
	Despawnatend(Customer, Trip, Start, Customer:GetAttribute("Speed"))
end

local function UpdateCustomerTimer(State: ShopState)
	if State.Visitor then
		return
	end
	if State.Directcustomer then
		local Visit = Planvisit(State, true)
		State.Directcustomer = false
		State.NeedsInstantCustomer = false
		Dispatchvisitor(State, Visit, Workspace:GetServerTimeNow())
		return
	end
	if not IsBusinessHours() or not CanSpawnMoreCustomersToday(State) then
		SetNextCustomerAt(State, 0)
		return
	end
	if State.NeedsInstantCustomer then
		State.NeedsInstantCustomer = false
		local Visit = Planvisit(State, true)
		Dispatchvisitor(State, Visit, Workspace:GetServerTimeNow() + Visit.Arrival)
		return
	end
	if State.NextCustomerAt <= 0 then
		ArmCustomerTimer(State)
		if Pendingskips[State.Player] > 0 and Skipwait(State) then
			Setpendingskips(State.Player, Pendingskips[State.Player] - 1)
		end
		return
	end
	local Interval = GetSpawnInterval(State.Player)
	State.Player:SetAttribute("CustomerInterval", Interval)
	local Now = Workspace:GetServerTimeNow()
	if State.NextCustomerAt > Now + Interval then
		SetNextCustomerAt(State, Now + Interval)
	end
	local Visit = State.Plannedvisit :: PlannedVisit
	if Now < State.NextCustomerAt - Visit.Arrival then
		return
	end
	Dispatchvisitor(State, Visit, State.NextCustomerAt)
end

local function OpenShop(Player: Player)
	Skipdetours(Core:GetService("ShopService"):GetShop(Player))
	Core:GetService("DataService"):WaitForLoad(Player)
	local Intutorial = Core:GetService("TutorialService"):IsActive(Player)
	if not Player.Parent then
		return
	end
	local State: ShopState = {
		Player = Player,
		Shop = Core:GetService("ShopService"):GetShop(Player),
		NextCustomerAt = 0,
		ArrivedToday = 0,
		NeedsInstantCustomer = true,
		Directcustomer = Intutorial,
	}
	Commonstreaks[Player] = Commonstreaks[Player] or 0
	Offerbags[Player] = Offerbags[Player] or {}
	States[Player] = State
	Setpendingskips(Player, Pendingskips[Player] or 0)
	ReplicateCustomerCount(State)
	if Stopsready then
		UpdateCustomerTimer(State)
	end
end

local function Closeshop(Player: Player)
	local State = States[Player]
	if not State then
		return
	end
	States[Player] = nil
	State.PendingOffer = nil
	if State.FrontCustomer then
		Walkaway(State)
	elseif State.Visitor then
		State.Visitor:Destroy()
		State.Visitor = nil
	end
end

function Customerservice:Init()
	local Map = Workspace:WaitForChild("Map")
	local Spawns = Map:WaitForChild("SpawnCustomers")
	Streetstart = Floorpoint((Spawns:WaitForChild("1") :: Attachment).WorldPosition)
	Streetfinish = Floorpoint((Spawns:WaitForChild("2") :: Attachment).WorldPosition)
	local Axis = Streetfinish - Streetstart
	Streetlength = Axis.Magnitude
	Streetside = Vector3.new(Axis.X, 0, Axis.Z).Unit:Cross(Vector3.yAxis)
	Shopsfolder = Map:WaitForChild("Shops") :: Folder
	Streetfolder = Instance.new("Folder")
	Streetfolder.Name = "StreetCustomers"
	Streetfolder.Parent = ReplicatedStorage
	CollectOfferObjects()
	Customertemplate = ReplicatedStorage:WaitForChild("Asset"):WaitForChild("Customer"):WaitForChild(FallbackCustomerTemplate) :: Model
	Wardrobeworkshop = Instance.new("Folder")
	Wardrobeworkshop.Name = "CustomerWardrobeWorkshop"
	Wardrobeworkshop.Parent = ServerStorage
	SyncDayState()
	Lighting:GetAttributeChangedSignal("Day"):Connect(SyncDayState)
	Core:GetService("DataService"):Register("Customer", {
		Load = function(Player, Saved)
			local Count = tonumber(Saved.PendingSkips) or 0
			Pendingskips[Player] = if Count == Count and math.abs(Count) ~= math.huge then math.max(math.floor(Count), 0) else 0
			Commonstreaks[Player] = math.max(math.floor(tonumber(Saved.CommonStreak) or 0), 0)
			Offerbags[Player] = Loadbags(Saved.OfferBags or {})
		end,
		Save = function(Player)
			return {
				PendingSkips = Pendingskips[Player] or 0,
				CommonStreak = Commonstreaks[Player] or 0,
				OfferBags = Offerbags[Player] or {},
			}
		end,
		Clear = function(Player)
			Closeshop(Player)
			Pendingskips[Player] = nil
			Commonstreaks[Player] = nil
			Offerbags[Player] = nil
		end,
	})
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(OpenShop, Player)
		task.spawn(Buildwardrobe, Player)
	end
	Players.PlayerAdded:Connect(function(Player)
		task.spawn(OpenShop, Player)
		task.spawn(Buildwardrobe, Player)
	end)

	Remotemanager:OnServerInvoke(self.Name, "RequestPriceEstimate", function(Player, OfferId)
		local State = States[Player]
		local Offer = if State then State.PendingOffer else nil
		if not Offer or Offer.Id ~= tonumber(OfferId) then
			return { Success = false, Reason = "OfferUnavailable" }
		end
		if not Core:GetService("UpgradeService"):ConsumePriceEstimate(Player) then
			return { Success = false, Reason = "NoEstimatesRemaining" }
		end
		return {
			Success = true,
			MaxPrice = Offer.MaxValue,
			Mutation = Offer.Mutation,
		}
	end)

	Remotemanager:OnServerInvoke(self.Name, "GetPendingOffer", function(Player)
		local State = States[Player]
		return if State then GetOfferPayload(State) else nil
	end)

	Remotemanager:OnServerInvoke(self.Name, "RespondToOffer", function(Player, OfferId, Decision)
		local State = States[Player]
		local Offer = if State then State.PendingOffer else nil
		if not State or not Offer or Offer.Id ~= OfferId or not State.FrontCustomer then
			return {
				Success = false,
				Reason = "OfferUnavailable",
			}
		end

		local NormalizedDecision = string.lower(tostring(Decision))
		if NormalizedDecision == "accept" then
			local Cashservice = Core:GetService("CashService")
			if not Cashservice:SpendCash(Player, Offer.Price) then
				if Cashservice:CanSpendCash(Player, GetAffordableOfferThreshold(Player)) then
					return {
						Success = false,
						Reason = "NotEnoughCash",
					}
				end
				State.PendingOffer = ChooseEmergencyRequest(Player)
				BroadcastOffer(State)
				return {
					Success = false,
					Reason = "EmergencyOfferPresented",
				}
			end
			Core:GetService("InventoryService"):AddPurchasedItem(Player, Offer.ObjectKey, {
				MaxValue = Offer.MaxValue,
				MaxReputation = Offer.MaxReputation,
				Mutation = Offer.Mutation,
			}, Offer.Price)
			Core:GetService("TutorialService"):MarkObjectBought(Player)
			if not Offer.Emergency then
				Core:GetService("DailyTaskService"):Record(Player, "Buy", {
					ObjectKey = Offer.ObjectKey,
					Rarity = Objectconfig.Object[Offer.ObjectKey].Rarity,
					Value = Offer.Price,
				})
			end
			ClearPendingOffer(State)
			Walkaway(State)
			return {
				Success = true,
			}
		end

		if NormalizedDecision == "decline" then
			ClearPendingOffer(State)
			Walkaway(State)
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

function Customerservice:PresentOffer(Player: Player)
	local State = States[Player]
	if State then
		PresentFrontOffer(State)
	end
end

function Customerservice:RefreshCustomerLimit()
	for _, State in pairs(States) do
		ReplicateCustomerCount(State)
	end
end

function Customerservice:SkipCooldown(Player: Player): boolean
	local State = States[Player]
	if not State or not Skipwait(State) then
		Setpendingskips(Player, (Pendingskips[Player] or 0) + 1)
	end
	return true
end

function Customerservice:Start()
	task.spawn(function()
		for _, Shop in ipairs(Shopsfolder:GetChildren()) do
			Shopstops[Shop.Name] = Buildshopstop(Shop)
		end
		Stopsready = true
		task.spawn(Runtraffic)
		while true do
			for _, State in pairs(table.clone(States)) do
				UpdateCustomerTimer(State)
			end
			task.wait(1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(5)
			SyncDayState()
			if IsBusinessHours() then
				for _, State in pairs(table.clone(States)) do
					PresentFrontOffer(State)
				end
			end
		end
	end)
end

return Customerservice
