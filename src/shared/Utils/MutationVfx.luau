local Collectionservice = game:GetService("CollectionService")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Mutationconfig = require(Replicatedstorage.Shared.Config.Mutation)

local MutationVfx = {}

local function Getanchorpart(Object: Instance): BasePart
	if Object:IsA("BasePart") then
		return Object
	end
	return (Object :: Model).PrimaryPart or Object:FindFirstChildWhichIsA("BasePart", true)
end

function MutationVfx.Attach(Object: Instance, Mutation: string, Withlight: boolean)
	if Mutation == "Normal" then
		return
	end
	local Attachment = Replicatedstorage:WaitForChild("Asset"):WaitForChild("Vfx"):WaitForChild(Mutation):Clone() :: Attachment
	Attachment.Name = Mutationconfig.VfxName
	if not Withlight then
		Attachment.Light:Destroy()
	end
	if Mutation == "Rainbow" then
		Collectionservice:AddTag(Attachment, Mutationconfig.RainbowTag)
	end
	Attachment.Parent = Getanchorpart(Object)
end

return MutationVfx
