local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Icon = require(ReplicatedStorage.Shared:WaitForChild("Utils"):WaitForChild("Icon"))

local TopbarController = {
	Name = "TopbarController",
	Priority = 9.5,
	topbarImage = "rbxassetid://128057992621993",
}

function TopbarController:Init()
	Icon.highlightKey = false
	self.isPhone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if not self.isPhone then
		return
	end
	self.menuIcon = Icon.new()
		:setName("Menu")
		:setImage(self.topbarImage)
		:modifyTheme({ "IconImage", "ImageColor3", Color3.fromRGB(255, 255, 255) })
		:modifyTheme({ "IconImage", "ScaleType", Enum.ScaleType.Fit })
		:setCaption("Menu")
	self.menuIcon.toggled:Connect(function(IsSelected: boolean)
		self.menuIcon:modifyTheme({
			{ "IconImage", "Image", if IsSelected then "" else self.topbarImage, "Viewing" },
			{ "IconLabel", "Text", if IsSelected then "X" else "", "Viewing" },
		})
	end)
end

function TopbarController:Start()
	if not self.isPhone then
		return
	end
	self.menuIcon:setMenu({
		Core:GetController("DonationController").topbarIcon,
		Core:GetController("DailyRewardController").topbarIcon,
		Core:GetController("GroupRewardController").topbarIcon,
		Core:GetController("SettingController").topbarIcon,
	})
end

return TopbarController
