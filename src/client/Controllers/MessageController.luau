local Players = game:GetService("Players")
local Tweenservice = game:GetService("TweenService")

local Messagecontroller = {
	Name = "MessageController",
	Priority = 1,
}

local Messagetweeninfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Messagelifetime = 3

function Messagecontroller:Show(Text: string, Color: Color3?)
	if not self.template then
		return
	end

	self.messageId += 1
	local Currentmessageid = self.messageId
	local Label = self.template:Clone()
	local Stroke = Label:WaitForChild("UIStroke") :: UIStroke
	Label.Name = "Message_" .. tostring(Currentmessageid)
	Label.Visible = true
	Label.Text = tostring(Text)
	Label.TextTransparency = 1
	Label.TextColor3 = Color or self.baseTextColor
	Stroke.Transparency = 1
	Label.Parent = self.frame

	Tweenservice:Create(Label, Messagetweeninfo, {
		TextTransparency = 0,
	}):Play()
	Tweenservice:Create(Stroke, Messagetweeninfo, {
		Transparency = self.baseStrokeTransparency,
	}):Play()

	task.delay(Messagelifetime, function()
		if not Label.Parent then
			return
		end

		local Fadetween = Tweenservice:Create(Label, Messagetweeninfo, {
			TextTransparency = 1,
		})
		Fadetween:Play()
		Tweenservice:Create(Stroke, Messagetweeninfo, {
			Transparency = 1,
		}):Play()
		Fadetween.Completed:Once(function()
			if Label.Parent then
				Label:Destroy()
			end
		end)
	end)
end

function Messagecontroller:Init()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.frame = Playergui:WaitForChild("HUD"):WaitForChild("Message")
	self.template = self.frame:WaitForChild("Template")

	self.baseTextColor = self.template.TextColor3
	self.baseStrokeTransparency = self.template:WaitForChild("UIStroke").Transparency
	self.messageId = 0
	self.template.Visible = false
end

return Messagecontroller
