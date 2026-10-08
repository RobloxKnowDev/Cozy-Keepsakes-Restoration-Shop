local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Icon = require(Replicatedstorage.Shared:WaitForChild("Utils"):WaitForChild("Icon"))

local Leaderboardcontroller = {
	Name = "LeaderboardController",
	Priority = 8.7,
	topbarImage = "rbxassetid://139860496927961",
}

local Cameras = { "CamRobux", "CamSold", "CamReputation" }

function Leaderboardcontroller:IsOpen(): boolean
	return self.isOpen == true
end

function Leaderboardcontroller:CanOpen(): boolean
	return not self:IsOpen()
		and not Core:GetController("TutorialController").running
		and not Core:GetController("RestorationController"):IsEditingObject()
		and not Core:GetController("ComputerController"):IsOpen()
		and not Core:GetController("CustomerController"):IsVisible()
		and not Core:GetController("CompletionController"):IsVisible()
end

function Leaderboardcontroller:Open()
	if not self:CanOpen() then
		self.topbarIcon:deselect()
		return
	end
	local Expositioncontroller = Core:GetController("ExpositionController")
	if Expositioncontroller:IsOpen() then Expositioncontroller:Close() end
	if Expositioncontroller:IsOpen() or not Core:GetController("InspectionCameraController"):ShowLeaderboardCamera(Cameras[1]) then
		self.topbarIcon:deselect()
		return
	end
	self.cameraIndex = 1
	self.isOpen = true
	Expositioncontroller:SetLeaderboardMode(true)
end

function Leaderboardcontroller:Step(Direction: number)
	if not self:IsOpen() then return end
	self.cameraIndex = (self.cameraIndex - 1 + Direction) % #Cameras + 1
	Core:GetController("InspectionCameraController"):ShowLeaderboardCamera(Cameras[self.cameraIndex])
end

function Leaderboardcontroller:Close()
	if not self:IsOpen() then return end
	self.isOpen = false
	Core:GetController("ExpositionController"):SetLeaderboardMode(false)
	Core:GetController("InspectionCameraController"):ShowIntroCamera()
end

function Leaderboardcontroller:CloseForSwitch()
	self:Close()
	self.topbarIcon:deselect()
end

function Leaderboardcontroller:Init()
	self.isOpen = false
	self.cameraIndex = 1
	self.topbarIcon = Icon.new()
		:setName("Leaderboards")
		:setImage(self.topbarImage)
		:modifyTheme({ "IconImage", "ImageColor3", Color3.fromRGB(255, 255, 255) })
		:modifyTheme({ "IconImage", "ScaleType", Enum.ScaleType.Fit })
		:setCaption("Leaderboards")
	self.topbarIcon.selected:Connect(function() self:Open() end)
	self.topbarIcon.deselected:Connect(function() self:Close() end)
	Core:GetController("GamepadController"):RegisterMenu({
		Priority = 15,
		IsOpen = function()
			return self:IsOpen()
		end,
		Close = function()
			self.topbarIcon:deselect()
		end,
	})
end

return Leaderboardcontroller
