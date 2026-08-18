local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local MonetizationConfig = require(ReplicatedStorage.Shared.Config.Monetization)

local VIPChatController = {
	Name = "VIPChatController",
	Priority = 20,
}

function VIPChatController:Start()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then return end
	TextChatService.OnIncomingMessage = function(Message)
		local Source = Message.TextSource
		if not Source then return nil end
		local Player = Players:GetPlayerByUserId(Source.UserId)
		if not Player or Player:GetAttribute("OwnsVIP") ~= true then return nil end
		local Properties = Instance.new("TextChatMessageProperties")
		Properties.PrefixText = string.format("<font color='#FFD66B'>%s</font> %s", tostring(MonetizationConfig.VIP.ChatTag), tostring(Message.PrefixText or ""))
		return Properties
	end
end

return VIPChatController
