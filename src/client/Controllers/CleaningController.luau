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
local Solventrequestretry = 0.25

type Pendingsolventrequest = {
	Attributechanged: RBXScriptConnection?,
	Destroying: RBXScriptConnection?,
	Requestedat: number?,
}

local Pendingsolventrequests: { [ImageLabel]: Pendingsolventrequest } = {}

local function Clearpendingsolventrequest(Image: ImageLabel)
	local Request = Pendingsolventrequests[Image]
	if not Request then return end
	Pendingsolventrequests[Image] = nil
	if Request.Attributechanged then Request.Attributechanged:Disconnect() end
	if Request.Destroying then Request.Destroying:Disconnect() end
end

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
	local Dirtframe = Surface:WaitForChild("DirtFrame") :: GuiObject
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

local function Getscratchimage(Surface: SurfaceGui, Facepoint: Vector2, Prefersolventfree: boolean): ImageLabel?
	local Scratchframe = Surface:FindFirstChild("ScratchesFrame")
	if not Scratchframe then return nil end
	assert(Scratchframe:IsA("GuiObject"), "CleaningController: " .. Scratchframe:GetFullName() .. " doit être un GuiObject")
	if not Scratchframe.Visible then return nil end
	local Canvaspoint = Surface.AbsolutePosition
		+ Vector2.new(Facepoint.X * Surface.AbsoluteSize.X, Facepoint.Y * Surface.AbsoluteSize.Y)
	local Target: ImageLabel? = nil
	local Targetdistance = math.huge
	local Solventfreetarget: ImageLabel? = nil
	local Solventfreetargetdistance = math.huge
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
			if Image:GetAttribute("HasSolvent") ~= true and Distance < Solventfreetargetdistance then
				Solventfreetarget = Image
				Solventfreetargetdistance = Distance
			end
		end
	end
	return if Prefersolventfree and Solventfreetarget then Solventfreetarget else Target
end

function Cleaningcontroller:Init()
	self.camera = Workspace.CurrentCamera
	self.lastRequest = 0
	self.lastScratchRequest = 0
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
	Worldnormal: Vector3,
	Prefersolventfree: boolean?
): ImageLabel?
	local Localnormal = Part.CFrame:VectorToObjectSpace(Worldnormal)
	local Facename = Getfacename(Localnormal)
	local Surface = Part:FindFirstChild("Ui" .. Facename)
	if not Surface or not Surface:IsA("SurfaceGui") or not Surface.Enabled then return nil end
	assert(Surface.Face.Name == Facename, "CleaningController: " .. Surface:GetFullName() .. " doit utiliser la face " .. Facename)
	return Getscratchimage(Surface, Getfacepoint(Part, Worldposition, Facename), Prefersolventfree == true)
end

function Cleaningcontroller:TryApplyScratchSolvent(
	Part: BasePart,
	Worldposition: Vector3,
	Worldnormal: Vector3
): ImageLabel?
	if Core:GetController("InspectionCameraController"):IsDragging() then return nil end
	local Image = self:GetScratchImage(Part, Worldposition, Worldnormal, true)
	if not Image or Image.ImageTransparency >= 1 then return nil end
	if Image:GetAttribute("HasSolvent") == true then
		Clearpendingsolventrequest(Image)
	else
		local Request = Pendingsolventrequests[Image]
		if not Request then
			Request = {}
			Pendingsolventrequests[Image] = Request
			Request.Attributechanged = Image:GetAttributeChangedSignal("HasSolvent"):Connect(function()
				if Image:GetAttribute("HasSolvent") == true then Clearpendingsolventrequest(Image) end
			end)
			Request.Destroying = Image.Destroying:Connect(function()
				Clearpendingsolventrequest(Image)
			end)
		end
		local Now = os.clock()
		if not Request.Requestedat or Now - Request.Requestedat >= Solventrequestretry then
			Request.Requestedat = Now
			Remotemanager:FireServer("RestorationService", "ApplyScratchSolvent", Image)
		end
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

	local Scratch = self:GetScratchImage(Result.Instance, Result.Position, Result.Normal)
	if Scratch and Scratch.ImageTransparency < 1 then
		if Scratch:GetAttribute("HasSolvent") ~= true then return end
		if os.clock() - self.lastScratchRequest < Scratchcleaninterval then return end
		self.lastScratchRequest = os.clock()
		Remotemanager:FireServer("RestorationService", "CleanScratch", Scratch)
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
