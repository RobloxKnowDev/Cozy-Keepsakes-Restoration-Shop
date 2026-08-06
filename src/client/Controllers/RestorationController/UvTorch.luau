local Uvtorch = {
	Name = "UvTorch",
	AssetName = "UvTorch",
	ShowsProgress = true,
}

local Glowingspots: { [BasePart]: Highlight } = {}

local function Stopglowing(Spot: BasePart)
	local Glow = Glowingspots[Spot]
	if Glow then Glow:Destroy() end
	Glowingspots[Spot] = nil
end

local function Clearglow()
	for Spot in pairs(Glowingspots) do
		Stopglowing(Spot)
	end
end

local function Makeglow(Spot: BasePart)
	if Glowingspots[Spot] then return end
	local Glow = Instance.new("Highlight")
	Glow.Name = "UvGlow"
	Glow.Adornee = Spot
	Glow.DepthMode = Enum.HighlightDepthMode.Occluded
	Glow.FillColor = Color3.fromRGB(151, 74, 255)
	Glow.FillTransparency = 0.18
	Glow.OutlineTransparency = 1
	Glow.Parent = Spot
	Glowingspots[Spot] = Glow
end

function Uvtorch.GetDisplayCFrame(Context): CFrame
	local Target = Context.SurfacePosition
	local Torchposition = Target + Vector3.new(0, 2.4, 0)
	return CFrame.lookAt(Torchposition, Target, Context.Camera.CFrame.RightVector) * CFrame.Angles(0, math.rad(90), 0)
end

function Uvtorch.OnUpdate(Context)
	local Object = Context.Object
	local Lightposition = Context.Display.SurfacePosition
	if not Object or not Lightposition then
		Clearglow()
		return
	end

	local Spots = Object:FindFirstChild("RestorationSpots")
	if not Spots then
		Clearglow()
		return
	end

	local Illuminated: { [BasePart]: boolean } = {}
	for _, Descendant in ipairs(Spots:GetDescendants()) do
		if Descendant:IsA("BasePart") and Descendant:GetAttribute("SpotKind") == "Dirt" then
			local Isilluminated = (Descendant.Position - Lightposition).Magnitude <= 1.65
			if Isilluminated then
				Illuminated[Descendant] = true
				Makeglow(Descendant)
			end
		end
	end
	for Spot in pairs(Glowingspots) do
		if not Illuminated[Spot] or not Spot.Parent then Stopglowing(Spot) end
	end
end

function Uvtorch.OnDeselected()
	Clearglow()
end

return Uvtorch
