local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)

local Uvtorch = {
	Name = "UvTorch",
	AssetName = "UvTorch",
	ShowsProgress = true,
}

local Uvcolor = Color3.fromRGB(100, 11, 255)
local Normalcolor = Color3.fromRGB(255, 255, 255)
local Glowingimages: { [ImageLabel]: boolean } = {}

local function Stopglowing(Image: ImageLabel)
	if Image.Parent then Image.ImageColor3 = Normalcolor end
	Glowingimages[Image] = nil
end

local function Clearglow()
	for Image in pairs(Glowingimages) do
		Stopglowing(Image)
	end
end

local function Makeglow(Image: ImageLabel)
	Image.ImageColor3 = Uvcolor
	Glowingimages[Image] = true
end

function Uvtorch.GetDisplayCFrame(Context): CFrame
	local Target = Context.SurfacePosition
	local Torchposition = Target + Vector3.new(0, 2.4, 0)
	return CFrame.lookAt(Torchposition, Target, Context.Camera.CFrame.RightVector) * CFrame.Angles(0, math.rad(90), 0)
end

function Uvtorch.OnUpdate(Context)
	local Display = Context.Display
	local Image: ImageLabel? = nil
	if
		Context.Object
		and Display.OnObject
		and Display.HitInstance
		and Display.HitInstance:IsA("BasePart")
		and Display.SurfacePosition
		and Display.SurfaceNormal
	then
		Image = Core:GetController("CleaningController"):GetDirtImage(
			Display.HitInstance,
			Display.SurfacePosition,
			Display.SurfaceNormal
		)
		if Image and Image.ImageTransparency >= 1 then Image = nil end
	end

	for Previous in pairs(Glowingimages) do
		if Previous ~= Image or not Previous.Parent then Stopglowing(Previous) end
	end
	if Image then Makeglow(Image) end
end

function Uvtorch.OnDeselected()
	Clearglow()
end

return Uvtorch
