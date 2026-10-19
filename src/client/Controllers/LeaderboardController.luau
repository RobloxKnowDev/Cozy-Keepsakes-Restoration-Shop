local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Userinputservice = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Icon = require(Replicatedstorage.Shared:WaitForChild("Utils"):WaitForChild("Icon"))

local Leaderboardcontroller = {
	Name = "LeaderboardController",
	Priority = 8.7,
	topbarImage = "rbxassetid://139860496927961",
}

local Cameras = { "CamRobux", "CamSold", "CamReputation" }
local Boards = { "Robux", "Sold", "Reputation" }
local Stickdeadzone = 0.2
local Windowspersecond = 1.2

function Leaderboardcontroller:GetList(Index: number): ScrollingFrame
	local Leaderboards = Workspace:WaitForChild("Map"):WaitForChild("Leaderboards")
	return Leaderboards:WaitForChild(Boards[Index]):WaitForChild("SurfaceGui"):WaitForChild("ScrollingFrame") :: ScrollingFrame
end

function Leaderboardcontroller:Scroll(Deltatime: number)
	local Direction = (if Userinputservice:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.DPadDown) then 1 else 0)
		- (if Userinputservice:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.DPadUp) then 1 else 0)
	if math.abs(self.stick) > Stickdeadzone then
		Direction -= math.sign(self.stick) * (math.abs(self.stick) - Stickdeadzone) / (1 - Stickdeadzone)
	end
	if Direction == 0 then
		return
	end
	local List = self:GetList(self.cameraIndex)
	local Window = List.AbsoluteWindowSize.Y
	local Maximum = math.max(List.AbsoluteCanvasSize.Y - Window, 0)
	local Next = math.clamp(List.CanvasPosition.Y + Direction * Window * Windowspersecond * Deltatime, 0, Maximum)
	List.CanvasPosition = Vector2.new(List.CanvasPosition.X, Next)
end

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
	self.stick = 0
	Userinputservice.InputChanged:Connect(function(Input)
		if Input.KeyCode == Enum.KeyCode.Thumbstick2 then
			self.stick = Input.Position.Y
		end
	end)
	Runservice.RenderStepped:Connect(function(Deltatime)
		if self:IsOpen() then
			self:Scroll(Deltatime)
		end
	end)
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
