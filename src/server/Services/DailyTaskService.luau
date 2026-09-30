local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Config = require(ReplicatedStorage.Shared.Config.DailyTasks)
local Rarityconfig = require(ReplicatedStorage.Shared.Config.Rarity)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)

local DailyTaskService = {
	Name = "DailyTaskService",
	Priority = 6,
	Remotes = {
		GetState = "Function",
		StateUpdated = "Event",
		TaskCompleted = "Event",
	},
}

type DailyTask = {
	Id: string,
	Goal: number,
	Reward: number,
	Progress: number,
	Completed: boolean,
}

type DailyTaskData = {
	Day: number,
	Tasks: { DailyTask },
}

local DaySeconds = 24 * 60 * 60
local Generator = Random.new()
local DataByPlayer: { [Player]: DailyTaskData } = {}

local function CurrentDay(): number
	return math.floor(Workspace:GetServerTimeNow() / DaySeconds)
end

local function NewData(Player: Player, Previous: { DailyTask }, Forced: string?): DailyTaskData
	local Sold = Core:GetService("StatsService"):GetStats(Player).ItemsSold
	local Repeated = {}
	for _, Task in ipairs(Previous) do
		Repeated[Task.Id] = true
	end
	local Candidates = {}
	for Id, Definition in pairs(Config.Tasks) do
		local Tiers = {}
		for _, Tier in ipairs(Definition.Tiers) do
			if Id == Forced or Sold >= (Tier.MinimumSold or 0) then
				table.insert(Tiers, Tier)
			end
		end
		if #Tiers > 0 then
			table.insert(Candidates, {
				Id = Id,
				Event = Definition.Event,
				Tiers = Tiers,
				Order = if Id == Forced then -1 else Generator:NextNumber() + (if Repeated[Id] then 1 else 0),
			})
		end
	end
	table.sort(Candidates, function(First, Second)
		return First.Order < Second.Order
	end)
	local Picked = {}
	local Events = {}
	for _, Candidate in ipairs(Candidates) do
		if #Picked < Config.TaskCount and not Events[Candidate.Event] then
			Events[Candidate.Event] = true
			table.insert(Picked, Candidate)
		end
	end
	for _, Candidate in ipairs(Candidates) do
		if #Picked < Config.TaskCount and not table.find(Picked, Candidate) then
			table.insert(Picked, Candidate)
		end
	end
	local Tasks = {}
	for _, Candidate in ipairs(Picked) do
		local Tier = Candidate.Tiers[Generator:NextInteger(1, #Candidate.Tiers)]
		table.insert(Tasks, {
			Id = Candidate.Id,
			Goal = Tier.Goal,
			Reward = Tier.Reward,
			Progress = 0,
			Completed = false,
		})
	end
	return {
		Day = CurrentDay(),
		Tasks = Tasks,
	}
end

local function IsValid(Tasks: { any }): boolean
	for _, Task in ipairs(Tasks) do
		if not Config.Tasks[Task.Id] or type(Task.Goal) ~= "number" or type(Task.Reward) ~= "number" then
			return false
		end
	end
	return true
end

local function Matches(Definition, Data): boolean
	if Definition.Rarity and (table.find(Rarityconfig.Order, Data.Rarity) or 0) < table.find(Rarityconfig.Order, Definition.Rarity) then
		return false
	end
	if Definition.Mutated and Data.Mutation == "Normal" then
		return false
	end
	if Definition.Family and not table.find(Config.Families[Definition.Family], Data.ObjectKey) then
		return false
	end
	if Definition.Tool and Data.Tool ~= Definition.Tool then
		return false
	end
	if Definition.Restored and Data.Percent < 100 then
		return false
	end
	if Definition.FromScratch and Data.Start > 0 then
		return false
	end
	return true
end

function DailyTaskService:EnsurePlayer(Player: Player): DailyTaskData
	local Data = DataByPlayer[Player]
	if Data == nil or Data.Day ~= CurrentDay() then
		Data = NewData(Player, if Data then Data.Tasks else {})
		DataByPlayer[Player] = Data
	end
	return Data
end

function DailyTaskService:GetState(Player: Player)
	local Data = self:EnsurePlayer(Player)
	return {
		ResetAt = (Data.Day + 1) * DaySeconds,
		Tasks = Data.Tasks,
	}
end

function DailyTaskService:PushState(Player: Player)
	RemoteManager:FireClient(self.Name, "StateUpdated", Player, self:GetState(Player))
end

function DailyTaskService:Record(Player: Player, Event: string, Data: { [string]: any })
	if not Core:GetService("DataService"):IsLoaded(Player) then
		return
	end
	local Changed = false
	for _, Task in ipairs(self:EnsurePlayer(Player).Tasks) do
		local Definition = Config.Tasks[Task.Id]
		if not Task.Completed and Definition.Event == Event and Matches(Definition, Data) then
			local Amount = math.max(if Definition.Measure then Data[Definition.Measure] else 1, 0)
			local Progress = math.min(if Definition.Single then math.max(Task.Progress, Amount) else Task.Progress + Amount, Task.Goal)
			if Progress > Task.Progress then
				Task.Progress = Progress
				Changed = true
				if Progress >= Task.Goal then
					Task.Completed = true
					Core:GetService("CashService"):AddCash(Player, Task.Reward, false)
					RemoteManager:FireClient(self.Name, "TaskCompleted", Player, Task)
				end
			end
		end
	end
	if Changed then
		self:PushState(Player)
	end
end

function DailyTaskService:Reroll(Player: Player, Forced: string?)
	DataByPlayer[Player] = NewData(Player, self:EnsurePlayer(Player).Tasks, Forced)
	self:PushState(Player)
end

function DailyTaskService:Init()
	Core:GetService("DataService"):Register("DailyTasks", {
		Load = function(Player, Saved)
			if Saved.Day == CurrentDay() and IsValid(Saved.Tasks) then
				local Tasks = {}
				for _, Task in ipairs(Saved.Tasks) do
					table.insert(Tasks, {
						Id = Task.Id,
						Goal = Task.Goal,
						Reward = Task.Reward,
						Progress = math.clamp(tonumber(Task.Progress) or 0, 0, Task.Goal),
						Completed = Task.Completed == true,
					})
				end
				DataByPlayer[Player] = {
					Day = Saved.Day,
					Tasks = Tasks,
				}
			else
				DataByPlayer[Player] = NewData(Player, Saved.Tasks)
			end
			self:PushState(Player)
		end,
		Save = function(Player)
			local Data = self:EnsurePlayer(Player)
			local Tasks = {}
			for _, Task in ipairs(Data.Tasks) do
				table.insert(Tasks, table.clone(Task))
			end
			return {
				Day = Data.Day,
				Tasks = Tasks,
			}
		end,
		Clear = function(Player)
			DataByPlayer[Player] = nil
		end,
	})

	Lighting:GetAttributeChangedSignal("Day"):Connect(function()
		for _, Player in ipairs(Players:GetPlayers()) do
			self:Record(Player, "Day", {})
		end
	end)

	RemoteManager:OnServerInvoke(self.Name, "GetState", function(Player)
		return self:GetState(Player)
	end)
end

function DailyTaskService:Start()
	task.spawn(function()
		local PushedDay = CurrentDay()
		while true do
			task.wait(1)
			local Day = CurrentDay()
			if Day ~= PushedDay then
				PushedDay = Day
				for Player in pairs(DataByPlayer) do
					if Player.Parent then
						self:PushState(Player)
					end
				end
			end
		end
	end)
end

return DailyTaskService
