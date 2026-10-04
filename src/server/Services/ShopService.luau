local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shopservice = {
	Name = "ShopService",
	Priority = 1,
}

local Emptysign = "N/A"

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
			Owners[Candidate] = Player
			Shopbyplayer[Player] = Candidate
			Player:SetAttribute("Shop", Candidate.Name)
			Player.ReplicationFocus = Candidate:WaitForChild("Camera"):WaitForChild("CamPart") :: BasePart
			Setsign(Candidate, Player.DisplayName .. "'s Shop")
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

function Shopservice:Init()
	local Map = Workspace:WaitForChild("Map")
	Shopsfolder = Map:WaitForChild("Shops") :: Folder
	Signsfolder = Map:WaitForChild("ShopSigns") :: Model
	for _, Shop in ipairs(Shopsfolder:GetChildren()) do
		Setsign(Shop :: Model, Emptysign)
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
