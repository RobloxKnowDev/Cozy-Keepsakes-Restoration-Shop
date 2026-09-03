local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local Tutorialservice = {
	Name = "TutorialService",
	Priority = 4,
	Remotes = {
		GetState = "Function",
		Complete = "Event",
	},
}

local Store = DataStoreService:GetDataStore("Tutorial_v1")
local Completedbyplayer: { [Player]: boolean } = {}
local Loadedbyplayer: { [Player]: boolean } = {}

local function Loadplayer(Player: Player)
	Completedbyplayer[Player] = false
	if not RunService:IsStudio() then
		local Success, Saved = pcall(function()
			return Store:GetAsync(tostring(Player.UserId))
		end)
		if Success then
			Completedbyplayer[Player] = Saved == true
		else
			warn("TutorialService: lecture impossible pour " .. Player.Name .. " : " .. tostring(Saved))
		end
	end
	Loadedbyplayer[Player] = true
end

local function Saveplayer(Player: Player)
	if not Loadedbyplayer[Player] or RunService:IsStudio() then
		return
	end
	local Success, Error = pcall(function()
		Store:SetAsync(tostring(Player.UserId), Completedbyplayer[Player] == true)
	end)
	if not Success then
		warn("TutorialService: sauvegarde impossible pour " .. Player.Name .. " : " .. tostring(Error))
	end
end

function Tutorialservice:IsActive(Player: Player): boolean
	while Player.Parent and not Loadedbyplayer[Player] do
		task.wait()
	end
	return Completedbyplayer[Player] == false
end

function Tutorialservice:Init()
	Players.PlayerAdded:Connect(Loadplayer)
	Players.PlayerRemoving:Connect(function(Player)
		Saveplayer(Player)
		Completedbyplayer[Player] = nil
		Loadedbyplayer[Player] = nil
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(Loadplayer, Player)
	end

	Remotemanager:OnServerInvoke(self.Name, "GetState", function(Player)
		return { Completed = not self:IsActive(Player) }
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
