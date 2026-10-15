local Analyticsservice = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Funnelconfig = require(script.Parent.Parent.Config.Funnel)

local Funnelservice = {
	Name = "FunnelService",
	Priority = 6,
}

local Loggedbyplayer: { [Player]: { [string]: boolean } } = {}
local Earlysteps: { [string]: number } = {}
for Step, Name in ipairs(Funnelconfig.Early.Steps) do
	Earlysteps[Name] = Step
end

local function Once(Player: Player, Key: string): boolean
	local Logged = Loggedbyplayer[Player]
	if not Logged then
		Logged = {}
		Loggedbyplayer[Player] = Logged
	end
	if Logged[Key] then
		return false
	end
	Logged[Key] = true
	return true
end

local function Send(Player: Player, Key: string, Log: () -> ())
	if not Once(Player, Key) then
		return
	end
	local Success, Failure = pcall(Log)
	if not Success then
		warn("FunnelService: " .. Key .. " for " .. Player.Name .. ": " .. tostring(Failure))
	end
end

function Funnelservice:LogTutorial(Player: Player, Step: number)
	Send(Player, "Tutorial" .. Step, function()
		Analyticsservice:LogOnboardingFunnelStepEvent(Player, Step, Funnelconfig.Tutorial[Step])
	end)
end

function Funnelservice:LogTutorialComplete(Player: Player)
	self:LogTutorial(Player, #Funnelconfig.Tutorial)
end

function Funnelservice:LogEarly(Player: Player, Name: string)
	local Step = Earlysteps[Name]
	Send(Player, "Early" .. Name, function()
		Analyticsservice:LogFunnelStepEvent(Player, Funnelconfig.Early.Name, tostring(Player.UserId), Step, Name)
	end)
end

function Funnelservice:LogLuck(Player: Player, Luck: number)
	for _, Milestone in ipairs(Funnelconfig.Early.Luck) do
		if Luck < Milestone.Amount then
			return
		end
		self:LogEarly(Player, Milestone.Name)
	end
end

function Funnelservice:LogAfterTutorial(Player: Player, Name: string)
	if Core:GetService("TutorialService"):IsActive(Player) then
		return
	end
	self:LogEarly(Player, Name)
end

function Funnelservice:Init()
	Players.PlayerRemoving:Connect(function(Player)
		Loggedbyplayer[Player] = nil
	end)
	Players.PlayerAdded:Connect(function(Player)
		local Dataservice = Core:GetService("DataService")
		Dataservice:WaitForLoad(Player)
		if Player.Parent and not Dataservice:IsNewProfile(Player) then
			self:LogEarly(Player, "SecondSession")
		end
	end)
end

function Funnelservice:Start()
	Core:GetService("DayNightService").DayChanged.Event:Connect(function(Player, Day)
		local Name = Funnelconfig.Early.Days[Day]
		if Name then
			self:LogEarly(Player, Name)
		end
	end)
end

return Funnelservice
