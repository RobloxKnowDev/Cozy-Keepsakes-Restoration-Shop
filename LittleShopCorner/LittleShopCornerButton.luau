local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local GROUP_ID = 670922202
local houseName = "Little Shop Corner"
local HousePrice = 0

local button = script.Parent
local label = button:WaitForChild("TextLabel")
local player = Players.LocalPlayer
local ownedFolder = player:WaitForChild("OwnedHouses")

local buyEvent = ReplicatedStorage:WaitForChild("BuyHouseEvent")
local CameraEvent = ReplicatedStorage:WaitForChild("CameraEvent")
local HouseLoadEvent = ReplicatedStorage:WaitForChild("HouseLoadEvent")
local NotifEvent = ReplicatedStorage:WaitForChild("NotifsFolder"):WaitForChild("NotifEvent")
local FrameOpenEvent = ReplicatedStorage:WaitForChild("SlotsFolder"):WaitForChild("OpenSlotsFrame")
local TweenModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIS"):WaitForChild("DownBarModules"):WaitForChild("TweensBar"))

local UISounds = SoundService:WaitForChild("UISounds")
local UIOpen = UISounds:WaitForChild("UIOpen")
local BuySound = UISounds:WaitForChild("BuySound")

local gameGui = button.Parent.Parent.Parent.Parent
local template = gameGui:WaitForChild("AppartmentsTemplates")
local visual = template:WaitForChild("LittleCornerShopVisual")
local loadingText = gameGui:WaitForChild("LoadingFrame"):WaitForChild("Text")

local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local blurInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local loadConnection

local function updateButton()
	if ownedFolder:FindFirstChild(houseName) then
		button.BackgroundColor3 = Color3.new(0.227451, 0.368627, 1)
		label.Text = "SPAWN"
	else
		button.BackgroundColor3 = Color3.new(0.517647, 0.780392, 0.286275)
		label.Text = "BUY"
	end
end

local function onHouseLoaded()
	CameraEvent:Fire("deactivate")
	TweenService:Create(loadingText, fadeInfo, { TextTransparency = 1 }):Play()

	local blur = Lighting:FindFirstChildOfClass("BlurEffect")
	if blur then
		TweenService:Create(blur, blurInfo, { Size = 0 }):Play()
	end

	gameGui.Enabled = false

	task.wait(1)
	UIOpen:Play()
	TweenModule.FrameOpen(player.PlayerGui:WaitForChild("FurnituresGui"):WaitForChild("ButtonsFrame"))
end

button.MouseButton1Click:Connect(function()
	if not player:IsInGroup(GROUP_ID) then
		NotifEvent:Fire("You are not in the game group!", Color3.new(0.815686, 0.176471, 0.188235), 137422160229322)
		return
	end

	if ownedFolder:FindFirstChild(houseName) then
		FrameOpenEvent:Fire(houseName, template, button.Parent)
		TweenService:Create(visual, tweenInfo, { Size = UDim2.new() }):Play()
		task.wait(0.5)
		visual.Visible = false

		if loadConnection then
			loadConnection:Disconnect()
		end
		loadConnection = HouseLoadEvent.OnClientEvent:Once(onHouseLoaded)
	else
		buyEvent:FireServer(houseName, HousePrice)
		BuySound:Play()
	end
end)

ownedFolder.ChildAdded:Connect(updateButton)

updateButton()
