local Badgeservice = game:GetService("BadgeService")
local Datastoreservice = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Config = {
	DataStoreName = "SpotlightTutorial_v1",
	WelcomeBadgeId = 3531691600974222,
	TutorialStartDate = "2026-10-23T22:00:00Z",
}

local Store = Datastoreservice:GetDataStore(Config.DataStoreName)
local Tutorialstart = DateTime.fromIsoDate(Config.TutorialStartDate).UnixTimestamp
local Completed: { [Player]: boolean } = {}
local Unsaved: { [Player]: boolean } = {}

local Remotes = Instance.new("Folder")
Remotes.Name = "TutorialRemotes"
local Getcompleted = Instance.new("RemoteFunction")
Getcompleted.Name = "GetCompleted"
Getcompleted.Parent = Remotes
local Completeevent = Instance.new("RemoteEvent")
Completeevent.Name = "Complete"
Completeevent.Parent = Remotes

local function Key(Userid: number): string
	return "Player_" .. Userid
end

local function Skipforbadge(Player: Player): boolean
	local Success, Badges = false, nil
	for Attempt = 1, 3 do
		Success, Badges = pcall(function()
			return Badgeservice:GetUserBadgesAsync(Player.UserId, { Config.WelcomeBadgeId })
		end)
		if Success then
			break
		end
		if Attempt < 3 then
			task.wait(Attempt)
		end
	end
	if not Success then
		warn("[Tutorial] could not check the Welcome badge for " .. Player.Name .. ", the tutorial is skipped: " .. tostring(Badges))
		return true
	end
	for _, Badge in ipairs(Badges) do
		if Badge.BadgeId == Config.WelcomeBadgeId then
			return Badge.AwardedDate.UnixTimestamp < Tutorialstart
		end
	end
	return false
end

local function Load(Player: Player)
	local Success, Saved = false, nil
	for Attempt = 1, 3 do
		Success, Saved = pcall(function()
			return Store:GetAsync(Key(Player.UserId))
		end)
		if Success then
			break
		end
		if Attempt < 3 then
			task.wait(Attempt)
		end
	end
	if not Success then
		warn("[Tutorial] could not load " .. Player.Name .. ", the tutorial is skipped: " .. tostring(Saved))
	end
	local Skip = not Success or Saved == true
	if not Skip and Player.Parent then
		Skip = Skipforbadge(Player)
	end
	if Player.Parent then
		Completed[Player] = Skip
	end
end

local function Save(Player: Player): boolean
	local Success, Failure = pcall(function()
		Store:SetAsync(Key(Player.UserId), true)
	end)
	if not Success then
		warn("[Tutorial] could not save " .. Player.Name .. ": " .. tostring(Failure))
	end
	return Success
end

Getcompleted.OnServerInvoke = function(Player)
	while Player.Parent and Completed[Player] == nil do
		task.wait()
	end
	return Completed[Player] ~= false
end

Completeevent.OnServerEvent:Connect(function(Player)
	if Completed[Player] ~= false then
		return
	end
	Completed[Player] = true
	Unsaved[Player] = true
	local Saved = Save(Player)
	if Player.Parent then
		Unsaved[Player] = not Saved
	end
end)

Players.PlayerAdded:Connect(Load)
for _, Player in ipairs(Players:GetPlayers()) do
	task.spawn(Load, Player)
end

Players.PlayerRemoving:Connect(function(Player)
	if Unsaved[Player] then
		Save(Player)
	end
	Completed[Player] = nil
	Unsaved[Player] = nil
end)

game:BindToClose(function()
	local Pending = 0
	for Player, Needsave in pairs(Unsaved) do
		if Needsave then
			Pending += 1
			task.spawn(function()
				Save(Player)
				Pending -= 1
			end)
		end
	end
	while Pending > 0 do
		task.wait()
	end
end)

Remotes.Parent = Replicatedstorage
