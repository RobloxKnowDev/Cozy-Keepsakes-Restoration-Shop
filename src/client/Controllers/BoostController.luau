local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoostConfig = require(ReplicatedStorage.Shared.Config.Boosts)
local Core = require(ReplicatedStorage.Shared.Packages.Core)
local FormatDuration = require(ReplicatedStorage.Shared.Utils.DurationFormatter)
local Translation = require(ReplicatedStorage.Shared.Utils.Translation)

local BoostController = {
	Name = "BoostController",
	Priority = 2,
}

local AppearWindow = 0.5

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
		CreatedAt = os.clock(),
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

function BoostController:SetBoost(Name: string, EndsAt: number, LayoutOrder: number, Multiplier: number?, Description: string?, ...: any)
	if EndsAt <= workspace:GetServerTimeNow() then
		self:RemoveBoost(Name)
		return
	end

	local Info = BoostConfig[Name]
	local Boost = self.boosts[Name] or self:CreateBoost(Name)
	if Multiplier then
		Translation.Raw(Boost.NameText, string.format("%s x%d", Translation.Format(Info.Title), Multiplier))
	else
		Translation.Set(Boost.NameText, Info.Title)
	end
	Translation.Set(Boost.DescriptionText, Description or Info.Description, ...)
	Boost.Frame.LayoutOrder = LayoutOrder
	Boost.EndsAt = EndsAt
	Translation.Raw(Boost.Text, FormatDuration(EndsAt - workspace:GetServerTimeNow()))
end

function BoostController:SetPermanentBoost(Name: string, LayoutOrder: number, Text: string, Description: string, ...: any)
	local Boost = self.boosts[Name] or self:CreateBoost(Name)
	Boost.Permanent = true
	Translation.Set(Boost.NameText, BoostConfig[Name].Title)
	Translation.Set(Boost.DescriptionText, Description, ...)
	Boost.Frame.LayoutOrder = LayoutOrder
	Translation.Raw(Boost.Text, Text)
end

function BoostController:PlayGain(Name: string, WithMessage: boolean)
	local Boost = self.boosts[Name]
	if not Boost then return end
	local Gradient = BoostConfig[Name].Gradient
	local Title = if Boost.Permanent then Boost.NameText.Text .. " " .. Boost.Text.Text else Boost.NameText.Text
	Core:GetController("FeedbackController"):BoostGain(Boost.Frame, Title .. "!", Gradient, os.clock() - Boost.CreatedAt < AppearWindow)
	if WithMessage then
		Core:GetController("MessageController"):Show("{1}: {2}", Gradient, Boost.NameText.Text, Boost.DescriptionText.Text)
	end
end

function BoostController:Update()
	local CurrentTime = workspace:GetServerTimeNow()
	for Name, Boost in pairs(self.boosts) do
		if not Boost.Permanent then
			local Remaining = Boost.EndsAt - CurrentTime
			if Remaining <= 0 then
				self:RemoveBoost(Name)
			else
				Translation.Raw(Boost.Text, FormatDuration(Remaining))
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
