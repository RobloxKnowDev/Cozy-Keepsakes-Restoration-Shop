local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage.Shared.Packages.RemoteManager)
local Separatenumber = require(ReplicatedStorage.Shared.Utils.NumberAbbreviator)
local Shared = require(script.Parent.Shared)

local Leaderboard = {}
local Boardorder = { "Reputation", "ItemSold", "Donation" }
local RobuxIcon = ""
local Podiumcolors = {
	Color3.fromRGB(255, 205, 60),
	Color3.fromRGB(205, 212, 222),
	Color3.fromRGB(205, 127, 50),
}

local function Ordinal(Place: number): string
	local Lasttwo = Place % 100
	if Lasttwo >= 11 and Lasttwo <= 13 then
		return Place .. "th"
	end
	local Last = Place % 10
	return Place .. (if Last == 1 then "st" elseif Last == 2 then "nd" elseif Last == 3 then "rd" else "th")
end

local function Formatvalue(Board: string, Value: number): string
	if Board == "Donation" then
		return RobuxIcon .. Separatenumber(Value)
	end
	return Separatenumber(Value)
end

function Leaderboard.RenderBoard(Controller, Board: string)
	local View = Controller.leaderboardViews[Board]
	for _, Child in ipairs(View.Scrolling:GetChildren()) do
		if Child ~= View.Template and not Child:IsA("UIGridLayout") then
			Child:Destroy()
		end
	end
	for Place, Row in ipairs(Controller.leaderboardData[Board]) do
		local Card = View.Template:Clone()
		Card.Name = "Place_" .. Place
		Card.LayoutOrder = Place
		Card.Visible = true
		local Button = Card:WaitForChild("Button")
		local Placetext = Button:WaitForChild("PlaceText")
		Placetext.Text = Ordinal(Place)
		Button:WaitForChild("PlayerText").Text = Row.Name
		Button:WaitForChild("NumberText").Text = Formatvalue(Board, Row.Value)
		Button:WaitForChild("Icon").Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", Row.UserId)
		local Podium = Podiumcolors[Place]
		if Podium then
			Placetext.TextColor3 = Podium
			Button:WaitForChild("UIStroke").Color = Podium
		end
		Card.Parent = View.Scrolling
	end
end

function Leaderboard.Apply(Controller, Payload)
	Controller.leaderboardData = Payload
	for _, Board in ipairs(Boardorder) do
		Leaderboard.RenderBoard(Controller, Board)
	end
end

function Leaderboard.SetBoard(Controller, Board: string)
	Controller.leaderboardBoard = Board
	for Name, View in pairs(Controller.leaderboardViews) do
		View.Scrolling.Visible = Name == Board
	end
end

function Leaderboard.Init(Controller)
	local Buttonframe = Controller.homeFrame:WaitForChild("Button")
	local Boardframe = Controller.homeFrame:WaitForChild("Leaderboard")
	Controller.leaderboardViews = {}
	for _, Board in ipairs(Boardorder) do
		local Scrolling = Boardframe:WaitForChild(Board)
		local Layout = Scrolling:WaitForChild("UIGridLayout")
		local Template = Scrolling:WaitForChild("Template")
		Layout.SortOrder = Enum.SortOrder.LayoutOrder
		Template.Visible = false
		Controller.leaderboardViews[Board] = { Scrolling = Scrolling, Layout = Layout, Template = Template }
		local Button = Buttonframe:WaitForChild(Board .. "Button")
		Shared.AnimateButton(Button, function()
			return Controller.leaderboardBoard == Board
		end)
		Button.Activated:Connect(function()
			Leaderboard.SetBoard(Controller, Board)
		end)
	end
	Leaderboard.SetBoard(Controller, "Reputation")
	Leaderboard.Apply(Controller, RemoteManager:InvokeServer("LeaderboardService", "GetLeaderboards"))
end

function Leaderboard.Start(Controller)
	for _, View in pairs(Controller.leaderboardViews) do
		View.Scrolling.CanvasSize = UDim2.fromOffset(0, View.Layout.AbsoluteContentSize.Y)
		View.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			View.Scrolling.CanvasSize = UDim2.fromOffset(0, View.Layout.AbsoluteContentSize.Y)
		end)
	end
	RemoteManager:OnClientEvent("LeaderboardService", "LeaderboardsUpdated", function(Payload)
		Leaderboard.Apply(Controller, Payload)
	end)
end

return Leaderboard
