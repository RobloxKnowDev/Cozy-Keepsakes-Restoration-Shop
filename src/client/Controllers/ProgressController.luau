local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Core = require(ReplicatedStorage.Shared.Packages.Core)

local ProgressController = { Name = "ProgressController", Priority = 9 }
local Kinds = { "Dirt", "Sticker", "Ink", "Scratch" }
local RowNames = { Dirt = "DirtFrame", Sticker = "StickersFrame", Ink = "InkFrame", Scratch = "ScratchesFrame" }
local Messages = { Dirt = "DIRT CLEANED", Sticker = "STICKERS REMOVED", Ink = "INK REMOVED", Scratch = "SCRATCHES POLISHED" }
local Colors = {
	Dirt = Color3.fromRGB(218, 164, 96), Sticker = Color3.fromRGB(255, 196, 92),
	Ink = Color3.fromRGB(106, 167, 255), Scratch = Color3.fromRGB(255, 230, 164),
}
local Thresholds = { 0.25, 0.5, 0.75 }

local function Percent(Ratio: number): number
	return math.floor(Ratio * 100 + 0.5)
end

local function GetRatio(Object: Model | BasePart, Kind: string?): (number, number)
	local Total = Object:GetAttribute(if Kind then "Total_" .. Kind else "TotalSpots") or 0
	local Cleaned = Object:GetAttribute(if Kind then "Cleaned_" .. Kind else "CleanedSpots") or 0
	return if Total > 0 then math.clamp(Cleaned / Total, 0, 1) else 0, Total
end

function ProgressController:CancelTween(Key: any)
	local Tween = self.tweens[Key]
	if Tween then Tween:Cancel() end
	self.tweens[Key] = nil
end

function ProgressController:AnimateText(Label: TextLabel, From: number, To: number)
	self.textIds[Label] = (self.textIds[Label] or 0) + 1
	local Id = self.textIds[Label]
	local Started = os.clock()
	local Duration = math.clamp(math.abs(To - From) * 0.012, 0.12, 0.4)
	task.spawn(function()
		while self.textIds[Label] == Id and Label.Parent do
			local Alpha = math.clamp((os.clock() - Started) / Duration, 0, 1)
			local Eased = TweenService:GetValue(Alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Label.Text = string.format("%d%%", math.round(From + (To - From) * Eased))
			if Alpha >= 1 then return end
			RunService.Heartbeat:Wait()
		end
	end)
end

function ProgressController:AnimateBar(Bar: Frame, Ratio: number, Overshoot: boolean)
	self:CancelTween(Bar)
	local Tween = TweenService:Create(Bar, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(if Overshoot then 1.025 else Ratio, 1),
	})
	self.tweens[Bar] = Tween
	Tween:Play()
	Tween.Completed:Once(function()
		if self.tweens[Bar] ~= Tween then return end
		self.tweens[Bar] = nil
		if Overshoot then
			local Return = TweenService:Create(Bar, TweenInfo.new(0.14), { Size = UDim2.fromScale(1, 1) })
			self.tweens[Bar] = Return
			Return:Play()
		end
	end)
end

function ProgressController:Crossed(Previous: number, Current: number): number?
	for _, Threshold in ipairs(Thresholds) do
		if Previous < Threshold and Current >= Threshold then return Threshold end
	end
	return nil
end

function ProgressController:Reset(Object: Model | BasePart)
	self.sessionObject = Object
	self.previousGlobal = 0
	self.globalCompleted = false
	table.clear(self.previousRatios)
	table.clear(self.completed)
	for _, Kind in ipairs(Kinds) do
		self:CancelTween(self.bars[Kind])
		self.textIds[self.texts[Kind]] = (self.textIds[self.texts[Kind]] or 0) + 1
		self.texts[Kind].Text = "0%"
		self.texts[Kind].TextColor3 = self.baseColors[Kind]
		self.bars[Kind].Size = UDim2.fromScale(0, 1)
		self.rows[Kind]:SetAttribute("Completed", false)
	end
	self.globalText.Text = "0%"
end

function ProgressController:CompleteCategory(Kind: string)
	local Row = self.rows[Kind]
	Row:SetAttribute("Completed", true)
	self.feedback:Pulse(Row, 1.11)
	self.feedback:Flash(self.bars[Kind], Colors[Kind])
	self.feedback:Burst(Row, Colors[Kind], 24)
	self.feedback:FloatingText(self.progressFrame, Messages[Kind], Colors[Kind])
	self.feedback:PlaySound("CategoryComplete", 0.08, 1 + table.find(Kinds, Kind) * 0.025)
	self.feedback:Tween(self.texts[Kind], self.texts[Kind], TweenInfo.new(0.2), { TextColor3 = Color3.fromRGB(144, 255, 155) })
end

function ProgressController:CompleteGlobal()
	self.feedback:Success(self.percentFrame, true)
	self.feedback:GlobalCompletion()
	for _, Kind in ipairs(Kinds) do
		if self.completed[Kind] then self.feedback:Pulse(self.rows[Kind], 1.06) end
	end
end

function ProgressController:Update(Object: Model | BasePart, InteractionPosition: Vector2?)
	if self.sessionObject ~= Object then self:Reset(Object) end
	local GlobalRatio = GetRatio(Object)
	if GlobalRatio ~= self.previousGlobal then
		local Previous = self.previousGlobal
		self.previousGlobal = GlobalRatio
		self:AnimateText(self.globalText, Percent(Previous), Percent(GlobalRatio))
		if GlobalRatio > Previous then
			if InteractionPosition then
				local GainedPercent = math.clamp(math.round((GlobalRatio - Previous) * 1000) / 10, 0.1, 1)
				self.feedback:CleaningPercent(InteractionPosition, GainedPercent)
			end
			self.feedback:Pulse(self.globalText, 1.07)
			local Threshold = self:Crossed(Previous, GlobalRatio)
			if Threshold then
				self.feedback:CenterText(string.format("%d%% RESTORED", Threshold * 100), Colors.Scratch)
				self.feedback:Burst(self.percentFrame, Colors.Scratch, 12)
				self.feedback:PlaySound("ProgressMilestone", 0.1, 0.96 + Threshold * 0.18)
			else
				self.feedback:PlaySound("Progress", 0.1, 0.96 + GlobalRatio * 0.08)
			end
		end
		if Percent(GlobalRatio) >= 100 and not self.globalCompleted then
			self.globalCompleted = true
			self:CompleteGlobal()
		end
	end
	for _, Kind in ipairs(Kinds) do
		local Current, Total = GetRatio(Object, Kind)
		local Previous = self.previousRatios[Kind] or 0
		if Current ~= Previous then
			self.previousRatios[Kind] = Current
			local FirstComplete = Total > 0 and Current >= 1 and not self.completed[Kind]
			self:AnimateText(self.texts[Kind], Percent(Previous), Percent(Current))
			self:AnimateBar(self.bars[Kind], Current, FirstComplete)
			if Current > Previous then
				self.feedback:Pulse(self.texts[Kind], 1.055)
				if self:Crossed(Previous, Current) then self.feedback:Flash(self.rows[Kind], Colors[Kind]) end
			end
			if FirstComplete then
				self.completed[Kind] = true
				self:CompleteCategory(Kind)
			end
		end
	end
end

function ProgressController:Init()
	self.gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("PackageUi")
	self.percentFrame = self.gui:WaitForChild("PercentFrame")
	self.globalText = self.percentFrame:WaitForChild("PercentText")
	self.progressFrame = self.gui:WaitForChild("ProgressFrame")
	self.rows, self.bars, self.texts, self.baseColors = {}, {}, {}, {}
	self.previousRatios, self.completed, self.tweens, self.textIds = {}, {}, {}, {}
	for _, Kind in ipairs(Kinds) do
		local Row = self.progressFrame:WaitForChild(RowNames[Kind])
		local Text = Row:WaitForChild("PercentText")
		self.rows[Kind] = Row
		self.texts[Kind] = Text
		self.bars[Kind] = Row:WaitForChild("FrameBar"):WaitForChild("Bar")
		self.baseColors[Kind] = Text.TextColor3
	end
end

function ProgressController:Start()
	self.feedback = Core:GetController("FeedbackController")
end

return ProgressController
