local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local BoostConfig = require(ReplicatedStorage.Shared.Config.Boosts)
local ObjectConfig = require(ReplicatedStorage.Shared.Config.Object)

local LoadingController = {
	Name = "LoadingController",
	Priority = 100,
}

local ReadyTimeout = 8
local SecondaryGuis = { "PackageUi", "ExpositionUi", "DailyRewardUi", "CompleteUi", "SettingUi", "DonationUi", "TutorialUi" }

local function AddImage(List: { Instance }, Object: Instance)
	if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then
		table.insert(List, Object)
	end
end

local function AddImages(List: { Instance }, Root: Instance)
	AddImage(List, Root)
	for _, Descendant in ipairs(Root:GetDescendants()) do
		AddImage(List, Descendant)
	end
end

local function AddImageId(List: { Instance }, Id: string)
	local Image = Instance.new("ImageLabel")
	Image.Image = Id
	table.insert(List, Image)
end

function LoadingController:Init()
	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local Computer = Core:GetController("ComputerController")
	local Essential = {}
	AddImages(Essential, PlayerGui:WaitForChild("HUD"))
	AddImages(Essential, PlayerGui:WaitForChild("CustomerUi"))
	AddImage(Essential, Computer.frame)
	AddImages(Essential, Computer.header)
	AddImages(Essential, Computer.LeftFrame)
	AddImages(Essential, Computer.homePage)
	for _, Boost in pairs(BoostConfig) do
		AddImageId(Essential, Boost.Icon)
	end
	AddImageId(Essential, Core:GetController("TopbarController").topbarImage)
	AddImageId(Essential, Core:GetController("SettingController").topbarImage)
	AddImageId(Essential, Core:GetController("DailyRewardController").topbarImage)
	AddImageId(Essential, Core:GetController("GroupRewardController").topbarImage)
	AddImageId(Essential, ObjectConfig.Object[ObjectConfig.Offer.TutorialObject].IdImage)
	self.essentialLoaded = false
	self.cameraReady = false
	task.spawn(function()
		ContentProvider:PreloadAsync(Essential)
		self.essentialLoaded = true
	end)
	task.spawn(function()
		local CameraController = Core:GetController("InspectionCameraController")
		while not CameraController:IsIntroCameraReady() do
			task.wait()
		end
		self.cameraReady = true
	end)
end

function LoadingController:Start()
	task.spawn(function()
		local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		local Gui = PlayerGui:WaitForChild("LoadingUi")
		local Deadline = os.clock() + ReadyTimeout
		while not (self.essentialLoaded and self.cameraReady) and os.clock() < Deadline do
			task.wait()
		end
		Gui:SetAttribute("Ready", true)
		local Secondary = {}
		for _, Name in ipairs(SecondaryGuis) do
			AddImages(Secondary, PlayerGui:WaitForChild(Name))
		end
		AddImages(Secondary, Core:GetController("ComputerController").pages)
		for _, Definition in pairs(ObjectConfig.Object) do
			AddImageId(Secondary, Definition.IdImage)
		end
		AddImageId(Secondary, Core:GetController("FeedbackController").purchaseRaysImage)
		ContentProvider:PreloadAsync(Secondary)
	end)
end

return LoadingController
