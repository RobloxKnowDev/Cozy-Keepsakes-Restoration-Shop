local Groupservice = game:GetService("GroupService")
local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Config = require(Replicatedstorage.Shared.Config.FreeReward)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Freerewardservice = {
	Name = "FreeRewardService",
	Priority = 6,
	Remotes = {
		ClaimFreeReward = "Function",
	},
}

local Claimed: { [Player]: boolean } = {}
local Claiming: { [Player]: boolean } = {}
local Lastcheck: { [Player]: number } = {}

local function Setclaimed(Player: Player, Value: boolean)
	Claimed[Player] = Value
	Player:SetAttribute("FreeRewardClaimed", Value)
end

local function Baseclaimed(Player: Player)
	Core:GetService("DataService"):WaitForLoad(Player)
	if Player.Parent and Claimed[Player] == nil then
		Setclaimed(Player, false)
	end
end

local function Isingroup(Userid: number): boolean?
	local Success, Groups = pcall(function()
		return Groupservice:GetGroupsAsync(Userid)
	end)
	if not Success then
		return nil
	end
	for _, Group in ipairs(Groups) do
		if Group.Id == Config.GroupId then
			return true
		end
	end
	return false
end

local function Claim(Player: Player)
	if Claimed[Player] == true then
		return { Success = false, Reason = "Claimed" }
	end
	if Claimed[Player] ~= false or Claiming[Player] or not Core:GetService("DataService"):IsLoaded(Player) then
		return { Success = false, Reason = "Busy" }
	end
	local Now = os.clock()
	if Now - (Lastcheck[Player] or -math.huge) < Config.CheckSeconds then
		return { Success = false, Reason = "Busy" }
	end
	Lastcheck[Player] = Now
	Claiming[Player] = true
	local Member = Isingroup(Player.UserId)
	Claiming[Player] = nil
	if not Player.Parent or Claimed[Player] ~= false or Member == nil then
		return { Success = false, Reason = "Busy" }
	end
	if not Member then
		return { Success = false, Reason = "NotInGroup" }
	end
	Setclaimed(Player, true)
	Core:GetService("CashService"):AddCash(Player, Config.Cash, false, true)
	task.spawn(function()
		Core:GetService("DataService"):Save(Player)
	end)
	return { Success = true, Cash = Config.Cash }
end

function Freerewardservice:IsInGroup(Userid: number): boolean?
	return Isingroup(Userid)
end

function Freerewardservice:Init()
	Core:GetService("DataService"):Register("FreeReward", {
		Load = function(Player, Saved)
			Setclaimed(Player, Saved.Claimed == true)
		end,
		Save = function(Player)
			return { Claimed = Claimed[Player] == true }
		end,
		Clear = function(Player)
			Claimed[Player] = nil
			Claiming[Player] = nil
			Lastcheck[Player] = nil
		end,
	})
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(Baseclaimed, Player)
	end
	Players.PlayerAdded:Connect(function(Player)
		task.spawn(Baseclaimed, Player)
	end)
	Remotemanager:OnServerInvoke(self.Name, "ClaimFreeReward", Claim)
end

return Freerewardservice
