local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Runservice = game:GetService("RunService")
local Tweenservice = game:GetService("TweenService")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)
local Abbreviatenumber = require(Replicatedstorage.Shared.Utils.NumberAbbreviator)

local Cashcontroller = {
	Name = "CashController",
	Priority = 6,
}

local Countduration = 0.65
local Pulseinfo = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Gaincolor = Color3.fromRGB(126, 255, 145)
local Losscolor = Color3.fromRGB(255, 138, 138)

local function EnsureScale(Target: Instance): UIScale
	local Existing = Target:FindFirstChildOfClass("UIScale")
	if Existing then
		return Existing
	end

	local Scale = Instance.new("UIScale")
	Scale.Parent = Target
	return Scale
end

function Cashcontroller:SetDisplayedCash(Value: number)
	self.displayedCash = Value
	self.cashText.Text = "$" .. Abbreviatenumber(Value)
end

function Cashcontroller:AnimateCashTo(TargetValue: number)
	local Startvalue = self.displayedCash or TargetValue
	local Delta = TargetValue - Startvalue
	if math.abs(Delta) < 0.005 then
		self:SetDisplayedCash(TargetValue)
		return
	end

	self.animationId += 1
	local Animationid = self.animationId
	local Starttime = os.clock()
	local Targetcolor = Delta > 0 and Gaincolor or Losscolor
	if Delta > 0 then
		self.feedback:FloatingText(self.cashFrame, "+$" .. Abbreviatenumber(math.abs(Delta)), Targetcolor)
		self.feedback:Burst(self.cashFrame, Gaincolor, math.clamp(math.floor(math.log10(math.abs(Delta) + 1) * 3), 4, 12))
		self.feedback:PlaySound("CashGain", 0.12, 1 + math.clamp(math.log10(math.abs(Delta) + 1) * 0.025, 0, 0.12))
	end

	Tweenservice:Create(self.cashScale, Pulseinfo, {
		Scale = 1.08,
	}):Play()
	Tweenservice:Create(self.cashText, Pulseinfo, {
		TextColor3 = Targetcolor,
	}):Play()

	local Connection
	Connection = Runservice.RenderStepped:Connect(function()
		if self.animationId ~= Animationid then
			Connection:Disconnect()
			return
		end

		local Alpha = math.clamp((os.clock() - Starttime) / Countduration, 0, 1)
		local Eased = Tweenservice:GetValue(Alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		self:SetDisplayedCash(Startvalue + Delta * Eased)

		if Alpha >= 1 then
			Connection:Disconnect()
			self:SetDisplayedCash(TargetValue)
			Tweenservice:Create(self.cashScale, Pulseinfo, {
				Scale = 1,
			}):Play()
			Tweenservice:Create(self.cashText, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextColor3 = self.baseTextColor,
			}):Play()
		end
	end)
end

function Cashcontroller:Init()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local Hud = Playergui:WaitForChild("HUD")
	self.cashFrame = Hud:WaitForChild("CashFrame")
	self.cashText = self.cashFrame:WaitForChild("CashText")
	self.cashScale = EnsureScale(self.cashText)
	self.baseTextColor = self.cashText.TextColor3
	self.displayedCash = 0
	self.animationId = 0
end

function Cashcontroller:Start()
	self.feedback = Core:GetController("FeedbackController")
	self:SetDisplayedCash(Remotemanager:InvokeServer("CashService", "GetCash"))
	Remotemanager:OnClientEvent("CashService", "CashUpdated", function(Value)
		self:AnimateCashTo(Value)
	end)
end

return Cashcontroller
