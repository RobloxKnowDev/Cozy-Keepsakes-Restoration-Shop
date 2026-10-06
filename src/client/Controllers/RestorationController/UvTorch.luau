local Assetservice = game:GetService("AssetService")
local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)

local Uvtorch = {
	Name = "UvTorch",
	AssetName = "UvTorch",
	Hint = "Use",
	ShowsProgress = true,
}

local Uvcolor = Color3.new(1, 1, 1)
local Sizescale = 2.5
local Beamscale = 2.5
local Scaninterval = 1 / 24
local Haloimagesize = 256
local Haloringratio = 0.62
local Halozindex = 1000
local Halosmoothing = 16
local Halobreathspeed = 2.4
local Halobreathamount = 0.04
local Lit = false
local Lastscan = 0
local Lastupdate = os.clock()
local Halocanvassize = 256
local Halo: ImageLabel? = nil
local Haloimage: EditableImage? = nil
local Halosurface: SurfaceGui? = nil
local Halocanvas: EditableImage? = nil
local Halodecal: Decal? = nil
local Halodirt: Decal? = nil
local Haloclear = buffer.create(Halocanvassize * Halocanvassize * 4)
local Halotarget = { Center = Vector2.new(0.5, 0.5), Size = Vector2.zero, Alpha = 0 }
local Halostate = { Center = Vector2.new(0.5, 0.5), Size = Vector2.zero, Alpha = 0 }
local Leftoverradius = 0.25
local Glowimagesize = 32
local Glowdotsize = 10
local Glowalpha = 0.9
local Glowimage: EditableImage? = nil
local Glowcanvas: EditableImage? = nil
local Glowdecal: Decal? = nil
local Glowtarget = 0
local Glowstate = 0

function Uvtorch.IsLit(): boolean
	return Lit
end

local function Getlight(Context): Light
	return Context.Display.Tip:WaitForChild("Light") :: Light
end

local function Buildhaloimage(): EditableImage
	local Image = Assetservice:CreateEditableImage({ Size = Vector2.new(Haloimagesize, Haloimagesize) })
	local Pixels = buffer.create(Haloimagesize * Haloimagesize * 4)
	local Half = Haloimagesize / 2
	for Y = 0, Haloimagesize - 1 do
		for X = 0, Haloimagesize - 1 do
			local Distance = math.sqrt((X + 0.5 - Half) ^ 2 + (Y + 0.5 - Half) ^ 2) / Half
			local Bloom = if Distance < Haloringratio
				then math.exp(-((Haloringratio - Distance) / 0.1) ^ 2)
				else math.exp(-((Distance - Haloringratio) / 0.22) ^ 2)
			local Line = math.exp(-((Distance - (Haloringratio - 0.05)) / 0.025) ^ 2)
			local Haze = math.clamp(1 - Distance, 0, 1) ^ 2 * 0.22
			local Edge = math.clamp((1 - Distance) / 0.08, 0, 1)
			local Alpha = math.clamp(Bloom * 0.8 + Line * 0.6 + Haze, 0, 1) * Edge
			local Offset = (Y * Haloimagesize + X) * 4
			buffer.writeu8(Pixels, Offset, 255)
			buffer.writeu8(Pixels, Offset + 1, 255)
			buffer.writeu8(Pixels, Offset + 2, 255)
			buffer.writeu8(Pixels, Offset + 3, math.round(Alpha * 255))
		end
	end
	Image:WritePixelsBuffer(Vector2.zero, Vector2.new(Haloimagesize, Haloimagesize), Pixels)
	return Image
end

local function Gethalo(): ImageLabel
	if Halo then return Halo end
	if not Haloimage then Haloimage = Buildhaloimage() end
	local Label = Instance.new("ImageLabel")
	Label.Name = "UvHalo"
	Label.BackgroundTransparency = 1
	Label.ScaleType = Enum.ScaleType.Fit
	Label.AnchorPoint = Vector2.new(0.5, 0.5)
	Label.ImageContent = Content.fromObject(Haloimage)
	Label.ImageColor3 = Uvcolor
	Label.ImageTransparency = 1
	Label.Visible = false
	Label.Destroying:Connect(function()
		if Halo == Label then Halo, Halosurface = nil, nil end
	end)
	Halo = Label
	return Label
end

local function Gethalodecal(): Decal
	if Halodecal then return Halodecal end
	if not Haloimage then Haloimage = Buildhaloimage() end
	if not Halocanvas then
		Halocanvas = Assetservice:CreateEditableImage({ Size = Vector2.new(Halocanvassize, Halocanvassize) })
	end
	local Decal = Instance.new("Decal")
	Decal.Name = "UvHalo"
	Decal.TextureContent = Content.fromObject(Halocanvas)
	Decal.Color3 = Uvcolor
	Decal.Transparency = 1
	Decal.Destroying:Connect(function()
		if Halodecal == Decal then Halodecal, Halodirt = nil, nil end
	end)
	Halodecal = Decal
	return Decal
end

local function Buildglowimage(): EditableImage
	local Image = Assetservice:CreateEditableImage({ Size = Vector2.new(Glowimagesize, Glowimagesize) })
	local Pixels = buffer.create(Glowimagesize * Glowimagesize * 4)
	local Half = Glowimagesize / 2
	for Y = 0, Glowimagesize - 1 do
		for X = 0, Glowimagesize - 1 do
			local Distance = math.sqrt((X + 0.5 - Half) ^ 2 + (Y + 0.5 - Half) ^ 2) / Half
			local Offset = (Y * Glowimagesize + X) * 4
			buffer.writeu8(Pixels, Offset, 255)
			buffer.writeu8(Pixels, Offset + 1, 255)
			buffer.writeu8(Pixels, Offset + 2, 255)
			buffer.writeu8(Pixels, Offset + 3, math.round(math.clamp(1 - Distance, 0, 1) ^ 1.5 * 255))
		end
	end
	Image:WritePixelsBuffer(Vector2.zero, Vector2.new(Glowimagesize, Glowimagesize), Pixels)
	return Image
end

local function Getglowdecal(): Decal
	if Glowdecal then return Glowdecal end
	if not Glowimage then Glowimage = Buildglowimage() end
	local Canvas = Glowcanvas or Assetservice:CreateEditableImage({ Size = Vector2.new(Halocanvassize, Halocanvassize) })
	Glowcanvas = Canvas
	local Decal = Instance.new("Decal")
	Decal.Name = "UvGlow"
	Decal.TextureContent = Content.fromObject(Canvas)
	Decal.Color3 = Uvcolor
	Decal.ZIndex = Halozindex
	Decal.Transparency = 1
	Decal.Destroying:Connect(function()
		if Glowdecal == Decal then Glowdecal = nil end
	end)
	Glowdecal = Decal
	return Decal
end

local function Drawglow(Spots: { Vector3 })
	local Canvas = Glowcanvas :: EditableImage
	local Image = Glowimage :: EditableImage
	Canvas:WritePixelsBuffer(Vector2.zero, Canvas.Size, Haloclear)
	for _, Spot in ipairs(Spots) do
		local Diameter = Glowdotsize + Spot.Z * 2
		Canvas:DrawImageTransformed(
			Vector2.new(Spot.X, Spot.Y) * Halocanvassize,
			Vector2.one * (Diameter / Glowimagesize),
			0,
			Image,
			{ CombineType = Enum.ImageCombineType.AlphaBlend }
		)
	end
end

local function Hideglow()
	Glowtarget = 0
	Glowstate = 0
	if Glowdecal then
		Glowdecal.Transparency = 1
		Glowdecal.Parent = nil
	end
end

local function Detachsurfacehalo()
	Halosurface = nil
	if Halo then
		Halo.Visible = false
		Halo.ImageTransparency = 1
		Halo.Parent = nil
	end
end

local function Detachdecalhalo()
	Halodirt = nil
	if Halodecal then
		Halodecal.Transparency = 1
		Halodecal.Parent = nil
	end
end

local function Hidehalo()
	Halotarget.Alpha = 0
	Halostate.Alpha = 0
	Detachsurfacehalo()
	Detachdecalhalo()
	Hideglow()
end

local function Scan(Context)
	local Display = Context.Display
	local Light = Getlight(Context)
	if not (Light.Enabled and Context.Object and Display.OnObject) then
		Halotarget.Alpha = 0
		Glowtarget = 0
		return
	end
	local Leftoverdecal, Spots = Core:GetController("CleaningController"):FindLeftovers(
		Display.HitInstance,
		Display.SurfacePosition,
		Display.SurfaceNormal,
		Leftoverradius
	)
	if Leftoverdecal and #Spots > 0 then
		local Decal = Getglowdecal()
		Decal.Face = Leftoverdecal.Face
		Decal.Parent = Leftoverdecal.Parent
		Drawglow(Spots)
		Glowtarget = Glowalpha
	else
		Glowtarget = 0
	end
	local Found = Core:GetController("CleaningController"):FindStainAround(
		Display.HitInstance,
		Display.SurfacePosition,
		Display.SurfaceNormal,
		Beamscale
	)
	if not Found then
		Halotarget.Alpha = 0
		return
	end
	local Halopixels = math.clamp(Found.Spread * 2.2 + Found.Radius * 0.25, Found.Radius * 0.45, Found.Radius * 1.15)
	local Extent = 2 * Halopixels / Haloringratio
	local Size = Vector2.new(Extent * Found.Scale.X, Extent * Found.Scale.Y)
	if Found.Decal then
		Detachsurfacehalo()
		local Decal = Gethalodecal()
		if Halodirt ~= Found.Decal then
			local Moved = Halodirt == nil or Halodirt.Parent ~= Found.Decal.Parent or Halodirt.Face ~= Found.Decal.Face
			Halodirt = Found.Decal
			Decal.Face = Found.Decal.Face
			Decal.ZIndex = Halozindex
			Decal.Parent = Found.Decal.Parent
			if Moved then
				Halostate.Center, Halostate.Size, Halostate.Alpha = Found.Center, Size * 1.5, 0
			end
		end
	else
		Detachdecalhalo()
		local Label = Gethalo()
		if Halosurface ~= Found.Surface then
			Halosurface = Found.Surface
			Label.ZIndex = Halozindex
			Label.Parent = Found.Surface
			Halostate.Center, Halostate.Size, Halostate.Alpha = Found.Center, Size * 1.5, 0
		end
	end
	Halotarget.Center, Halotarget.Size = Found.Center, Size
	Halotarget.Alpha = 0.55 + 0.45 * math.clamp(Found.Amount / 0.2, 0, 1)
end

local function Drawhalodecal(Decal: Decal, Breath: number, Shimmer: number)
	if Halostate.Alpha <= 0.02 then
		Decal.Transparency = 1
		return
	end
	local Canvas = Halocanvas :: EditableImage
	local Image = Haloimage :: EditableImage
	Canvas:WritePixelsBuffer(Vector2.zero, Canvas.Size, Haloclear)
	Canvas:DrawImageTransformed(
		Halostate.Center * Halocanvassize,
		Halostate.Size * Breath * (Halocanvassize / Haloimagesize),
		0,
		Image,
		{ CombineType = Enum.ImageCombineType.Overwrite, PivotPoint = Image.Size / 2 }
	)
	Decal.Transparency = 1 - Halostate.Alpha * Shimmer
end

local function Animatehalo(Deltatime: number)
	if Glowdecal then
		Glowstate += (Glowtarget - Glowstate) * (1 - math.exp(-Halosmoothing * Deltatime))
		Glowdecal.Transparency = 1 - Glowstate * (0.85 + 0.15 * math.sin(os.clock() * Halobreathspeed * 2))
	end
	if not Halo and not Halodecal then return end
	local Blend = 1 - math.exp(-Halosmoothing * Deltatime)
	Halostate.Center = Halostate.Center:Lerp(Halotarget.Center, Blend)
	Halostate.Size = Halostate.Size:Lerp(Halotarget.Size, Blend)
	Halostate.Alpha += (Halotarget.Alpha - Halostate.Alpha) * Blend
	local Clock = os.clock()
	local Breath = 1 + Halobreathamount * math.sin(Clock * Halobreathspeed)
	local Shimmer = 0.92 + 0.08 * math.sin(Clock * Halobreathspeed * 2)
	if Halo then
		Halo.Position = UDim2.fromScale(Halostate.Center.X, Halostate.Center.Y)
		Halo.Size = UDim2.fromScale(Halostate.Size.X * Breath, Halostate.Size.Y * Breath)
		Halo.ImageTransparency = 1 - Halostate.Alpha * Shimmer
		Halo.Visible = Halostate.Alpha > 0.02
	end
	if Halodecal and Halodirt then
		Drawhalodecal(Halodecal, Breath, Shimmer)
	end
end

function Uvtorch.OnSelected(Context)
	Lit = false
	Getlight(Context).Enabled = false
	Lastupdate = os.clock()
	Hidehalo()
end

function Uvtorch.OnInputBegan(Context)
	local Light = Getlight(Context)
	Light.Enabled = not Light.Enabled
	Lit = Light.Enabled
	Core:GetController("FeedbackController"):PlaySound("UvTorch")
end

function Uvtorch.GetDisplayCFrame(Context): CFrame
	local Target = Context.SurfacePosition
	local Torchposition = Target + Context.SurfaceNormal * (2.4 / Sizescale)
	return CFrame.lookAt(Torchposition, Target, Context.Camera.CFrame.RightVector) * CFrame.Angles(0, math.rad(90), 0)
end

function Uvtorch.OnUpdate(Context)
	local Now = os.clock()
	local Deltatime = math.min(Now - Lastupdate, 0.1)
	Lastupdate = Now
	if Now - Lastscan >= Scaninterval then
		Lastscan = Now
		Scan(Context)
	end
	Animatehalo(Deltatime)
end

function Uvtorch.OnDeselected()
	Lit = false
	Hidehalo()
end

return Uvtorch
