local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Remotemanager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Datastorerequest = require(script.Parent.Parent.Utils.Datastorerequest)

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
local Isstudio = RunService:IsStudio()
local Loadattempts = 5
local Saveattempts = 3
local Maximumstep = 1000
local Shutdowndeadline = 25
local Completedbyplayer: { [Player]: boolean } = {}
local Loadedbyplayer: { [Player]: boolean } = {}
local Objectdonebyplayer: { [Player]: boolean } = {}
local Stepbyplayer: { [Player]: number } = {}
local Boughtbyplayer: { [Player]: boolean } = {}
local Blockedbyplayer: { [Player]: boolean } = {}
local Erroredbyplayer: { [Player]: boolean } = {}
local Existedbyplayer: { [Player]: boolean } = {}
local Savingbyuserid: { [number]: boolean } = {}
local Activesaves = 0

local function Sanitizestep(Value: any): number?
	if type(Value) ~= "number" or Value ~= Value or Value == math.huge or Value == -math.huge then
		return nil
	end
	return math.clamp(math.floor(Value), 1, Maximumstep)
end

local function Clearplayer(Player: Player)
	Completedbyplayer[Player] = nil
	Loadedbyplayer[Player] = nil
	Objectdonebyplayer[Player] = nil
	Stepbyplayer[Player] = nil
	Boughtbyplayer[Player] = nil
	Blockedbyplayer[Player] = nil
	Erroredbyplayer[Player] = nil
	Existedbyplayer[Player] = nil
end

local function Cansave(Player: Player): boolean
	return Loadedbyplayer[Player] == true
		and not Blockedbyplayer[Player]
		and not Erroredbyplayer[Player]
		and not Core:GetService("DataService"):IsLost(Player)
end

local function Loadplayer(Player: Player)
	Completedbyplayer[Player] = false
	Stepbyplayer[Player] = 1
	Boughtbyplayer[Player] = false
	while Savingbyuserid[Player.UserId] do
		task.wait()
	end
	local Success, Saved = Datastorerequest.Run(Loadattempts, function()
		return Store:GetAsync(tostring(Player.UserId))
	end)
	if not Player.Parent then
		Clearplayer(Player)
		return
	end
	if Success then
		Existedbyplayer[Player] = Saved ~= nil
		if type(Saved) == "table" then
			Completedbyplayer[Player] = Saved.Completed == true
			Stepbyplayer[Player] = Sanitizestep(tonumber(Saved.Step)) or 1
		else
			Completedbyplayer[Player] = Saved == true
		end
	else
		Erroredbyplayer[Player] = true
		warn("TutorialService: could not read data for " .. Player.Name .. ", saving disabled: " .. tostring(Saved))
		if not Isstudio then
			local Dataservice = Core:GetService("DataService")
			Dataservice:WaitForLoad(Player)
			if not Player.Parent then
				Clearplayer(Player)
				return
			end
			Completedbyplayer[Player] = not Dataservice:IsNewProfile(Player)
		end
	end
	Loadedbyplayer[Player] = true
	if not Completedbyplayer[Player] then
		Core:GetService("UpgradeService"):PushUpgrades(Player)
	end
end

function Tutorialservice:Wipe(Userid: number): (boolean, string)
	local Player = Players:GetPlayerByUserId(Userid)
	if Player then
		Blockedbyplayer[Player] = true
		Completedbyplayer[Player] = false
		Objectdonebyplayer[Player] = nil
		Stepbyplayer[Player] = 1
		Boughtbyplayer[Player] = false
	end
	while Savingbyuserid[Userid] do
		task.wait()
	end
	local Success, Error = Datastorerequest.Run(Saveattempts, function()
		Store:RemoveAsync(tostring(Userid))
	end)
	if not Success then
		warn("TutorialService: could not erase data for " .. Userid .. ": " .. tostring(Error))
		return false, tostring(Error)
	end
	return true, "erased"
end

local function Saveplayer(Player: Player): boolean
	local Userid = Player.UserId
	Activesaves += 1
	while Cansave(Player) and Savingbyuserid[Userid] do
		task.wait()
	end
	if not Cansave(Player) then
		Activesaves -= 1
		return false
	end
	Savingbyuserid[Userid] = true
	local Value = {
		Completed = Completedbyplayer[Player] == true,
		Step = Stepbyplayer[Player] or 1,
	}
	local Existed = Existedbyplayer[Player] == true
	local Erased = false
	local Success, Error = Datastorerequest.Run(Saveattempts, function()
		Store:UpdateAsync(tostring(Userid), function(Current)
			if Current == nil and Existed then
				Erased = true
				return nil
			end
			Erased = false
			local Stored = if type(Current) == "table" then Current else { Completed = Current == true }
			return {
				Completed = Value.Completed or Stored.Completed == true,
				Step = math.max(Value.Step, Sanitizestep(tonumber(Stored.Step)) or 1),
			}, { Userid }
		end)
	end)
	Savingbyuserid[Userid] = nil
	Activesaves -= 1
	if not Success then
		warn("TutorialService: could not save data for " .. Player.Name .. ": " .. tostring(Error))
		return false
	end
	if Erased then
		Blockedbyplayer[Player] = true
		warn("TutorialService: " .. Player.Name .. "'s tutorial data was erased elsewhere, saving stopped")
		return false
	end
	if Loadedbyplayer[Player] then
		Existedbyplayer[Player] = true
	end
	return true
end

function Tutorialservice:IsActive(Player: Player): boolean
	while Player.Parent and not Loadedbyplayer[Player] do
		task.wait()
	end
	return Completedbyplayer[Player] == false
end

function Tutorialservice:IsRunning(Player: Player): boolean
	return Loadedbyplayer[Player] == true and Completedbyplayer[Player] == false
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
		Clearplayer(Player)
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(Loadplayer, Player)
	end

	Remotemanager:OnServerInvoke(self.Name, "GetState", function(Player)
		return { Completed = not self:IsActive(Player), Step = Stepbyplayer[Player] or 1 }
	end)

	Remotemanager:OnServerEvent(self.Name, "SetStep", function(Player, Step)
		local Sanitized = Sanitizestep(Step)
		if not Sanitized or Completedbyplayer[Player] == true then
			return
		end
		Stepbyplayer[Player] = Sanitized
	end)

	Remotemanager:OnServerEvent(self.Name, "Complete", function(Player)
		if Completedbyplayer[Player] == true then
			return
		end
		Completedbyplayer[Player] = true
		Core:GetService("CustomerService"):PresentOffer(Player)
		Saveplayer(Player)
	end)
end

function Tutorialservice:Start()
	game:BindToClose(function()
		for _, Player in ipairs(Players:GetPlayers()) do
			task.spawn(Saveplayer, Player)
		end
		local Deadline = os.clock() + Shutdowndeadline
		while Activesaves > 0 and os.clock() < Deadline do
			task.wait()
		end
	end)
end

return Tutorialservice
