local Analyticsservice = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Rarityconfig = require(Replicatedstorage.Shared.Config.Rarity)
local Funnelconfig = require(script.Parent.Parent.Config.Funnel)

local Funnelservice = {
	Name = "FunnelService",
	Priority = 6,
}

type FunnelState = {
	Ready: boolean,
	Tracked: boolean?,
	Bought: number,
	Cleaned: number,
	Best: number,
	Steps: { [string]: number },
}

local Loggedbyplayer: { [Player]: { [number]: boolean } } = {}
local Statebyplayer: { [Player]: FunnelState } = {}

local function Ensurestate(Player: Player): FunnelState
	local State = Statebyplayer[Player]
	if not State then
		State = {
			Ready = false,
			Tracked = nil,
			Bought = 0,
			Cleaned = 0,
			Best = 0,
			Steps = {},
		}
		for _, Chain in ipairs(Funnelconfig.Chains) do
			State.Steps[Chain.Name] = 0
		end
		Statebyplayer[Player] = State
	end
	return State
end

local function Send(Player: Player, Key: string, Log: () -> ())
	local Success, Failure = pcall(Log)
	if not Success then
		warn("FunnelService: " .. Key .. " for " .. Player.Name .. ": " .. tostring(Failure))
	end
end

local function Reached(Player: Player, State: FunnelState, Step): boolean
	if Step.Tutorial then
		return not Core:GetService("TutorialService"):IsActive(Player)
	elseif Step.Bought then
		return State.Bought >= Step.Bought
	elseif Step.Cleaned then
		return State.Cleaned >= Step.Cleaned
	elseif Step.Sold then
		return Core:GetService("StatsService"):GetStats(Player).ItemsSold >= Step.Sold
	elseif Step.Upgrades then
		return Core:GetService("UpgradeService"):GetBoughtLevels(Player) >= Step.Upgrades
	elseif Step.Luck then
		return Core:GetService("StatsService"):GetRankedReputation(Player) >= Step.Luck
	end
	return State.Best >= table.find(Rarityconfig.Order, Step.Rarity)
end

local function Isplaying(Player: Player, State: FunnelState): boolean
	return State.Ready and State.Tracked == true and not Core:GetService("TutorialService"):IsActive(Player)
end

local function Logonboarding(Player: Player, Index: number, Name: string)
	local Logged = Loggedbyplayer[Player] or {}
	Loggedbyplayer[Player] = Logged
	if Logged[Index] then
		return
	end
	Logged[Index] = true
	Send(Player, "Onboarding " .. Name, function()
		Analyticsservice:LogOnboardingFunnelStepEvent(Player, Index, Name)
	end)
end

function Funnelservice:LogTutorial(Player: Player, Index: number)
	local Step = Funnelconfig.Tutorial[Index]
	if not Step then
		return
	end
	Logonboarding(Player, Index, Step.Name)
end

function Funnelservice:LogLesson(Player: Player, Id: string)
	for Index, Step in ipairs(Funnelconfig.Lessons) do
		if Step.Id == Id then
			if Ensurestate(Player).Tracked == true then
				Logonboarding(Player, #Funnelconfig.Tutorial + Index, Step.Name)
			end
			return
		end
	end
end

function Funnelservice:LogTutorialComplete(Player: Player)
	self:LogTutorial(Player, #Funnelconfig.Tutorial)
	self:Refresh(Player)
end

function Funnelservice:Refresh(Player: Player)
	local State = Ensurestate(Player)
	if not State.Ready or State.Tracked ~= true then
		return
	end
	for _, Chain in ipairs(Funnelconfig.Chains) do
		local Index = State.Steps[Chain.Name]
		while Chain.Steps[Index + 1] and Reached(Player, State, Chain.Steps[Index + 1]) do
			Index += 1
			State.Steps[Chain.Name] = Index
			local Step = Chain.Steps[Index]
			Send(Player, Chain.Name .. " " .. Step.Name, function()
				Analyticsservice:LogFunnelStepEvent(Player, Chain.Name, tostring(Player.UserId), Index, Step.Name)
			end)
		end
	end
end

function Funnelservice:RecordPurchase(Player: Player, Rarity: string)
	local State = Ensurestate(Player)
	if not Isplaying(Player, State) then
		return
	end
	State.Bought += 1
	State.Best = math.max(State.Best, table.find(Rarityconfig.Order, Rarity))
	self:Refresh(Player)
end

function Funnelservice:RecordCleaned(Player: Player)
	local State = Ensurestate(Player)
	if not Isplaying(Player, State) then
		return
	end
	State.Cleaned += 1
	self:Refresh(Player)
end

function Funnelservice:Init()
	Core:GetService("DataService"):Register("Funnel", {
		Load = function(Player, Saved)
			local State = Ensurestate(Player)
			State.Tracked = Saved.Tracked == true
			State.Bought = math.max(tonumber(Saved.Bought) or 0, 0)
			State.Cleaned = math.max(tonumber(Saved.Cleaned) or 0, 0)
			State.Best = math.max(tonumber(Saved.Best) or 0, 0)
			for _, Chain in ipairs(Funnelconfig.Chains) do
				State.Steps[Chain.Name] = math.clamp(tonumber(Saved.Steps[Chain.Name]) or 0, 0, #Chain.Steps)
			end
		end,
		Save = function(Player)
			local State = Ensurestate(Player)
			return {
				Tracked = State.Tracked == true,
				Bought = State.Bought,
				Cleaned = State.Cleaned,
				Best = State.Best,
				Steps = table.clone(State.Steps),
			}
		end,
		Clear = function(Player)
			Statebyplayer[Player] = nil
			Loggedbyplayer[Player] = nil
		end,
	})
	Players.PlayerAdded:Connect(function(Player)
		local Dataservice = Core:GetService("DataService")
		Dataservice:WaitForLoad(Player)
		if not Player.Parent then
			return
		end
		local State = Ensurestate(Player)
		if State.Tracked == nil then
			State.Tracked = Dataservice:IsNewProfile(Player)
		end
		State.Ready = true
		self:Refresh(Player)
	end)
end

return Funnelservice
