local Collectionservice = game:GetService("CollectionService")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Mutationconfig = require(Replicatedstorage.Shared.Config.Mutation)

local MutationVfx = {}

function MutationVfx.Attach(Object: Instance, Mutation: string)
	if Mutation == "Normal" then
		return
	end
	local Attachment = Replicatedstorage:WaitForChild("Asset"):WaitForChild("Vfx"):WaitForChild(Mutation):Clone() :: Attachment
	Attachment.Name = Mutationconfig.VfxName
	if Mutation == "Rainbow" then
		Collectionservice:AddTag(Attachment, Mutationconfig.RainbowTag)
	end
	local Base = Object:WaitForChild("Base") :: BasePart
	Attachment.Position = Base.CFrame:PointToObjectSpace((Object :: Model):GetBoundingBox().Position)
	Attachment.Parent = Base
end

return MutationVfx
