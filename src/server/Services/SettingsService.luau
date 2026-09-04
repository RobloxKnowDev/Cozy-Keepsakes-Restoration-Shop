local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Settingsservice = {
	Name = "SettingsService",
	Priority = 6,
	Remotes = {
		GetSettings = "Function",
		SetSetting = "Event",
	},
}

local Defaults = {
	Graphism = true,
	Effect = true,
	MusicVolume = 0.5,
	SoundEffect = 0.5,
}

local Settingsbyplayer: { [Player]: { [string]: any } } = {}

function Settingsservice:EnsurePlayer(Player: Player): { [string]: any }
	local Settings = Settingsbyplayer[Player]
	if not Settings then
		Settings = table.clone(Defaults)
		Settingsbyplayer[Player] = Settings
	end
	return Settings
end

function Settingsservice:GetSettings(Player: Player): { [string]: any }
	return table.clone(self:EnsurePlayer(Player))
end

function Settingsservice:SetSetting(Player: Player, Name: string, Value: any)
	local Default = Defaults[Name]
	local Settings = self:EnsurePlayer(Player)
	if type(Default) == "boolean" then
		Settings[Name] = Value == true
	elseif type(Default) == "number" then
		Settings[Name] = math.clamp(tonumber(Value) or Default, 0, 1)
	end
end

function Settingsservice:Init()
	Core:GetService("DataService"):Register("Settings", {
		Load = function(Player, Saved)
			local Settings = self:EnsurePlayer(Player)
			for Name, Default in pairs(Defaults) do
				if type(Default) == "boolean" then
					Settings[Name] = if Saved[Name] == nil then Default else Saved[Name] == true
				else
					Settings[Name] = math.clamp(tonumber(Saved[Name]) or Default, 0, 1)
				end
			end
		end,
		Save = function(Player)
			return self:GetSettings(Player)
		end,
		Clear = function(Player)
			Settingsbyplayer[Player] = nil
		end,
	})

	Remotemanager:OnServerInvoke(self.Name, "GetSettings", function(Player)
		Core:GetService("DataService"):WaitForLoad(Player)
		return self:GetSettings(Player)
	end)

	Remotemanager:OnServerEvent(self.Name, "SetSetting", function(Player, Name, Value)
		self:SetSetting(Player, tostring(Name), Value)
	end)
end

return Settingsservice
