local Players = game:GetService("Players")

local Progresscontroller = { Name = "ProgressController", Priority = 9 }

function Progresscontroller:Init()
	local Gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("PackageUi")
	self.percentText = Gui:WaitForChild("PercentFrame"):WaitForChild("PercentText")
	local Progress = Gui:WaitForChild("ProgressFrame")
	local Dirtframe = Progress:WaitForChild("DirtFrame")
	local Stickersframe = Progress:WaitForChild("StickersFrame")
	local Inkframe = Progress:WaitForChild("InkFrame")
	local Scratchesframe = Progress:WaitForChild("ScratchesFrame")
	self.bars = {
		Dirt = Dirtframe:WaitForChild("FrameBar"):WaitForChild("Bar"),
		Sticker = Stickersframe:WaitForChild("FrameBar"):WaitForChild("Bar"),
		Ink = Inkframe:WaitForChild("FrameBar"):WaitForChild("Bar"),
		Scratch = Scratchesframe:WaitForChild("FrameBar"):WaitForChild("Bar"),
	}
	self.texts = {
		Dirt = Dirtframe:WaitForChild("PercentText"),
		Sticker = Stickersframe:WaitForChild("PercentText"),
		Ink = Inkframe:WaitForChild("PercentText"),
		Scratch = Scratchesframe:WaitForChild("PercentText"),
	}
end

function Progresscontroller:Update(Object: Model | BasePart)
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
end

return Progresscontroller
