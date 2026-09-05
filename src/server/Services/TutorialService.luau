local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Objectconfig = require(ReplicatedStorage.Shared.Config.Object)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local Tutorialservice = {
	Name = "TutorialService",
	Priority = 4,
	Remotes = {
		GetState = "Function",
		SetStep = "Event",
		Complete = "Event",
	},
}

local Store = DataStoreService:GetDataStore("Tutorial_v1")
local Completedbyplayer: { [Player]: boolean } = {}
local Loadedbyplayer: { [Player]: boolean } = {}
local Objectdonebyplayer: { [Player]: boolean } = {}
local Stepbyplayer: { [Player]: number } = {}
local Boughtbyplayer: { [Player]: boolean } = {}

local function Loadplayer(Player: Player)
	Completedbyplayer[Player] = false
	Stepbyplayer[Player] = 1
	Boughtbyplayer[Player] = false
	local Success, Saved = pcall(function()
		return Store:GetAsync(tostring(Player.UserId))
	end)
	if Success then
		if type(Saved) == "table" then
			Completedbyplayer[Player] = Saved.Completed == true
			Stepbyplayer[Player] = math.max(math.floor(tonumber(Saved.Step) or 1), 1)
			Boughtbyplayer[Player] = Saved.Bought == true
		else
			Completedbyplayer[Player] = Saved == true
		end
	else
		warn("TutorialService: could not read data for " .. Player.Name .. ": " .. tostring(Saved))
	end
	Loadedbyplayer[Player] = true
	if Completedbyplayer[Player] == false and Boughtbyplayer[Player] and Player.Parent then
		task.spawn(function()
			Core:GetService("RestorationService"):GrantObject(Player, Objectconfig.Offer.TutorialObject)
		end)
	end
end

function Tutorialservice:Wipe(Player: Player)
	Completedbyplayer[Player] = false
	Objectdonebyplayer[Player] = nil
	Stepbyplayer[Player] = 1
	Boughtbyplayer[Player] = false
	local Success, Error = pcall(function()
		Store:RemoveAsync(tostring(Player.UserId))
	end)
	if not Success then
		warn("TutorialService: could not erase data for " .. Player.Name .. ": " .. tostring(Error))
	end
end

local function Saveplayer(Player: Player)
	if not Loadedbyplayer[Player] then
		return
	end
	local Success, Error = pcall(function()
		Store:SetAsync(tostring(Player.UserId), {
			Completed = Completedbyplayer[Player] == true,
			Step = Stepbyplayer[Player] or 1,
			Bought = Boughtbyplayer[Player] == true,
		})
	end)
	if not Success then
		warn("TutorialService: could not save data for " .. Player.Name .. ": " .. tostring(Error))
	end
end

function Tutorialservice:IsActive(Player: Player): boolean
	while Player.Parent and not Loadedbyplayer[Player] do
		task.wait()
	end
	return Completedbyplayer[Player] == false
end

function Tutorialservice:MarkObjectBought(Player: Player)
	if Completedbyplayer[Player] == true then
		return
	end
	Boughtbyplayer[Player] = true
end

function Tutorialservice:MarkObjectDone(Player: Player)
	Objectdonebyplayer[Player] = true
	Boughtbyplayer[Player] = false
end

function Tutorialservice:CanTakeNewObject(Player: Player): boolean
	if not self:IsActive(Player) then
		return true
	end
	return Objectdonebyplayer[Player] ~= true and Boughtbyplayer[Player] ~= true
end

function Tutorialservice:Init()
	Players.PlayerAdded:Connect(Loadplayer)
	Players.PlayerRemoving:Connect(function(Player)
		Saveplayer(Player)
		Completedbyplayer[Player] = nil
		Loadedbyplayer[Player] = nil
		Objectdonebyplayer[Player] = nil
		Stepbyplayer[Player] = nil
		Boughtbyplayer[Player] = nil
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(Loadplayer, Player)
	end

	Remotemanager:OnServerInvoke(self.Name, "GetState", function(Player)
		return { Completed = not self:IsActive(Player), Step = Stepbyplayer[Player] or 1 }
	end)

	Remotemanager:OnServerEvent(self.Name, "SetStep", function(Player, Step)
		if Completedbyplayer[Player] == true then
			return
		end
		Stepbyplayer[Player] = math.max(math.floor(tonumber(Step) or 1), 1)
	end)

	Remotemanager:OnServerEvent(self.Name, "Complete", function(Player)
		if Completedbyplayer[Player] == true then
			return
		end
		Completedbyplayer[Player] = true
		Saveplayer(Player)
	end)
end

function Tutorialservice:Start()
	game:BindToClose(function()
		for _, Player in ipairs(Players:GetPlayers()) do
			Saveplayer(Player)
		end
	end)
end

return Tutorialservice
