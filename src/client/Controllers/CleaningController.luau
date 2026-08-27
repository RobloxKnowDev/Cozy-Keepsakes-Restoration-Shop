local Guiservice = game:GetService("GuiService")
local Replicatedstorage = game:GetService("ReplicatedStorage")
local Userinputservice = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)
local Remotemanager = require(Replicatedstorage.Shared.Packages.RemoteManager)

local Cleaningcontroller = { Name = "CleaningController", Priority = 9 }

local Cleaninterval = 0.075
local Scratchimagecount = 4
local Scratchcleaninterval = Cleaninterval
local Inkimagecount = 4
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
	assert(Inkframe:IsA("GuiObject"), "CleaningController: " .. Inkframe:GetFullName() .. " doit être un GuiObject")
	if not Inkframe.Visible then return nil end
	local Canvaspoint = Surface.AbsolutePosition
		+ Vector2.new(Facepoint.X * Surface.AbsoluteSize.X, Facepoint.Y * Surface.AbsoluteSize.Y)
	local Target: ImageLabel? = nil
	local Targetdistance = math.huge
	for Index = 1, Inkimagecount do
		local Image = Inkframe:WaitForChild(tostring(Index))
		assert(Image:IsA("ImageLabel"), "CleaningController: " .. Image:GetFullName() .. " doit être un ImageLabel")
		local Minimum = Image.AbsolutePosition
		local Maximum = Minimum + Image.AbsoluteSize
		if
			Image.Visible
			and Image.ImageTransparency < 1
			and Canvaspoint.X >= Minimum.X
			and Canvaspoint.Y >= Minimum.Y
			and Canvaspoint.X <= Maximum.X
			and Canvaspoint.Y <= Maximum.Y
		then
			local Distance = (Canvaspoint - (Minimum + Image.AbsoluteSize * 0.5)).Magnitude
			if Distance < Targetdistance then
				Target = Image
				Targetdistance = Distance
			end
		end
	end
	return Target
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

local function Getdirtimage(Surface: SurfaceGui, Facepoint: Vector2): ImageLabel?
	local Dirtframe = Surface:FindFirstChild("DirtFrame")
	if not Dirtframe then return nil end
	assert(Dirtframe:IsA("GuiObject"), "CleaningController: " .. Dirtframe:GetFullName() .. " doit être un GuiObject")
	if not Dirtframe.Visible then return nil end
	local Canvaspoint = Surface.AbsolutePosition
		+ Vector2.new(Facepoint.X * Surface.AbsoluteSize.X, Facepoint.Y * Surface.AbsoluteSize.Y)
	local Target: ImageLabel? = nil
	local Targetdistance = math.huge
	for Index = 1, 16 do
		local Image = Dirtframe:WaitForChild(tostring(Index))
		assert(Image:IsA("ImageLabel"), "CleaningController: " .. Image:GetFullName() .. " doit être un ImageLabel")
		local Minimum = Image.AbsolutePosition
		local Maximum = Minimum + Image.AbsoluteSize
		if
			Image.Visible
			and Image.ImageTransparency < 1
			and Canvaspoint.X >= Minimum.X
			and Canvaspoint.Y >= Minimum.Y
			and Canvaspoint.X <= Maximum.X
			and Canvaspoint.Y <= Maximum.Y
		then
			local Distance = (Canvaspoint - (Minimum + Image.AbsoluteSize * 0.5)).Magnitude
			if Distance < Targetdistance then
				Target = Image
				Targetdistance = Distance
			end
		end
	end
	return Target
end

local function Getscratchimage(Surface: SurfaceGui, Facepoint: Vector2): ImageLabel?
	local Canvaspoint = Surface.AbsolutePosition
		+ Vector2.new(Facepoint.X * Surface.AbsoluteSize.X, Facepoint.Y * Surface.AbsoluteSize.Y)
	local Target: ImageLabel? = nil
	local Targetdistance = math.huge
	for _, Scratchframe in ipairs(Surface:GetChildren()) do
		if Scratchframe.Name == "ScratchesFrame" then
			assert(Scratchframe:IsA("GuiObject"), "CleaningController: " .. Scratchframe:GetFullName() .. " doit être un GuiObject")
			if not Scratchframe.Visible then continue end
			for Index = 1, Scratchimagecount do
				local Image = Scratchframe:WaitForChild(tostring(Index))
				assert(Image:IsA("ImageLabel"), "CleaningController: " .. Image:GetFullName() .. " doit être un ImageLabel")
				local Minimum = Image.AbsolutePosition
				local Maximum = Minimum + Image.AbsoluteSize
				if
					Image.Visible
					and Image.ImageTransparency < 1
					and Canvaspoint.X >= Minimum.X
					and Canvaspoint.Y >= Minimum.Y
					and Canvaspoint.X <= Maximum.X
					and Canvaspoint.Y <= Maximum.Y
				then
					local Distance = (Canvaspoint - (Minimum + Image.AbsoluteSize * 0.5)).Magnitude
					if Distance < Targetdistance then
						Target = Image
						Targetdistance = Distance
					end
				end
			end
		end
	end
	return Target
end

function Cleaningcontroller:Init()
	self.camera = Workspace.CurrentCamera
	self.lastRequest = 0
	self.lastScratchRequest = 0
	self.lastInkRequest = 0
	self.lastInkSolventRequest = 0
	self.lastScratchPolishRequest = 0
end

function Cleaningcontroller:GetDirtImage(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Facename = Getfacename(Localnormal)
	local Surface = Part:FindFirstChild("Ui" .. Facename)
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled then return nil end
	assert(Surface.Face.Name == Facename, "CleaningController: " .. Surface:GetFullName() .. " doit utiliser la face " .. Facename)
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
	assert(Surface.Face.Name == Facename, "CleaningController: " .. Surface:GetFullName() .. " doit utiliser la face " .. Facename)
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
	assert(Surface.Face.Name == Facename, "CleaningController: " .. Surface:GetFullName() .. " doit utiliser la face " .. Facename)
	return Getinkimage(Surface, Getfacepoint(Part, Worldposition, Facename))
end

function Cleaningcontroller:TryApplyInkSolvent(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Image = self:GetInkImage(Part, Worldposition, Worldnormal)
	if not Image or Image.ImageTransparency >= 1 then return nil end
	if Image:GetAttribute("HasSolvent") ~= true and os.clock() - self.lastInkSolventRequest >= Liquidapplyinterval then
		self.lastInkSolventRequest = os.clock()
		Remotemanager:FireServer("RestorationService", "ApplyInkSolvent", Image)
	end
	return Image
end

function Cleaningcontroller:TryApplyScratchPolish(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Image = self:GetScratchImage(Part, Worldposition, Worldnormal)
	if not Image or Image.ImageTransparency >= 1 then return nil end
	if Image:GetAttribute("HasPolish") ~= true and os.clock() - self.lastScratchPolishRequest >= Liquidapplyinterval then
		self.lastScratchPolishRequest = os.clock()
		Remotemanager:FireServer("RestorationService", "ApplyScratchPolish", Image)
	end
	return Image
end

function Cleaningcontroller:TryCleanInk(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Image = self:GetInkImage(Part, Worldposition, Worldnormal)
	if not Image or Image.ImageTransparency >= 1 then return nil end
	if os.clock() - self.lastInkRequest >= Inkcleaninterval then
		self.lastInkRequest = os.clock()
		Remotemanager:FireServer("RestorationService", "CleanInk", Image)
	end
	return Image
end

function Cleaningcontroller:TryCleanScratch(Part: BasePart, Worldposition: Vector3, Worldnormal: Vector3): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Image = self:GetScratchImage(Part, Worldposition, Worldnormal)
	if not Image or Image.ImageTransparency >= 1 then return nil end
	if os.clock() - self.lastScratchRequest >= Scratchcleaninterval then
		self.lastScratchRequest = os.clock()
		Remotemanager:FireServer("RestorationService", "CleanScratch", Image)
	end
	return Image
end

function Cleaningcontroller:TryCleanDirt(Object: Model | BasePart, Toolname: string)
	if os.clock() - self.lastRequest < Cleaninterval then return end
	if Core:GetController("InspectionCameraController"):IsDragging() then return end
	local Mouse = Userinputservice:GetMouseLocation() - Guiservice:GetGuiInset()
	local Ray = self.camera:ViewportPointToRay(Mouse.X, Mouse.Y)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Object }
	local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 100, Params)
	if not Result or not Result.Instance:IsA("BasePart") then return end
	local Image = self:GetDirtImage(Result.Instance, Result.Position, Result.Normal)
	if not Image then return end
	self.lastRequest = os.clock()
	Remotemanager:FireServer("RestorationService", "CleanDirt", Image, Toolname)
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

	local Ink = self:GetInkImage(Result.Instance, Result.Position, Result.Normal)
	if Ink and Ink.ImageTransparency < 1 then
		if Ink:GetAttribute("HasSolvent") ~= true then return end
		self:TryCleanInk(Result.Instance, Result.Position, Result.Normal)
		return
	end

	local Scratch = self:GetScratchImage(Result.Instance, Result.Position, Result.Normal)
	if Scratch and Scratch.ImageTransparency < 1 then
		if Scratch:GetAttribute("HasPolish") ~= true then return end
		self:TryCleanScratch(Result.Instance, Result.Position, Result.Normal)
		return
	end

	if os.clock() - self.lastRequest < Cleaninterval then return end
	local Dirt = self:GetDirtImage(Result.Instance, Result.Position, Result.Normal)
	if not Dirt then return end
	self.lastRequest = os.clock()
	Remotemanager:FireServer("RestorationService", "CleanDirt", Dirt, "CottonTip")
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
