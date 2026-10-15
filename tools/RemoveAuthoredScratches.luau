local Replicatedstorage = game:GetService("ReplicatedStorage")
local Changehistoryservice = game:GetService("ChangeHistoryService")
assert(game:GetService("RunService"):IsEdit(), "Remove authored scratches: run this in Edit mode, not during Play")
local Templates = Replicatedstorage.Asset.Object

local Recorded, Recording = pcall(Changehistoryservice.TryBeginRecording, Changehistoryservice, "RemoveAuthoredScratches", "Remove authored scratches")
local Removed = 0
for _, Descendant in ipairs(Templates:GetDescendants()) do
	if Descendant:IsA("GuiObject") and Descendant.Name == "ScratchesFrame" and Descendant:GetAttribute("Generated") ~= true then
		print("Removed " .. Descendant:GetFullName())
		Descendant:Destroy()
		Removed += 1
	end
end
if Recorded and Recording then
	Changehistoryservice:FinishRecording(Recording, Enum.FinishRecordingOperation.Commit)
end
print(string.format("Remove authored scratches: %d removed (Ctrl+Z to undo)", Removed))
