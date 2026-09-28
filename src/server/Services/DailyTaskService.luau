local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Config = require(ReplicatedStorage.Shared.Config.DailyTasks)
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

local function NewData(): DailyTaskData
	local Ids = {}
	for Id in pairs(Config.Tasks) do
		table.insert(Ids, Id)
	end
	local Tasks = {}
	for _ = 1, Config.TaskCount do
		table.insert(Tasks, {
			Id = table.remove(Ids, Generator:NextInteger(1, #Ids)),
			Progress = 0,
			Completed = false,
		})
	end
	return {
		Day = CurrentDay(),
		Tasks = Tasks,
	}
end

function DailyTaskService:EnsurePlayer(Player: Player): DailyTaskData
	local Data = DataByPlayer[Player]
	if Data == nil or Data.Day ~= CurrentDay() then
		Data = NewData()
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

function DailyTaskService:AddProgress(Player: Player, Id: string, Amount: number)
	for _, Task in ipairs(self:EnsurePlayer(Player).Tasks) do
		if Task.Id == Id and not Task.Completed then
			local Definition = Config.Tasks[Id]
			Task.Progress = math.min(Task.Progress + Amount, Definition.Goal)
			if Task.Progress >= Definition.Goal then
				Task.Completed = true
				Core:GetService("CashService"):AddCash(Player, Definition.Reward, false)
				RemoteManager:FireClient(self.Name, "TaskCompleted", Player, Id)
			end
			self:PushState(Player)
		end
	end
end

function DailyTaskService:Init()
	Core:GetService("DataService"):Register("DailyTasks", {
		Load = function(Player, Saved)
			if Saved.Day == CurrentDay() then
				local Tasks = {}
				for _, Task in ipairs(Saved.Tasks) do
					local Definition = Config.Tasks[Task.Id]
					if Definition then
						table.insert(Tasks, {
							Id = Task.Id,
							Progress = math.clamp(tonumber(Task.Progress) or 0, 0, Definition.Goal),
							Completed = Task.Completed == true,
						})
					end
				end
				DataByPlayer[Player] = {
					Day = Saved.Day,
					Tasks = Tasks,
				}
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
