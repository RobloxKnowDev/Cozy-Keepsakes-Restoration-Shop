local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Config = require(ReplicatedStorage.Shared.Config.DailyTasks)
local FormatDuration = require(ReplicatedStorage.Shared.Utils.DurationFormatter)
local Rarityconfig = require(ReplicatedStorage.Shared.Config.Rarity)
local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Shared = require(script.Parent.Shared)

local DailyTasks = {}
local CompletedGradient = Rarityconfig.Common.Gradient

local function FormatAmount(Definition, Value: number): string
	if Definition.Currency then
		return Shared.FormatCurrency(math.floor(Value))
	end
	return tostring(Value)
end

local function TaskText(Task): string
	local Definition = Config.Tasks[Task.Id]
	return string.format(Definition.Text, FormatAmount(Definition, Task.Goal))
end

function DailyTasks.UpdateReset(Controller)
	Controller.dailyTasksResetText.Text = "Reset in " .. FormatDuration(Controller.dailyTasksResetAt - Workspace:GetServerTimeNow())
end

function DailyTasks.Apply(Controller, State)
	Controller.dailyTasksResetAt = State.ResetAt
	for _, Card in ipairs(Controller.dailyTaskCards) do
		Card:Destroy()
	end
	table.clear(Controller.dailyTaskCards)
	for Order, Task in ipairs(State.Tasks) do
		local Definition = Config.Tasks[Task.Id]
		local Card = Controller.dailyTaskTemplate:Clone()
		Card.Name = "Task_" .. Order
		Card.LayoutOrder = Order
		Card.Visible = true
		Card:WaitForChild("NameText").Text = TaskText(Task)
		Card:WaitForChild("NumberText").Text = FormatAmount(Definition, Task.Progress) .. "/" .. FormatAmount(Definition, Task.Goal)
		Card:WaitForChild("CashText").Text = Shared.FormatCurrency(Task.Reward)
		Card:WaitForChild("FrameBar"):WaitForChild("Bar").Size = UDim2.fromScale(math.clamp(Task.Progress / Task.Goal, 0, 1), 1)
		Card.Parent = Controller.dailyTasksList
		table.insert(Controller.dailyTaskCards, Card)
	end
	DailyTasks.UpdateReset(Controller)
end

function DailyTasks.Init(Controller)
	local TasksFrame = Controller.homePage:WaitForChild("DailyTasksFrame")
	Controller.dailyTasksList = TasksFrame:WaitForChild("Tasks")
	Controller.dailyTaskTemplate = Controller.dailyTasksList:WaitForChild("Template")
	Controller.dailyTasksResetText = TasksFrame:WaitForChild("ResetText")
	Controller.dailyTasksList:WaitForChild("UIListLayout").SortOrder = Enum.SortOrder.LayoutOrder
	Controller.dailyTaskTemplate.Visible = false
	Controller.dailyTaskCards = {}
	DailyTasks.Apply(Controller, RemoteManager:InvokeServer("DailyTaskService", "GetState"))
end

function DailyTasks.Start(Controller)
	RemoteManager:OnClientEvent("DailyTaskService", "StateUpdated", function(State)
		DailyTasks.Apply(Controller, State)
	end)
	RemoteManager:OnClientEvent("DailyTaskService", "TaskCompleted", function(Task)
		Core:GetController("MessageController"):Show(
			"Task completed: " .. TaskText(Task) .. " +" .. Shared.FormatCurrency(Task.Reward),
			CompletedGradient
		)
		Core:GetController("FeedbackController"):DailyTaskReward(Task.Reward)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			DailyTasks.UpdateReset(Controller)
		end
	end)
end

return DailyTasks
