local Players = game:GetService("Players")

local BoostController = {
	Name = "BoostController",
	Priority = 2,
}

local function FormatTime(Seconds: number): string
	local Total = math.max(math.ceil(Seconds), 0)
	return string.format("%d:%02d", math.floor(Total / 60), Total % 60)
end

function BoostController:RemoveBoost(Name: string)
	local Boost = self.boosts[Name]
	if not Boost then return end
	Boost.Frame:Destroy()
	self.boosts[Name] = nil
end

function BoostController:SetBoost(Name: string, Icon: string, EndsAt: number, LayoutOrder: number)
	if EndsAt <= workspace:GetServerTimeNow() then
		self:RemoveBoost(Name)
		return
	end

	local Boost = self.boosts[Name]
	if not Boost then
		local Frame = self.template:Clone() :: ImageLabel
		Frame.Name = Name
		Frame.Parent = self.frame
		Boost = {
			Frame = Frame,
			Text = Frame:WaitForChild("Text") :: TextLabel,
			EndsAt = EndsAt,
		}
		self.boosts[Name] = Boost
	end

	Boost.Frame.Image = Icon
	Boost.Frame.LayoutOrder = LayoutOrder
	Boost.Frame.Visible = true
	Boost.EndsAt = EndsAt
	Boost.Text.Text = FormatTime(EndsAt - workspace:GetServerTimeNow())
end

function BoostController:Update()
	local CurrentTime = workspace:GetServerTimeNow()
	for Name, Boost in pairs(self.boosts) do
		local Remaining = Boost.EndsAt - CurrentTime
		if Remaining <= 0 then
			self:RemoveBoost(Name)
		else
			Boost.Text.Text = FormatTime(Remaining)
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
