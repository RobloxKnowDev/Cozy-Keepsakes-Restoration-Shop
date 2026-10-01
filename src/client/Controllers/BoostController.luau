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

function BoostController:CreateBoost(Name: string)
	local Frame = self.template:Clone() :: ImageLabel
	local Tooltip = Frame:WaitForChild("Frame") :: Frame
	local BaseZIndex = Frame.ZIndex
	Tooltip.Visible = false
	Frame.Name = Name
	Frame.Image = BoostConfig[Name].Icon
	Frame.Visible = true
	Frame.Parent = self.frame
	local Boost = {
		Frame = Frame,
		Text = Frame:WaitForChild("Text") :: TextLabel,
		NameText = Tooltip:WaitForChild("NameText") :: TextLabel,
		DescriptionText = Tooltip:WaitForChild("DescriptionText") :: TextLabel,
		EndsAt = 0,
		Permanent = false,
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
	return Boost
end

function BoostController:SetBoost(Name: string, EndsAt: number, LayoutOrder: number, Multiplier: number?, Description: string?)
	if EndsAt <= workspace:GetServerTimeNow() then
		self:RemoveBoost(Name)
		return
	end

	local Info = BoostConfig[Name]
	local Boost = self.boosts[Name] or self:CreateBoost(Name)
	Boost.NameText.Text = if Multiplier then string.format("%s x%d", Info.Title, Multiplier) else Info.Title
	Boost.DescriptionText.Text = Description or Info.Description
	Boost.Frame.LayoutOrder = LayoutOrder
	Boost.EndsAt = EndsAt
	Boost.Text.Text = FormatDuration(EndsAt - workspace:GetServerTimeNow())
end

function BoostController:SetPermanentBoost(Name: string, LayoutOrder: number, Text: string, Description: string)
	local Boost = self.boosts[Name] or self:CreateBoost(Name)
	Boost.Permanent = true
	Boost.NameText.Text = BoostConfig[Name].Title
	Boost.DescriptionText.Text = Description
	Boost.Frame.LayoutOrder = LayoutOrder
	Boost.Text.Text = Text
end

function BoostController:Update()
	local CurrentTime = workspace:GetServerTimeNow()
	for Name, Boost in pairs(self.boosts) do
		if not Boost.Permanent then
			local Remaining = Boost.EndsAt - CurrentTime
			if Remaining <= 0 then
				self:RemoveBoost(Name)
			else
				Boost.Text.Text = FormatDuration(Remaining)
			end
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
