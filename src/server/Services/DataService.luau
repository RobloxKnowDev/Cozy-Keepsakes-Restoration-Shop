local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Dataservice = {
	Name = "DataService",
	Priority = 1,
}

local Store = DataStoreService:GetDataStore("PlayerData_v1")
local Usedatastore = true
local Verboselogs = false
local Autosaveinterval = 20
local Sectionorder = { "Cash", "Stats", "Upgrades", "Inventory", "Exposition", "Monetization", "Settings" }

type Section = { Load: (Player, any) -> (), Save: (Player) -> any, Clear: (Player) -> () }

local Sections: { [string]: Section } = {}
local Loadedbyplayer: { [Player]: boolean } = {}
local Savingbyplayer: { [Player]: boolean } = {}
local Blockedbyplayer: { [Player]: boolean } = {}

local function Log(Message: string)
	if Verboselogs then
		print("[DataService] " .. Message)
	end
end

local function Describe(Value: any): string
	if type(Value) ~= "table" then
		return tostring(Value)
	end
	local Keys = {}
	for Key in pairs(Value) do
		table.insert(Keys, tostring(Key))
	end
	table.sort(Keys)
	return "{" .. table.concat(Keys, ", ") .. "}"
end

function Dataservice:Register(Name: string, Handlers: Section)
	assert(table.find(Sectionorder, Name), "DataService: unknown section " .. Name)
	Sections[Name] = Handlers
	Log("section registered: " .. Name)
end

function Dataservice:IsLoaded(Player: Player): boolean
	return Loadedbyplayer[Player] == true
end

function Dataservice:WaitForLoad(Player: Player)
	while Player.Parent and not Loadedbyplayer[Player] do
		task.wait()
	end
end

local function Applysaved(Player: Player, Saved: any)
	if type(Saved) ~= "table" then
		Log("no save to apply for " .. Player.Name .. " (" .. tostring(Saved) .. ")")
		return
	end
	for _, Name in ipairs(Sectionorder) do
		local Handlers = Sections[Name]
		if not Handlers then
			Log("section " .. Name .. " NOT registered, skipped")
		elseif Saved[Name] == nil then
			Log("nothing saved for section " .. Name)
		else
			local Success, Error = pcall(Handlers.Load, Player, Saved[Name])
			if Success then
				Log("applied " .. Name .. " = " .. Describe(Saved[Name]))
			else
				warn("DataService: could not load " .. Name .. " for " .. Player.Name .. ": " .. tostring(Error))
			end
		end
	end
end

local function Loadplayer(Player: Player)
	if Loadedbyplayer[Player] ~= nil then
		return
	end
	Loadedbyplayer[Player] = false
	Log("loading " .. Player.Name .. " (key " .. Player.UserId .. ")")
	local Saved = nil
	if Usedatastore then
		local Success, Result = pcall(function()
			return Store:GetAsync(tostring(Player.UserId))
		end)
		if Success then
			Saved = Result
			Log("read for " .. Player.Name .. ": " .. Describe(Result))
		else
			warn("DataService: could not read data for " .. Player.Name .. ": " .. tostring(Result))
		end
	end
	if not Player.Parent then
		Loadedbyplayer[Player] = nil
		return
	end
	Applysaved(Player, Saved)
	Loadedbyplayer[Player] = true
	Log(Player.Name .. " is loaded, saving enabled")
end

local function Refusalreason(Player: Player): string?
	if not Usedatastore then
		return "DataStore disabled"
	elseif Blockedbyplayer[Player] then
		return "data erased, saving blocked"
	elseif not Loadedbyplayer[Player] then
		return "profile not loaded yet"
	elseif Savingbyplayer[Player] then
		return "save already in progress"
	end
	return nil
end

local function Buildsnapshot(Player: Player): { [string]: any }
	local Snapshot = {}
	for _, Name in ipairs(Sectionorder) do
		local Handlers = Sections[Name]
		if not Handlers then
			Log("section " .. Name .. " NOT registered, nothing to save")
		else
			local Success, Value = pcall(Handlers.Save, Player)
			if Success then
				Snapshot[Name] = Value
				Log("  " .. Name .. " = " .. Describe(Value))
			else
				warn("DataService: could not save " .. Name .. " for " .. Player.Name .. ": " .. tostring(Value))
			end
		end
	end
	return Snapshot
end

local function Clearsections(Player: Player)
	for _, Name in ipairs(Sectionorder) do
		local Handlers = Sections[Name]
		if Handlers then
			Handlers.Clear(Player)
		end
	end
	Log("memory released for " .. Player.Name)
end

local function Writesnapshot(Player: Player, Snapshot: { [string]: any }): (boolean, string)
	Savingbyplayer[Player] = true
	local Success, Error = pcall(function()
		Store:SetAsync(tostring(Player.UserId), Snapshot)
	end)
	Savingbyplayer[Player] = nil
	if not Success then
		warn("DataService: could not write data for " .. Player.Name .. ": " .. tostring(Error))
		return false, tostring(Error)
	end
	Log("written for " .. Player.Name .. ": " .. Describe(Snapshot))
	return true, "ok"
end

function Dataservice:Save(Player: Player): (boolean, string)
	local Refusal = Refusalreason(Player)
	if Refusal then
		Log("save REFUSED for " .. Player.Name .. ": " .. Refusal)
		return false, Refusal
	end
	Log("saving " .. Player.Name .. "...")
	return Writesnapshot(Player, Buildsnapshot(Player))
end

function Dataservice:Saveandrelease(Player: Player)
	local Refusal = Refusalreason(Player)
	if Refusal then
		Log("save REFUSED for " .. Player.Name .. ": " .. Refusal)
		Clearsections(Player)
		Loadedbyplayer[Player] = nil
		Blockedbyplayer[Player] = nil
		return
	end
	Log("saving " .. Player.Name .. " before they leave...")
	local Snapshot = Buildsnapshot(Player)
	Clearsections(Player)
	Loadedbyplayer[Player] = nil
	Writesnapshot(Player, Snapshot)
end

function Dataservice:Wipe(Player: Player): boolean
	Blockedbyplayer[Player] = true
	local Success, Error = pcall(function()
		Store:RemoveAsync(tostring(Player.UserId))
	end)
	if not Success then
		warn("DataService: could not erase data for " .. Player.Name .. ": " .. tostring(Error))
	end
	return Success
end

function Dataservice:Init()
	Players.PlayerRemoving:Connect(function(Player)
		Log("leaving: " .. Player.Name)
		self:Saveandrelease(Player)
	end)
end

function Dataservice:Start()
	task.spawn(function()
		local Success, Error = pcall(function()
			Store:SetAsync("Probe", os.time())
		end)
		if Success then
			Log("DataStore ready")
		else
			warn("DataService: DATASTORE UNAVAILABLE - " .. tostring(Error))
			warn("DataService: tick Game Settings > Security > Enable Studio Access to API Services")
		end
	end)

	Players.PlayerAdded:Connect(function(Player)
		task.spawn(Loadplayer, Player)
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(Loadplayer, Player)
	end

	game:BindToClose(function()
		Log("server shutting down")
		for _, Player in ipairs(Players:GetPlayers()) do
			task.spawn(function()
				self:Saveandrelease(Player)
			end)
		end
		while next(Savingbyplayer) do
			task.wait()
		end
		Log("server shutdown: saves complete")
	end)

	task.spawn(function()
		while true do
			task.wait(Autosaveinterval)
			Log("autosave")
			for _, Player in ipairs(Players:GetPlayers()) do
				self:Save(Player)
			end
		end
	end)
end

return Dataservice
