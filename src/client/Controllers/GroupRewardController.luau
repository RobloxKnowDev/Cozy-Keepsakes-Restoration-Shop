local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Icon = require(ReplicatedStorage.Shared:WaitForChild("Utils"):WaitForChild("Icon"))

local GroupRewardController = {
	Name = "GroupRewardController",
	Priority = 8.55,
	topbarImage = "rbxassetid://107150542972325",
}

local ComingSoonText = "Group Rewards are coming soon!"
local WhiteGradient = ColorSequence.new(Color3.fromRGB(255, 255, 255))

function GroupRewardController:Init()
	self.topbarIcon = Icon.new()
		:setName("GroupRewards")
		:setImage(self.topbarImage)
		:modifyTheme({ "IconImage", "ImageColor3", Color3.fromRGB(255, 255, 255) })
		:modifyTheme({ "IconImage", "ScaleType", Enum.ScaleType.Fit })
		:setCaption("Group Rewards")
		:oneClick()
		:autoDeselect(false)
	self.topbarIcon.selected:Connect(function()
		Core:GetController("MessageController"):Show(ComingSoonText, WhiteGradient)
	end)
end

return GroupRewardController
