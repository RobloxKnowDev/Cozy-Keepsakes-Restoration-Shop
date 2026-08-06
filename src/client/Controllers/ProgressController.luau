local Players = game:GetService("Players")

local Progresscontroller = { Name = "ProgressController", Priority = 9 }

function Progresscontroller:Init()
	local Gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("PackageUi")
	self.percentText = Gui.PercentFrame.PercentText
	local Progress = Gui.ProgressFrame
	self.bars = {
		Dirt = Progress.DirtFrame.FrameBar.Bar,
		Sticker = Progress.StickersFrame.FrameBar.Bar,
	}
	self.texts = {
		Dirt = Progress.DirtFrame.PercentText,
		Sticker = Progress.StickersFrame.PercentText,
	}
end

function Progresscontroller:Update(Object: Model | BasePart): boolean
	local Totalspots = Object:GetAttribute("TotalSpots") or 0
	local Cleanedspots = Object:GetAttribute("CleanedSpots") or 0
	local Globalratio = Totalspots > 0 and math.clamp(Cleanedspots / Totalspots, 0, 1) or 0
	self.percentText.Text = string.format("%d%%", math.floor(Globalratio * 100 + 0.5))
	for Kind, Bar in self.bars do
		local Total = Object:GetAttribute("Total_" .. Kind) or 0
		local Cleaned = Object:GetAttribute("Cleaned_" .. Kind) or 0
		local Ratio = Total > 0 and math.clamp(Cleaned / Total, 0, 1) or 0
		self.texts[Kind].Text = string.format("%d%%", math.floor(Ratio * 100 + 0.5))
		Bar.Size = UDim2.fromScale(Ratio, 1)
	end
	return Totalspots > 0 and Cleanedspots >= Totalspots
end

return Progresscontroller
