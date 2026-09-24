local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostConfig = require(ReplicatedStorage.Shared.Config.Boosts)
local FormatDuration = require(ReplicatedStorage.Shared.Utils.DurationFormatter)

local BoostController = {
	Name = "BoostController",
	Priority = 2,
}

function BoostController:RemoveBoost(Name: string)
	local Boost = self.boosts[Name]
	if not Boost then return end
	Boost.Frame:Destroy()
	self.boosts[Name] = nil
end

function BoostController:SetBoost(Name: string, EndsAt: number, LayoutOrder: number, Multiplier: number?)
	if EndsAt <= workspace:GetServerTimeNow() then
		self:RemoveBoost(Name)
		return
	end

	local Info = BoostConfig[Name]
	local Boost = self.boosts[Name]
	if not Boost then
		local Frame = self.template:Clone() :: ImageLabel
		local Tooltip = Frame:WaitForChild("Frame") :: Frame
		local BaseZIndex = Frame.ZIndex
		local DescriptionText = Tooltip:WaitForChild("DescriptionText") :: TextLabel
		DescriptionText.Text = Info.Description
		Tooltip.Visible = false
		Frame.Name = Name
		Frame.Parent = self.frame
		Boost = {
			Frame = Frame,
			Text = Frame:WaitForChild("Text") :: TextLabel,
			NameText = Tooltip:WaitForChild("NameText") :: TextLabel,
			EndsAt = EndsAt,
		}
		self.boosts[Name] = Boost

		Frame.MouseEnter:Connect(function()
			Frame.ZIndex = BaseZIndex + 1
			Tooltip.Visible = true
		end)
		Frame.MouseLeave:Connect(function()
			Frame.ZIndex = BaseZIndex
			Tooltip.Visible = false
		end)
	end

	Boost.NameText.Text = if Multiplier then string.format("%s x%d", Info.Title, Multiplier) else Info.Title
	Boost.Frame.Image = Info.Icon
	Boost.Frame.LayoutOrder = LayoutOrder
	Boost.Frame.Visible = true
	Boost.EndsAt = EndsAt
	Boost.Text.Text = FormatDuration(EndsAt - workspace:GetServerTimeNow())
end

function BoostController:Update()
	local CurrentTime = workspace:GetServerTimeNow()
	for Name, Boost in pairs(self.boosts) do
		local Remaining = Boost.EndsAt - CurrentTime
		if Remaining <= 0 then
			self:RemoveBoost(Name)
		else
			Boost.Text.Text = FormatDuration(Remaining)
		end
	end
end

function BoostController:Init()
	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.frame = PlayerGui:WaitForChild("HUD"):WaitForChild("BoostFrame")
	self.template = self.frame:WaitForChild("Template") :: ImageLabel
	self.boosts = {}
	self.frame.Visible = true
	self.template.Visible = false
end

function BoostController:Start()
	task.spawn(function()
		while true do
			self:Update()
			task.wait(1)
		end
	end)
end

return BoostController
