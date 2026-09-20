local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)
local Codesconfig = require(script.Parent.Parent.Config.Codes)

local Codeservice = {
	Name = "CodeService",
	Priority = 6,
	Remotes = {
		RedeemCode = "Function",
	},
}

local Maxcodelength = 32
local Claimedbyplayer: { [Player]: { [string]: boolean } } = {}

local function Normalize(Code: any): string
	return (string.upper(string.gsub(tostring(Code), "%s", "")))
end

local Rewardsbycode: { [string]: any } = {}
for Name, Reward in pairs(Codesconfig) do
	Rewardsbycode[Normalize(Name)] = Reward
end

function Codeservice:EnsurePlayer(Player: Player): { [string]: boolean }
	local Claimed = Claimedbyplayer[Player]
	if not Claimed then
		Claimed = {}
		Claimedbyplayer[Player] = Claimed
	end
	return Claimed
end

function Codeservice:GrantReward(Player: Player, Reward: any): boolean
	if Reward.Type == "Cash" then
		Core:GetService("CashService"):AddCash(Player, tonumber(Reward.Amount) or 0, false, true)
		return true
	end
	if Reward.Type == "Object" then
		return (Core:GetService("RestorationService"):GrantObject(Player, tostring(Reward.ObjectKey)))
	end
	if Reward.Type == "SaleBoost" then
		Core:GetService("DailyRewardService"):GrantSaleBoost(Player, tonumber(Reward.DurationSeconds) or 0)
		return true
	end
	return false
end

function Codeservice:RedeemCode(Player: Player, Code: any)
	local Normalized = Normalize(Code)
	if #Normalized == 0 or #Normalized > Maxcodelength then
		return { Success = false, Reason = "Unknown" }
	end

	local Reward = Rewardsbycode[Normalized]
	if not Reward then
		return { Success = false, Reason = "Unknown" }
	end

	local Claimed = self:EnsurePlayer(Player)
	if Claimed[Normalized] then
		return { Success = false, Reason = "AlreadyClaimed" }
	end

	Claimed[Normalized] = true
	if not self:GrantReward(Player, Reward) then
		Claimed[Normalized] = nil
		return { Success = false, Reason = "RewardFailed" }
	end

	return { Success = true, Code = Normalized, ValueText = tostring(Reward.ValueText) }
end

function Codeservice:Init()
	Core:GetService("DataService"):Register("Codes", {
		Load = function(Player, Saved)
			local Claimed = self:EnsurePlayer(Player)
			for Name, Value in pairs(Saved) do
				if Value == true then
					Claimed[Name] = true
				end
			end
		end,
		Save = function(Player)
			return table.clone(self:EnsurePlayer(Player))
		end,
		Clear = function(Player)
			Claimedbyplayer[Player] = nil
		end,
	})

	Remotemanager:OnServerInvoke(self.Name, "RedeemCode", function(Player, Code)
		Core:GetService("DataService"):WaitForLoad(Player)
		if not Player.Parent then
			return { Success = false, Reason = "Unknown" }
		end
		return self:RedeemCode(Player, Code)
	end)
end

return Codeservice
