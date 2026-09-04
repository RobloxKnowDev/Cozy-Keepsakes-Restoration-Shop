local Assetservice = game:GetService("AssetService")
local Guiservice = game:GetService("GuiService")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Userinputservice = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)
local Roundedtexture = require(Replicatedstorage.Shared.Utils.RoundedTexture)

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

local function Getfacepoint(Part: BasePart, Worldposition: Vector3, Facename: string): Vector2
	local Position = Part.CFrame:PointToObjectSpace(Worldposition)
	local Size = Part.Size
	if Facename == "Front" then
		return Vector2.new(0.5 - Position.X / Size.X, 0.5 - Position.Y / Size.Y)
	end
	if Facename == "Back" then
		return Vector2.new(0.5 + Position.X / Size.X, 0.5 - Position.Y / Size.Y)
	end
	if Facename == "Left" then
		return Vector2.new(0.5 + Position.Z / Size.Z, 0.5 - Position.Y / Size.Y)
	end
	if Facename == "Right" then
		return Vector2.new(0.5 - Position.Z / Size.Z, 0.5 - Position.Y / Size.Y)
	end
	if Facename == "Top" then
		return Vector2.new(0.5 - Position.Z / Size.Z, 0.5 + Position.X / Size.X)
	end
	return Vector2.new(0.5 - Position.Z / Size.Z, 0.5 - Position.X / Size.X)
end

local function Getdirtimage(Surface: SurfaceGui, Facepoint: Vector2): (ImageLabel?, Vector2?)
	local Dirtframe = Surface:FindFirstChild("DirtFrame")
	if not Dirtframe then return nil end
	assert(Dirtframe:IsA("GuiObject"), "CleaningController: " .. Dirtframe:GetFullName() .. " must be a GuiObject")
	if not Dirtframe.Visible or Dirtframe:GetAttribute("Cleaned") == true then return nil end
	local Texture = Dirtframe:FindFirstChild("Texture")
	if not Texture or not Texture:IsA("ImageLabel") then return nil end
	local Canvaspoint = Surface.AbsolutePosition
		+ Vector2.new(Facepoint.X * Surface.AbsoluteSize.X, Facepoint.Y * Surface.AbsoluteSize.Y)
	local Framepoint = (Canvaspoint - Dirtframe.AbsolutePosition) / Dirtframe.AbsoluteSize
	if Framepoint.X < 0 or Framepoint.Y < 0 or Framepoint.X > 1 or Framepoint.Y > 1 then return nil end
	return Texture, Framepoint
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

local Overlayimages: { [ImageLabel]: EditableImage } = {}
local Overlaypending: { [ImageLabel]: boolean } = {}
local Overlayradiusratio = 1 / 16
local Cottonscale = 4 / 3
local Brushscale = 1.5

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

local function Getoverlayimage(Test: ImageLabel): EditableImage?
	local Editable = Overlayimages[Test]
	if Editable then return Editable end
	if Overlaypending[Test] then return nil end
	Overlaypending[Test] = true
	task.spawn(function()
		local Success, Created = pcall(function()
			return Assetservice:CreateEditableImageAsync(Content.fromUri(Test.Image))
		end)
		if not Success then
			warn("CleaningController: EditableImage failed for " .. Test:GetFullName() .. ": " .. tostring(Created))
			return
		end
		local Shape = Roundedtexture.GetShape(Test)
		Roundcorners(Created, Shape)
		Test.ImageContent = Content.fromObject(Created)
		Overlayimages[Test] = Created
		Test.Destroying:Connect(function()
			Overlayimages[Test] = nil
			Overlaypending[Test] = nil
			Created:Destroy()
		end)
	end)
	return nil
end

local Pendingpoints: { [ImageLabel]: { Vector2 } } = {}

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

local function Erasedirtoverlay(Surface: SurfaceGui, Facepoint: Vector2, Radiusscale: number)
	local Dirtframe = Surface:FindFirstChild("DirtFrame")
	if not Dirtframe or not Dirtframe:IsA("GuiObject") or not Dirtframe.Visible then return end
	local Texture = Dirtframe:FindFirstChild("Texture")
	if not Texture or not Texture:IsA("ImageLabel") then return end
	Erasetexture(Texture, Surface, Facepoint, Radiusscale)
end

local Overlayframenames = { DirtFrame = true, Ink = true, ScratchesFrame = true }

function Cleaningcontroller:PreloadOverlays(Object: Model | BasePart)
	table.clear(Pendingpoints)
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if
			Descendant:IsA("ImageLabel")
			and Descendant.Name == "Texture"
			and Descendant.Parent:IsA("GuiObject")
			and Overlayframenames[Descendant.Parent.Name]
			and Descendant.Parent.Visible
		then
			Getoverlayimage(Descendant)
		end
	end
end

function Cleaningcontroller:EraseDirtOverlay(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3, Radiusscale: number)
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Facename = Getfacename(Localnormal)
	local Surface = Part:FindFirstChild("Ui" .. Facename)
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled then return end
	Erasedirtoverlay(Surface, Getfacepoint(Part, Worldposition, Facename), Radiusscale)
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

function Cleaningcontroller:GetDirtImage(
	Part: BasePart,
	Worldposition: Vector3,
	Worldnormal: Vector3
): (ImageLabel?, Vector2?)
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Facename = Getfacename(Localnormal)
	local Surface = Part:FindFirstChild("Ui" .. Facename)
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled then return nil end
	assert(Surface.Face.Name == Facename, "CleaningController: " .. Surface:GetFullName() .. " must use the face " .. Facename)
	return Getdirtimage(Surface, Getfacepoint(Part, Worldposition, Facename))
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
	local Mouse = Userinputservice:GetMouseLocation() - Guiservice:GetGuiInset()
	local Ray = self.camera:ViewportPointToRay(Mouse.X, Mouse.Y)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Object }
	local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 100, Params)
	if not Result or not Result.Instance:IsA("BasePart") then return end
	local Radiusscale = if Toolname == "CottonTip" then Cottonscale else Brushscale
	self:EraseCleanedLeftovers(Result.Instance, Result.Position, Result.Normal, Radiusscale)
	self:EraseDirtOverlay(Result.Instance, Result.Position, Result.Normal, Radiusscale)
	if os.clock() - self.lastRequest < Cleaninterval then return end
	local Image = self:GetDirtImage(Result.Instance, Result.Position, Result.Normal)
	if not Image then return end
	local Points = Takepoints(Image)
	if not Points then return end
	self.lastRequest = os.clock()
	Remotemanager:FireServer("RestorationService", "CleanDirt", Image, Toolname, Points)
end

function Cleaningcontroller:TryCleanCotton(Object: Model | BasePart)
	if Core:GetController("InspectionCameraController"):IsDragging() then return end
	local Mouse = Userinputservice:GetMouseLocation() - Guiservice:GetGuiInset()
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
	if os.clock() - self.lastRequest < Cleaninterval then return end
	local Dirt = self:GetDirtImage(Result.Instance, Result.Position, Result.Normal)
	if not Dirt then return end
	local Points = Takepoints(Dirt)
	if not Points then return end
	self.lastRequest = os.clock()
	Remotemanager:FireServer("RestorationService", "CleanDirt", Dirt, "CottonTip", Points)
end

function Cleaningcontroller:TryClean(Object: Model | BasePart, Toolname: string)
	if os.clock() - self.lastRequest < 0.05 then return end
	if Core:GetController("InspectionCameraController"):IsDragging() then return end
	local Mouse = Userinputservice:GetMouseLocation() - Guiservice:GetGuiInset()
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
