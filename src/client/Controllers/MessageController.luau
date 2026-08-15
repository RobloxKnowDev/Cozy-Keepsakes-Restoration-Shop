local Players = game:GetService("Players")
local Tweenservice = game:GetService("TweenService")

local Messagecontroller = {
	Name = "MessageController",
	Priority = 1,
}

local Messagetweeninfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Messagelifetime = 3

local function FindMessageFrame(Root: Instance): Frame
	local MessageFrame = Root:FindFirstChild("Message", true)
	assert(MessageFrame and MessageFrame:IsA("Frame"), "Frame 'Message' introuvable dans PlayerGui")
	return MessageFrame
end

function Messagecontroller:Show(Text: string, Color: Color3?)
	if not self.template then
		return
	end

	self.messageId += 1
	local Currentmessageid = self.messageId
	local Label = self.template:Clone()
	Label.Name = "Message_" .. tostring(Currentmessageid)
	Label.Visible = true
	Label.Text = tostring(Text)
	Label.TextTransparency = 1
	Label.TextColor3 = Color or self.baseTextColor
	Label.Parent = self.frame

	Tweenservice:Create(Label, Messagetweeninfo, {
		TextTransparency = 0,
	}):Play()

	task.delay(Messagelifetime, function()
		if not Label.Parent then
			return
		end

		local Fadetween = Tweenservice:Create(Label, Messagetweeninfo, {
			TextTransparency = 1,
		})
		Fadetween:Play()
		Fadetween.Completed:Once(function()
			if Label.Parent then
				Label:Destroy()
			end
		end)
	end)
end

function Messagecontroller:Init()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.frame = FindMessageFrame(Playergui)
	self.template = self.frame:FindFirstChild("Template")
	assert(self.template and self.template:IsA("TextLabel"), "TextLabel 'Template' introuvable dans Message")

	self.baseTextColor = self.template.TextColor3
	self.messageId = 0
	self.template.Visible = false
end

return Messagecontroller
