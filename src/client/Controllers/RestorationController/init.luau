local Guiservice = game:GetService("GuiService")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Userinputservice = game:GetService("UserInputService")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)
local Interfacemodule = require(script.Runtime.Interface)
local Toolruntime = require(script.Runtime.ToolRuntime)

local Tools = {}
for _, Module in ipairs(script:GetChildren()) do
	if Module:IsA("ModuleScript") then
		local Tool = require(Module)
		Tools[Tool.Name] = Tool
	end
end

local Controller = { Name = "RestorationController", Priority = 1 }
local Interface = Interfacemodule.new(Tools)
local Runtime = Toolruntime.new(Tools, Interface)
local Activeobject: (Model | BasePart)? = nil

local function Showcompletion()
	local Completion = Core:GetController("CompletionController")
	if Completion:IsVisible() or not Activeobject then return end
	Runtime:Destroy()
	Core:GetController("InspectionCameraController"):PrepareCompletion()
	Interface:HideForCompletion()
	Completion:Show(Activeobject, function()
		Remotemanager:FireServer("RestorationService", "SessionEnded")
		Core:GetController("InspectionCameraController"):End()
		Activeobject = nil
		Runtime:SetObject(nil)
		Interface.Gui.Enabled = false
		Completion:Hide()
	end)
end

local function Updateprogress()
	if Activeobject and Core:GetController("ProgressController"):Update(Activeobject) then
		Showcompletion()
	end
end

function Controller:SelectTool(Name: string)
	Runtime:Select(Name)
end

function Controller:Enter()
	if Activeobject then return end
	local Object = Remotemanager:InvokeServer("RestorationService", "BeginSession")
	if not Object or (not Object:IsA("BasePart") and not Object:IsA("Model")) then return end
	Activeobject = Object
	Runtime:SetObject(Object)
	Core:GetController("CompletionController"):Hide()
	Core:GetController("InspectionCameraController"):Begin(Object)
	Interface.Gui.Enabled = true
	Interface.ProgressText.Visible = true
	Userinputservice.MouseBehavior = Enum.MouseBehavior.Default
	Updateprogress()
	Runtime:Select("Transform")
end

function Controller:Start()
	local Cameracontroller = Core:GetController("InspectionCameraController")
	Interface:Start(
		function(Name) Runtime:Select(Name) end,
		function(Mode) Cameracontroller:SetTransformMode(Mode) end,
		function() Cameracontroller:FlipObject() end
	)
	Cameracontroller:SetTransformMode("Rotate")
	Userinputservice.MouseIconEnabled = true

	Userinputservice.InputBegan:Connect(function(Input, Processed)
		if Processed or not Activeobject or Core:GetController("CompletionController"):IsVisible() then return end
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then Runtime:InputBegan() end
	end)
	Userinputservice.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then Runtime:InputEnded() end
	end)
	Runservice.RenderStepped:Connect(function(Deltatime)
		local Mouse = Userinputservice:GetMouseLocation()
		if not Interface.Hud.IgnoreGuiInset then Mouse -= Guiservice:GetGuiInset() end
		Interface.Cursor.Position = UDim2.fromOffset(Mouse.X, Mouse.Y)
		if not Activeobject or Core:GetController("CompletionController"):IsVisible() then return end
		Runtime:Update(Deltatime)
		Updateprogress()
	end)

	task.defer(function() Controller:Enter() end)
end

return Controller
