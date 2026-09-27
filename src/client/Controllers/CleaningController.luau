local Assetservice = game:GetService("AssetService")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Userinputservice = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Cleaningconfig = require(Replicatedstorage.Shared.Config.Cleaning)
local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)
local Roundedtexture = require(Replicatedstorage.Shared.Utils.RoundedTexture)
local Facemapping = require(Replicatedstorage.Shared.Utils.FaceMapping)

local function Countcopies(Name: string): number
	local Count = 0
	for _, Child in ipairs(Replicatedstorage.Shared.Utils:GetChildren()) do
		if Child.Name == Name then
			Count += 1
		end
	end
	return Count
end

assert(
	Roundedtexture.GetShape and Roundedtexture.GetBounds and Roundedtexture.GetRowInset,
	string.format(
		"CleaningController: outdated RoundedTexture (%d copies in Shared.Utils, delete the duplicates in Studio)",
		Countcopies("RoundedTexture")
	)
)

local Cleaningcontroller = { Name = "CleaningController", Priority = 9 }

local Cleaninterval = 0.075
local Scratchcleaninterval = Cleaninterval
local Inkcleaninterval = Cleaninterval
local Liquidapplyinterval = 0.25
local Maxdirtstrokes = 8
local Minimumfacedot = 0.01
local Dirtdecalnames = Cleaningconfig.DirtDecals
local Getfacepoint = Facemapping.GetPoint

local function Getfacename(Localnormal: Vector3): string
	local Absolutex = math.abs(Localnormal.X)
	local Absolutey = math.abs(Localnormal.Y)
	local Absolutez = math.abs(Localnormal.Z)
	if Absolutex > Absolutey and Absolutex > Absolutez then
		return if Localnormal.X > 0 then "Right" else "Left"
	end
	if Absolutey > Absolutez then
		return if Localnormal.Y > 0 then "Top" else "Bottom"
	end
	return if Localnormal.Z > 0 then "Back" else "Front"
end

local function Getinkimage(Surface: SurfaceGui, Facepoint: Vector2): ImageLabel?
	local Inkframe = Surface:FindFirstChild("Ink")
	if not Inkframe then return nil end
	assert(Inkframe:IsA("GuiObject"), "CleaningController: " .. Inkframe:GetFullName() .. " must be a GuiObject")
	if not Inkframe.Visible or Inkframe:GetAttribute("Cleaned") == true then return nil end
	local Texture = Inkframe:FindFirstChild("Texture")
	if not Texture or not Texture:IsA("ImageLabel") then return nil end
	if (Texture:GetAttribute("Remaining") or 0) <= 0 then return nil end
	local Canvaspoint = Surface.AbsolutePosition
		+ Vector2.new(Facepoint.X * Surface.AbsoluteSize.X, Facepoint.Y * Surface.AbsoluteSize.Y)
	local Minimum = Texture.AbsolutePosition
	local Maximum = Minimum + Texture.AbsoluteSize
	if Canvaspoint.X < Minimum.X or Canvaspoint.Y < Minimum.Y or Canvaspoint.X > Maximum.X or Canvaspoint.Y > Maximum.Y then
		return nil
	end
	return Texture
end

local function Getdirtdecals(Part: BasePart, Worldnormal: Vector3): { Decal }
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Decals = {}
	for _, Child in ipairs(Part:GetChildren()) do
		if Child:IsA("Decal") and Dirtdecalnames[Child.Name] and Vector3.FromNormalId(Child.Face):Dot(Localnormal) > Minimumfacedot then
			table.insert(Decals, Child)
		end
	end
	return Decals
end

local function Getscratchimage(Surface: SurfaceGui, Facepoint: Vector2): ImageLabel?
	local Canvaspoint = Surface.AbsolutePosition
		+ Vector2.new(Facepoint.X * Surface.AbsoluteSize.X, Facepoint.Y * Surface.AbsoluteSize.Y)
	for _, Scratchframe in ipairs(Surface:GetChildren()) do
		if Scratchframe.Name == "ScratchesFrame" then
			assert(Scratchframe:IsA("GuiObject"), "CleaningController: " .. Scratchframe:GetFullName() .. " must be a GuiObject")
			if not Scratchframe.Visible or Scratchframe:GetAttribute("Cleaned") == true then continue end
			local Texture = Scratchframe:FindFirstChild("Texture")
			if not Texture or not Texture:IsA("ImageLabel") then continue end
			if (Texture:GetAttribute("Remaining") or 0) <= 0 then continue end
			local Minimum = Texture.AbsolutePosition
			local Maximum = Minimum + Texture.AbsoluteSize
			if
				Canvaspoint.X >= Minimum.X
				and Canvaspoint.Y >= Minimum.Y
				and Canvaspoint.X <= Maximum.X
				and Canvaspoint.Y <= Maximum.Y
			then
				return Texture
			end
		end
	end
	return nil
end

local Overlayimages: { [Instance]: EditableImage } = {}
local Overlaypending: { [Instance]: boolean } = {}
local Overlayradiusratio = 1 / 16
local Cottonscale = 4 / 3
local Brushscale = 1.5
local Dirtfadestep = math.ceil(255 / Cleaningconfig.DirtPasses)
local Stainsamplestep = 2
local Stainspotratio = 0.2
local Tickmarks: { [Instance]: buffer } = {}

export type StainCluster = {
	Surface: SurfaceGui?,
	Decal: Decal?,
	Center: Vector2,
	Spread: number,
	Radius: number,
	Scale: Vector2,
	Amount: number,
	Spot: number,
}
local function Roundcorners(Editable: EditableImage, Shape)
	if not Roundedtexture.IsCut(Shape) then
		return
	end
	local Size = Editable.Size
	local Width, Height = Size.X, Size.Y
	local Bounds = Roundedtexture.GetBounds(Width, Height, Shape)
	local Pixels = Editable:ReadPixelsBuffer(Vector2.zero, Size)
	for Y = 0, Height - 1 do
		local Rowinset = Roundedtexture.GetRowInset(Y + 0.5, Bounds)
		local Startx, Endx = 0, 0
		if Rowinset then
			Startx = math.clamp(math.floor(Bounds.Left + Rowinset), 0, Width)
			Endx = math.clamp(math.ceil(Bounds.Right - Rowinset), Startx, Width)
		end
		local Rowoffset = Y * Width * 4
		if Startx > 0 then
			buffer.fill(Pixels, Rowoffset, 0, Startx * 4)
		end
		if Endx < Width then
			buffer.fill(Pixels, Rowoffset + Endx * 4, 0, (Width - Endx) * 4)
		end
	end
	Editable:WritePixelsBuffer(Vector2.zero, Size, Pixels)
end

local function Getoverlayimage(Test: ImageLabel | Decal): EditableImage?
	local Editable = Overlayimages[Test]
	if Editable then return Editable end
	if Overlaypending[Test] then return nil end
	Overlaypending[Test] = true
	task.spawn(function()
		local Source = if Test:IsA("Decal") then Test.Texture else Test.Image
		local Success, Created = pcall(function()
			return Assetservice:CreateEditableImageAsync(Content.fromUri(Source))
		end)
		if not Success then
			warn("CleaningController: EditableImage failed for " .. Test:GetFullName() .. ": " .. tostring(Created))
			return
		end
		if Test:IsA("Decal") then
			Test.TextureContent = Content.fromObject(Created)
		else
			Roundcorners(Created, Roundedtexture.GetShape(Test))
			Test.ImageContent = Content.fromObject(Created)
		end
		Overlayimages[Test] = Created
		Test.Destroying:Connect(function()
			Overlayimages[Test] = nil
			Overlaypending[Test] = nil
			Tickmarks[Test] = nil
			Created:Destroy()
		end)
	end)
	return nil
end

local Pendingpoints: { [ImageLabel]: { Vector2 } } = {}
local Pendingdirt: { [Decal]: { Vector2 } } = {}

local function Takepoints(Texture: ImageLabel): { Vector2 }?
	local Points = Pendingpoints[Texture]
	Pendingpoints[Texture] = nil
	return Points
end

local function Erasetexture(Texture: ImageLabel, Surface: SurfaceGui, Facepoint: Vector2, Radiusscale: number)
	local Canvaspoint = Surface.AbsolutePosition
		+ Vector2.new(Facepoint.X * Surface.AbsoluteSize.X, Facepoint.Y * Surface.AbsoluteSize.Y)
	local Localpoint = (Canvaspoint - Texture.AbsolutePosition) / Texture.AbsoluteSize
	if Localpoint.X < 0 or Localpoint.Y < 0 or Localpoint.X > 1 or Localpoint.Y > 1 then return end
	local Points = Pendingpoints[Texture]
	if not Points then
		Points = {}
		Pendingpoints[Texture] = Points
	end
	if #Points < 16 then table.insert(Points, Localpoint) end
	local Editable = Getoverlayimage(Texture)
	if not Editable then return end
	local Size = Editable.Size
	local Center = Vector2.new(math.round(Localpoint.X * Size.X), math.round(Localpoint.Y * Size.Y))
	local Radius = math.max(math.round(math.min(Size.X, Size.Y) * Overlayradiusratio * Radiusscale), 2)
	Editable:DrawCircle(Center, Radius, Color3.new(0, 0, 0), 1, Enum.ImageCombineType.Overwrite)
end

local function Fadedecal(Decal: Decal, Localpoint: Vector2, Radiusscale: number)
	if Localpoint.X < 0 or Localpoint.Y < 0 or Localpoint.X > 1 or Localpoint.Y > 1 then return end
	local Points = Pendingdirt[Decal]
	if not Points then
		Points = {}
		Pendingdirt[Decal] = Points
	end
	if #Points < 16 then table.insert(Points, Localpoint) end
	local Editable = Getoverlayimage(Decal)
	if not Editable then return end
	local Size = Editable.Size
	local Width, Height = Size.X, Size.Y
	local Centerx = math.round(Localpoint.X * Width)
	local Centery = math.round(Localpoint.Y * Height)
	local Radius = math.max(math.round(math.min(Width, Height) * Overlayradiusratio * Radiusscale), 2)
	local Minx = math.max(Centerx - Radius, 0)
	local Miny = math.max(Centery - Radius, 0)
	local Maxx = math.min(Centerx + Radius, Width - 1)
	local Maxy = math.min(Centery + Radius, Height - 1)
	if Minx > Maxx or Miny > Maxy then return end
	local Regionwidth = Maxx - Minx + 1
	local Regionheight = Maxy - Miny + 1
	local Pixels = Editable:ReadPixelsBuffer(Vector2.new(Minx, Miny), Vector2.new(Regionwidth, Regionheight))
	local Marks = Tickmarks[Decal]
	if not Marks then
		Marks = buffer.create(Width * Height * 2)
		Tickmarks[Decal] = Marks
	end
	local Tick = math.floor(os.clock() / Cleaninterval) % 65535 + 1
	local Radiussquared = Radius * Radius
	for Y = Miny, Maxy do
		local Dy = Y - Centery
		for X = Minx, Maxx do
			local Dx = X - Centerx
			if Dx * Dx + Dy * Dy <= Radiussquared then
				local Markoffset = (Y * Width + X) * 2
				if buffer.readu16(Marks, Markoffset) ~= Tick then
					buffer.writeu16(Marks, Markoffset, Tick)
					local Alphaoffset = ((Y - Miny) * Regionwidth + (X - Minx)) * 4 + 3
					local Alpha = buffer.readu8(Pixels, Alphaoffset)
					if Alpha > 0 then
						buffer.writeu8(Pixels, Alphaoffset, math.max(Alpha - Dirtfadestep, 0))
					end
				end
			end
		end
	end
	Editable:WritePixelsBuffer(Vector2.new(Minx, Miny), Vector2.new(Regionwidth, Regionheight), Pixels)
end

local Overlayframenames = { Ink = true, ScratchesFrame = true }

function Cleaningcontroller:PreloadOverlays(Object: Model | BasePart)
	table.clear(Pendingpoints)
	table.clear(Pendingdirt)
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if
			Descendant:IsA("ImageLabel")
			and Descendant.Name == "Texture"
			and Descendant.Parent:IsA("GuiObject")
			and Overlayframenames[Descendant.Parent.Name]
			and Descendant.Parent.Visible
		then
			Getoverlayimage(Descendant)
		elseif Descendant:IsA("Decal") and Dirtdecalnames[Descendant.Name] then
			Getoverlayimage(Descendant)
		end
	end
end

function Cleaningcontroller:EraseDirtOverlay(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3, Radiusscale: number)
	for _, Decal in ipairs(Getdirtdecals(Part, Worldnormal)) do
		Fadedecal(Decal, Getfacepoint(Part, Worldposition, Decal.Face.Name), Radiusscale)
	end
end

function Cleaningcontroller:SendDirt(Toolname: string)
	if os.clock() - self.lastRequest < Cleaninterval then return end
	local Strokes = {}
	for Decal, Points in pairs(Pendingdirt) do
		if Decal.Parent and Decal:GetAttribute("Cleaned") ~= true and #Strokes < Maxdirtstrokes then
			table.insert(Strokes, { Target = Decal, Points = Points })
		end
	end
	table.clear(Pendingdirt)
	if #Strokes == 0 then return end
	self.lastRequest = os.clock()
	Remotemanager:FireServer("RestorationService", "CleanDirt", Toolname, Strokes)
end

function Cleaningcontroller:EraseTextureAt(
	Part: BasePart,
	Worldposition: Vector3,
	Worldnormal: Vector3,
	Texture: ImageLabel,
	Radiusscale: number
)
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Facename = Getfacename(Localnormal)
	local Surface = Part:FindFirstChild("Ui" .. Facename)
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled then return end
	Erasetexture(Texture, Surface, Getfacepoint(Part, Worldposition, Facename), Radiusscale)
end

function Cleaningcontroller:EraseCleanedLeftovers(
	Part: BasePart,
	Worldposition: Vector3,
	Worldnormal: Vector3,
	Radiusscale: number
)
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Facename = Getfacename(Localnormal)
	local Surface = Part:FindFirstChild("Ui" .. Facename)
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled then return end
	local Facepoint = Getfacepoint(Part, Worldposition, Facename)
	for _, Frame in ipairs(Surface:GetChildren()) do
		if
			(Frame.Name == "Ink" or Frame.Name == "ScratchesFrame")
			and Frame:IsA("GuiObject")
			and Frame.Visible
			and Frame:GetAttribute("Cleaned") == true
		then
			local Texture = Frame:FindFirstChild("Texture")
			if Texture and Texture:IsA("ImageLabel") then
				Erasetexture(Texture, Surface, Facepoint, Radiusscale)
			end
		end
	end
end

function Cleaningcontroller:Init()
	self.camera = Workspace.CurrentCamera
	self.lastRequest = 0
	self.lastScratchRequest = 0
	self.lastInkRequest = 0
	self.lastInkSolventRequest = 0
	self.lastScratchPolishRequest = 0
end

local function Scanpixels(Editable: EditableImage, Localpoint: Vector2, Radiusscale: number)
	if Localpoint.X < 0 or Localpoint.Y < 0 or Localpoint.X > 1 or Localpoint.Y > 1 then return nil end
	local Size = Editable.Size
	local Width, Height = Size.X, Size.Y
	local Centerx = math.round(Localpoint.X * Width)
	local Centery = math.round(Localpoint.Y * Height)
	local Radius = math.max(math.round(math.min(Width, Height) * Overlayradiusratio * Radiusscale), 2)
	local Minx = math.max(Centerx - Radius, 0)
	local Miny = math.max(Centery - Radius, 0)
	local Maxx = math.min(Centerx + Radius, Width - 1)
	local Maxy = math.min(Centery + Radius, Height - 1)
	if Minx > Maxx or Miny > Maxy then return nil end
	local Regionwidth = Maxx - Minx + 1
	local Regionheight = Maxy - Miny + 1
	local Pixels = Editable:ReadPixelsBuffer(Vector2.new(Minx, Miny), Vector2.new(Regionwidth, Regionheight))
	local Radiussquared = Radius * Radius
	local Spotradiussquared = (Radius * Stainspotratio) ^ 2
	local Samples, Weight, Spotweight, Sumx, Sumy, Sumxx, Sumyy = 0, 0, 0, 0, 0, 0, 0
	for Y = Miny, Maxy, Stainsamplestep do
		local Dy = Y - Centery
		for X = Minx, Maxx, Stainsamplestep do
			local Dx = X - Centerx
			local Distancesquared = Dx * Dx + Dy * Dy
			if Distancesquared <= Radiussquared then
				Samples += 1
				local Alpha = buffer.readu8(Pixels, ((Y - Miny) * Regionwidth + (X - Minx)) * 4 + 3)
				if Alpha > 0 then
					Weight += Alpha
					Sumx += X * Alpha
					Sumy += Y * Alpha
					Sumxx += X * X * Alpha
					Sumyy += Y * Y * Alpha
					if Distancesquared <= Spotradiussquared then Spotweight += Alpha end
				end
			end
		end
	end
	if Spotweight == 0 then return nil end
	local Meanx, Meany = Sumx / Weight, Sumy / Weight
	local Variance = math.max(Sumxx / Weight - Meanx * Meanx + Sumyy / Weight - Meany * Meany, 0)
	return {
		Mean = Vector2.new(Meanx, Meany),
		Spread = math.sqrt(Variance),
		Radius = Radius,
		Amount = Weight / (Samples * 255),
		Spot = Spotweight,
	}
end

local function Scanstain(Texture: ImageLabel, Surface: SurfaceGui, Facepoint: Vector2, Radiusscale: number): StainCluster?
	local Editable = Overlayimages[Texture]
	if not Editable then return nil end
	local Canvaspoint = Surface.AbsolutePosition
		+ Vector2.new(Facepoint.X * Surface.AbsoluteSize.X, Facepoint.Y * Surface.AbsoluteSize.Y)
	local Scan = Scanpixels(Editable, (Canvaspoint - Texture.AbsolutePosition) / Texture.AbsoluteSize, Radiusscale)
	if not Scan then return nil end
	local Pixelscale = Texture.AbsoluteSize / Editable.Size
	local Canvascenter = Texture.AbsolutePosition - Surface.AbsolutePosition + Scan.Mean * Pixelscale
	return {
		Surface = Surface,
		Center = Canvascenter / Surface.AbsoluteSize,
		Spread = Scan.Spread,
		Radius = Scan.Radius,
		Scale = Pixelscale / Surface.AbsoluteSize,
		Amount = Scan.Amount,
		Spot = Scan.Spot,
	}
end

local function Scandecal(Decal: Decal, Facepoint: Vector2, Radiusscale: number): StainCluster?
	local Editable = Overlayimages[Decal]
	if not Editable then return nil end
	local Scan = Scanpixels(Editable, Facepoint, Radiusscale)
	if not Scan then return nil end
	return {
		Decal = Decal,
		Center = Scan.Mean / Editable.Size,
		Spread = Scan.Spread,
		Radius = Scan.Radius,
		Scale = Vector2.one / Editable.Size,
		Amount = Scan.Amount,
		Spot = Scan.Spot,
	}
end

function Cleaningcontroller:FindStainAround(
	Part: BasePart,
	Worldposition: Vector3,
	Worldnormal: Vector3,
	Radiusscale: number
): StainCluster?
	local Best: StainCluster? = nil
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Facename = Getfacename(Localnormal)
	local Surface = Part:FindFirstChild("Ui" .. Facename)
	if Surface and Surface:IsA("SurfaceGui") and Surface.Enabled then
		local Facepoint = Getfacepoint(Part, Worldposition, Facename)
		local Candidates = {}
		local Ink = Getinkimage(Surface, Facepoint)
		if Ink then table.insert(Candidates, Ink) end
		local Scratch = Getscratchimage(Surface, Facepoint)
		if Scratch then table.insert(Candidates, Scratch) end
		for _, Texture in ipairs(Candidates) do
			local Cluster = Scanstain(Texture, Surface, Facepoint, Radiusscale)
			if Cluster and (not Best or Cluster.Spot > Best.Spot) then Best = Cluster end
		end
	end
	for _, Decal in ipairs(Getdirtdecals(Part, Worldnormal)) do
		if Decal:GetAttribute("Cleaned") ~= true then
			local Cluster = Scandecal(Decal, Getfacepoint(Part, Worldposition, Decal.Face.Name), Radiusscale)
			if Cluster and (not Best or Cluster.Spot > Best.Spot) then Best = Cluster end
		end
	end
	return Best
end

function Cleaningcontroller:GetScratchImage(
	Part: BasePart,
	Worldposition: Vector3,
	Worldnormal: Vector3
): ImageLabel?
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Facename = Getfacename(Localnormal)
	local Surface = Part:FindFirstChild("Ui" .. Facename)
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled then return nil end
	assert(Surface.Face.Name == Facename, "CleaningController: " .. Surface:GetFullName() .. " must use the face " .. Facename)
	return Getscratchimage(Surface, Getfacepoint(Part, Worldposition, Facename))
end

function Cleaningcontroller:GetInkImage(
	Part: BasePart,
	Worldposition: Vector3,
	Worldnormal: Vector3
): ImageLabel?
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Facename = Getfacename(Localnormal)
	local Surface = Part:FindFirstChild("Ui" .. Facename)
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled then return nil end
	assert(Surface.Face.Name == Facename, "CleaningController: " .. Surface:GetFullName() .. " must use the face " .. Facename)
	return Getinkimage(Surface, Getfacepoint(Part, Worldposition, Facename))
end

function Cleaningcontroller:TryApplyInkSolvent(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Image = self:GetInkImage(Part, Worldposition, Worldnormal)
	if not Image then return nil end
	if Image:GetAttribute("HasSolvent") ~= true and os.clock() - self.lastInkSolventRequest >= Liquidapplyinterval then
		self.lastInkSolventRequest = os.clock()
		Remotemanager:FireServer("RestorationService", "ApplyInkSolvent", Image)
	end
	return Image
end

function Cleaningcontroller:TryApplyScratchPolish(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Image = self:GetScratchImage(Part, Worldposition, Worldnormal)
	if not Image then return nil end
	if Image:GetAttribute("HasPolish") ~= true and os.clock() - self.lastScratchPolishRequest >= Liquidapplyinterval then
		self.lastScratchPolishRequest = os.clock()
		Remotemanager:FireServer("RestorationService", "ApplyScratchPolish", Image)
	end
	return Image
end

function Cleaningcontroller:TryCleanInk(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Image = self:GetInkImage(Part, Worldposition, Worldnormal)
	if not Image then return nil end
	if os.clock() - self.lastInkRequest >= Inkcleaninterval then
		local Points = Takepoints(Image)
		if Points then
			self.lastInkRequest = os.clock()
			Remotemanager:FireServer("RestorationService", "CleanInk", Image, Points)
		end
	end
	return Image
end

function Cleaningcontroller:TryCleanScratch(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Image = self:GetScratchImage(Part, Worldposition, Worldnormal)
	if not Image then return nil end
	if os.clock() - self.lastScratchRequest >= Scratchcleaninterval then
		local Points = Takepoints(Image)
		if Points then
			self.lastScratchRequest = os.clock()
			Remotemanager:FireServer("RestorationService", "CleanScratch", Image, Points)
		end
	end
	return Image
end

function Cleaningcontroller:TryCleanDirt(Object: Model | BasePart, Toolname: string)
	if Core:GetController("InspectionCameraController"):IsDragging() then return end
	local Mouse = Userinputservice:GetMouseLocation()
	local Ray = self.camera:ViewportPointToRay(Mouse.X, Mouse.Y)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Object }
	local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 100, Params)
	if not Result or not Result.Instance:IsA("BasePart") then return end
	local Radiusscale = if Toolname == "CottonTip" then Cottonscale else Brushscale
	self:EraseCleanedLeftovers(Result.Instance, Result.Position, Result.Normal, Radiusscale)
	self:EraseDirtOverlay(Result.Instance, Result.Position, Result.Normal, Radiusscale)
	self:SendDirt(Toolname)
end

function Cleaningcontroller:TryCleanCotton(Object: Model | BasePart)
	if Core:GetController("InspectionCameraController"):IsDragging() then return end
	local Mouse = Userinputservice:GetMouseLocation()
	local Ray = self.camera:ViewportPointToRay(Mouse.X, Mouse.Y)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Object }
	local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 100, Params)
	if not Result or not Result.Instance:IsA("BasePart") then return end

	self:EraseCleanedLeftovers(Result.Instance, Result.Position, Result.Normal, Brushscale)
	local Ink = self:GetInkImage(Result.Instance, Result.Position, Result.Normal)
	if Ink then
		if Ink:GetAttribute("HasSolvent") ~= true then return end
		self:EraseTextureAt(Result.Instance, Result.Position, Result.Normal, Ink, Brushscale)
		self:TryCleanInk(Result.Instance, Result.Position, Result.Normal)
		return
	end

	local Scratch = self:GetScratchImage(Result.Instance, Result.Position, Result.Normal)
	if Scratch then
		if Scratch:GetAttribute("HasPolish") ~= true then return end
		self:EraseTextureAt(Result.Instance, Result.Position, Result.Normal, Scratch, Brushscale)
		self:TryCleanScratch(Result.Instance, Result.Position, Result.Normal)
		return
	end

	self:EraseDirtOverlay(Result.Instance, Result.Position, Result.Normal, Cottonscale)
	self:SendDirt("CottonTip")
end

function Cleaningcontroller:TryClean(Object: Model | BasePart, Toolname: string)
	if os.clock() - self.lastRequest < 0.05 then return end
	if Core:GetController("InspectionCameraController"):IsDragging() then return end
	local Mouse = Userinputservice:GetMouseLocation()
	local Ray = self.camera:ViewportPointToRay(Mouse.X, Mouse.Y)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Object }
	local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 100, Params)
	if Result and Result.Instance:GetAttribute("SpotKind") then
		self.lastRequest = os.clock()
		Remotemanager:FireServer("RestorationService", "CleanSpot", Result.Instance, Toolname)
	end
end

return Cleaningcontroller
