local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Workspace = game:GetService("Workspace")

local Core = require(ReplicatedStorage.Shared.Packages.Core)
local Config = require(ReplicatedStorage.Shared.Config.Event)
local Lessonsconfig = require(ReplicatedStorage.Shared.Config.Lessons)
local Icon = require(ReplicatedStorage.Shared:WaitForChild("Utils"):WaitForChild("Icon"))
local Shared = require(script.Parent.ComputerController.Apps.Shared)

local EventController = {
	Name = "EventController",
	Priority = 8.65,
}

function EventController:CanPopup(): boolean
	return self.status ~= Enum.RsvpStatus.Going
		and not self.prompting
		and Lessonsconfig.LearnedAll(Players.LocalPlayer:GetAttribute("Lessons"))
		and not Core:GetController("CustomerController"):IsStartingItem()
		and not Core:GetController("TutorialController").running
		and not Core:GetController("GroupRewardController"):IsOpen()
		and Core:GetController("GamepadController"):IsIdle()
		and Core:GetController("InspectionCameraController"):IsIntroCameraReady()
end

function EventController:SetStatus(Status: Enum.RsvpStatus?)
	self.status = Status
	Shared.SetTopbarNotice(self.topbarIcon, Status ~= Enum.RsvpStatus.Going)
end

function EventController:Prompt()
	if self.prompting then
		return
	end
	self.prompting = true
	local Success, Status = pcall(SocialService.PromptRsvpToEventAsync, SocialService, Config.EventId)
	self.prompting = false
	if Success then
		self:SetStatus(Status)
	end
end

function EventController:Start()
	if Workspace:GetServerTimeNow() >= Config.StartsAt then
		return
	end
	self.prompting = false
	self.topbarIcon = Icon.new()
		:setName("Event")
		:setLabel("New Update")
		:setCaption("Get Notified")
		:align("Right")
		:oneClick(true)
		:autoDeselect(false)
	self.topbarIcon.selected:Connect(function()
		task.spawn(self.Prompt, self)
	end)
	task.spawn(function()
		local Success, Status = pcall(SocialService.GetEventRsvpStatusAsync, SocialService, Config.EventId)
		self:SetStatus(if Success then Status else nil)
		local PopupAt = os.clock() + Config.PopupSeconds
		while Workspace:GetServerTimeNow() < Config.StartsAt do
			if PopupAt and os.clock() >= PopupAt and self:CanPopup() then
				PopupAt = nil
				task.spawn(self.Prompt, self)
			end
			task.wait(1)
		end
		Shared.SetTopbarNotice(self.topbarIcon, false)
		self.topbarIcon:destroy()
	end)
end

return EventController
