local Replicatedstorage = game:GetService("ReplicatedStorage")
local Changehistoryservice = game:GetService("ChangeHistoryService")
assert(game:GetService("RunService"):IsEdit(), "Clear dirt textures: run this in Edit mode, not during Play")
local Cleaningconfig = require(Replicatedstorage.Shared.Config.Cleaning)
local Templates = Replicatedstorage.Asset.Object

local Recorded, Recording = pcall(Changehistoryservice.TryBeginRecording, Changehistoryservice, "ClearDirtTextures", "Clear dirt textures")
local Cleared = 0
local Objects = 0
for _, Object in ipairs(Templates:GetChildren()) do
	local Count = 0
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("Decal") and Cleaningconfig.DirtDecals[Descendant.Name] and Descendant.Texture ~= "" then
			Descendant.Texture = ""
			Count += 1
		end
	end
	if Count > 0 then
		Objects += 1
		Cleared += Count
		print(string.format("%s: %d decals", Object.Name, Count))
	end
end
if Recorded and Recording then
	Changehistoryservice:FinishRecording(Recording, Enum.FinishRecordingOperation.Commit)
end
print(string.format("Clear dirt textures: %d decals cleared in %d objects (Ctrl+Z to undo)", Cleared, Objects))
