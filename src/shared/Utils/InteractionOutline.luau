local Workspace = game:GetService("Workspace")

local InteractionOutline = {}

local Outlinecolor = Color3.fromRGB(255, 255, 255)
local Outlinetransparency = 0
local Depthmode = Enum.HighlightDepthMode.AlwaysOnTop

function InteractionOutline.Create(Name: string): Highlight
	local Outline = Instance.new("Highlight")
	Outline.Name = Name
	Outline.DepthMode = Depthmode
	Outline.FillTransparency = 1
	Outline.OutlineColor = Outlinecolor
	Outline.OutlineTransparency = Outlinetransparency
	Outline.Enabled = false
	Outline.Parent = Workspace
	return Outline
end

return InteractionOutline
