local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)

local Shopservice = {
	Name = "ShopService",
	Priority = 1,
}

local Emptysign = "N/A"
local Cameramarkers = { "CamPart", "CamPartComputer", "CamPartExposition" }

local Shopsfolder: Folder
local Signsfolder: Model
local Owners: { [Model]: Player } = {}
local Shopbyplayer: { [Player]: Model } = {}

local function Setsign(Shop: Model, Text: string)
	local Surfacegui = Signsfolder:WaitForChild(Shop.Name .. "Text"):WaitForChild("SurfaceGui")
	for _, Label in ipairs(Surfacegui:GetChildren()) do
		if Label:IsA("TextLabel") then
			Label.Text = Text
		end
	end
end

local function Preparecamera(Shop: Model)
	local Camera = Shop:WaitForChild("Camera")
	for _, Name in ipairs(Cameramarkers) do
		local Marker = Camera:WaitForChild(Name) :: BasePart
		Marker.Anchored = true
		Marker.CanCollide = false
		Marker.CanQuery = false
		Marker.CanTouch = false
		Marker.Transparency = 1
	end
end

local function Claim(Player: Player, Shop: Model)
	Owners[Shop] = Player
	Shopbyplayer[Player] = Shop
	Player:SetAttribute("Shop", Shop.Name)
	Player.ReplicationFocus = Shop:WaitForChild("Camera"):WaitForChild("CamPart") :: BasePart
	Setsign(Shop, Player.DisplayName .. "'s Shop")
end

local function Assign(Player: Player): Model
	local Shop = Shopbyplayer[Player]
	if Shop then
		return Shop
	end
	if not Player.Parent then
		error("ShopService: " .. Player.Name .. " has already left")
	end
	for Index = 1, #Shopsfolder:GetChildren() do
		local Candidate = Shopsfolder:WaitForChild("Shop" .. Index) :: Model
		if not Owners[Candidate] then
			Claim(Player, Candidate)
			return Candidate
		end
	end
	error("ShopService: no free shop for " .. Player.Name)
end

local function Release(Player: Player)
	local Shop = Shopbyplayer[Player]
	if not Shop then
		return
	end
	Owners[Shop] = nil
	Shopbyplayer[Player] = nil
	Setsign(Shop, Emptysign)
end

function Shopservice:GetShop(Player: Player): Model
	return Assign(Player)
end

function Shopservice:GetOwner(Shop: Model): Player?
	return Owners[Shop]
end

function Shopservice:GetShops(): { Model }
	return Shopsfolder:GetChildren() :: { Model }
end

function Shopservice:MoveToNextShop(Player: Player): (Model?, string?)
	if not Core:GetService("DataService"):IsLoaded(Player) then
		return nil, "Data still loading"
	end
	if Core:GetService("TutorialService"):IsRunning(Player) then
		return nil, "Tutorial in progress"
	end
	if Core:GetService("RestorationService"):IsRestoring(Player) then
		return nil, "Restoration in progress"
	end
	if Core:GetService("ExpositionService"):IsBusy(Player) then
		return nil, "Try again in a moment"
	end
	local Previous = Assign(Player)
	local Count = #Shopsfolder:GetChildren()
	local Start = tonumber(string.match(Previous.Name, "%d+")) :: number
	for Step = 1, Count - 1 do
		local Candidate = Shopsfolder:WaitForChild("Shop" .. (Start + Step - 1) % Count + 1) :: Model
		if not Owners[Candidate] then
			Owners[Previous] = nil
			Setsign(Previous, Emptysign)
			Claim(Player, Candidate)
			Core:GetService("ExpositionService"):MoveShop(Player, Previous)
			Core:GetService("CustomerService"):MoveShop(Player)
			return Candidate, nil
		end
	end
	return nil, "No free shop"
end

function Shopservice:Init()
	local Map = Workspace:WaitForChild("Map")
	Shopsfolder = Map:WaitForChild("Shops") :: Folder
	Signsfolder = Map:WaitForChild("ShopSigns") :: Model
	for _, Shop in ipairs(Shopsfolder:GetChildren()) do
		Setsign(Shop :: Model, Emptysign)
		Preparecamera(Shop :: Model)
	end
	for _, Player in ipairs(Players:GetPlayers()) do
		Assign(Player)
	end
	Players.PlayerAdded:Connect(Assign)
	Players.PlayerRemoving:Connect(function(Player)
		task.defer(Release, Player)
	end)
end

return Shopservice
