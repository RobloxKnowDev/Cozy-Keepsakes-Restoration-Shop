local Players = game:GetService("Players")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Userinputservice = game:GetService("UserInputService")

local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Admincontroller = {
	Name = "AdminController",
	Priority = 26,
}

local Servicename = "AdminService"
local Togglekey = Enum.KeyCode.F2
local Consolewidth = 520
local Rowheight = 26
local Maximumrows = 6
local Backgroundcolor = Color3.fromRGB(18, 18, 22)
local Hintcolor = Color3.fromRGB(150, 150, 160)

local function Makelabel(Parent: Instance, Order: number): TextLabel
	local Label = Instance.new("TextLabel")
	Label.Name = "Row" .. Order
	Label.LayoutOrder = Order
	Label.BackgroundTransparency = 1
	Label.Size = UDim2.new(1, -20, 0, Rowheight)
	Label.FontFace = Font.new("rbxasset://fonts/families/Inter.json", Enum.FontWeight.Medium)
	Label.TextSize = 15
	Label.TextColor3 = Hintcolor
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.TextTruncate = Enum.TextTruncate.AtEnd
	Label.Text = ""
	Label.Visible = false
	Label.Parent = Parent
	return Label
end

function Admincontroller:Buildgui()
	local Playergui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "AdminUi"
	self.gui.DisplayOrder = 9000
	self.gui.IgnoreGuiInset = true
	self.gui.ResetOnSpawn = false
	self.gui.Enabled = false
	self.gui.Parent = Playergui

	self.frame = Instance.new("Frame")
	self.frame.Name = "Console"
	self.frame.AnchorPoint = Vector2.new(0.5, 0)
	self.frame.Position = UDim2.new(0.5, 0, 0, 70)
	self.frame.Size = UDim2.fromOffset(Consolewidth, 40)
	self.frame.BackgroundColor3 = Backgroundcolor
	self.frame.BackgroundTransparency = 0.1
	self.frame.BorderSizePixel = 0
	self.frame.Parent = self.gui
	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 8)
	Corner.Parent = self.frame

	self.input = Instance.new("TextBox")
	self.input.Name = "Input"
	self.input.BackgroundTransparency = 1
	self.input.Size = UDim2.new(1, -20, 0, 40)
	self.input.Position = UDim2.fromOffset(10, 0)
	self.input.FontFace = Font.new("rbxasset://fonts/families/Inter.json", Enum.FontWeight.SemiBold)
	self.input.TextSize = 17
	self.input.TextColor3 = Color3.new(1, 1, 1)
	self.input.PlaceholderText = "Command..."
	self.input.TextXAlignment = Enum.TextXAlignment.Left
	self.input.ClearTextOnFocus = false
	self.input.Text = ""
	self.input.Parent = self.frame

	self.list = Instance.new("ScrollingFrame")
	self.list.Name = "Suggestions"
	self.list.BackgroundColor3 = Backgroundcolor
	self.list.BackgroundTransparency = 0.1
	self.list.BorderSizePixel = 0
	self.list.Position = UDim2.fromOffset(0, 44)
	self.list.Size = UDim2.fromOffset(Consolewidth, 0)
	self.list.CanvasSize = UDim2.fromOffset(0, 0)
	self.list.ScrollBarThickness = 4
	self.list.ScrollBarImageColor3 = Hintcolor
	self.list.Visible = false
	self.list.Parent = self.frame
	local Listcorner = Instance.new("UICorner")
	Listcorner.CornerRadius = UDim.new(0, 8)
	Listcorner.Parent = self.list
	local Listlayout = Instance.new("UIListLayout")
	Listlayout.SortOrder = Enum.SortOrder.LayoutOrder
	Listlayout.Padding = UDim.new(0, 0)
	Listlayout.Parent = self.list
	local Listpadding = Instance.new("UIPadding")
	Listpadding.PaddingTop = UDim.new(0, 4)
	Listpadding.PaddingBottom = UDim.new(0, 4)
	Listpadding.PaddingLeft = UDim.new(0, 10)
	Listpadding.Parent = self.list

	self.rows = {}
end

function Admincontroller:Getrow(Order: number): TextLabel
	local Row = self.rows[Order]
	if not Row then
		Row = Makelabel(self.list, Order)
		self.rows[Order] = Row
	end
	return Row
end

function Admincontroller:Showrows(Lines: { { Text: string, Color: Color3 } })
	for Order, Line in ipairs(Lines) do
		local Row = self:Getrow(Order)
		Row.Text = Line.Text
		Row.TextColor3 = Line.Color
		Row.Visible = true
	end
	for Order = #Lines + 1, #self.rows do
		self.rows[Order].Visible = false
	end
	local Visiblerows = math.min(#Lines, Maximumrows)
	self.list.Visible = #Lines > 0
	self.list.Size = UDim2.fromOffset(Consolewidth, Visiblerows * Rowheight + 8)
	self.list.CanvasSize = UDim2.fromOffset(0, #Lines * Rowheight + 8)
	self.list.CanvasPosition = Vector2.zero
end

function Admincontroller:Findcommand(Name: string)
	for _, Command in ipairs(self.commands) do
		if Command.Name == Name then
			return Command
		end
	end
	return nil
end

function Admincontroller:Getoptions(Kind: string): { string }
	if Kind == "player" then
		local Names = {}
		for _, Player in ipairs(Players:GetPlayers()) do
			table.insert(Names, Player.Name)
		end
		table.sort(Names)
		return Names
	end
	return self.options[Kind] or {}
end

function Admincontroller:Refreshsuggestions()
	local Text = self.input.Text
	local Words = {}
	for Word in string.gmatch(Text, "%S+") do
		table.insert(Words, Word)
	end
	local Trailingspace = string.match(Text, "%s$") ~= nil
	local Index = if Trailingspace then #Words + 1 else math.max(#Words, 1)
	local Current = string.lower(if Trailingspace then "" else Words[Index] or "")
	local Lines = {}

	if Index <= 1 then
		for _, Command in ipairs(self.commands) do
			if Current == "" or string.sub(Command.Name, 1, #Current) == Current then
				table.insert(Lines, { Text = Command.Usage .. "  —  " .. Command.Description, Color = Hintcolor })
			end
		end
		self:Showrows(Lines)
		return
	end

	local Command = self:Findcommand(string.lower(Words[1] or ""))
	if not Command then
		self:Showrows({ { Text = "Unknown command", Color = Hintcolor } })
		return
	end
	local Kind = Command.Arguments[Index - 1]
	if not Kind or Kind == "number" then
		self:Showrows({ { Text = Command.Usage, Color = Hintcolor } })
		return
	end
	for _, Option in ipairs(self:Getoptions(Kind)) do
		if Current == "" or string.sub(string.lower(Option), 1, #Current) == Current then
			table.insert(Lines, { Text = Option, Color = Hintcolor })
		end
	end
	if #Lines == 0 then
		table.insert(Lines, { Text = Command.Usage, Color = Hintcolor })
	end
	self:Showrows(Lines)
end

function Admincontroller:Setopen(Open: boolean)
	self.gui.Enabled = Open
	if Open then
		self.input.Text = ""
		self:Refreshsuggestions()
		self.input:CaptureFocus()
	else
		self.input:ReleaseFocus()
	end
end

function Admincontroller:Submit()
	local Text = self.input.Text
	if string.match(Text, "^%s*$") then
		self:Setopen(false)
		return
	end
	self.input.Text = ""
	self:Showrows({ { Text = "...", Color = Hintcolor } })
	task.spawn(function()
		local Result = Remotemanager:InvokeServer(Servicename, "RunCommand", Text)
		if not self.gui.Enabled then
			return
		end
		self:Showrows({ { Text = tostring(Result), Color = Color3.new(1, 1, 1) } })
	end)
end

function Admincontroller:Init()
	self:Buildgui()
	self.commands = {}
	self.options = {}
end

function Admincontroller:Start()
	task.spawn(function()
		local Result = Remotemanager:InvokeServer(Servicename, "GetCommands")
		if type(Result) ~= "table" or type(Result.Commands) ~= "table" or #Result.Commands == 0 then
			return
		end
		self.commands = Result.Commands
		self.options = if type(Result.Options) == "table" then Result.Options else {}
		Userinputservice.InputBegan:Connect(function(Input, Processed)
			if Processed or Input.KeyCode ~= Togglekey then
				return
			end
			self:Setopen(not self.gui.Enabled)
		end)
		self.input:GetPropertyChangedSignal("Text"):Connect(function()
			if self.gui.Enabled then
				self:Refreshsuggestions()
			end
		end)
		self.input.FocusLost:Connect(function(Entered)
			if Entered then
				self:Submit()
			else
				self:Setopen(false)
			end
		end)
	end)
end

return Admincontroller
