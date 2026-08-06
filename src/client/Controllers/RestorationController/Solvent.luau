local Replicatedstorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Core = require(Replicatedstorage.Shared.Packages.Core)

local Solvent = {
	Name = "Solvent",
	AssetName = "Solvent",
}

local Restheight = 1.15
local Contactheight = 0.025
local Pourinterval = 0.055
local Minpuddledistance = 0.12

local Currentheight = Restheight
local Lastpourtime = 0
local Lastpuddleposition: Vector3? = nil
local Tiptouching = false

local function Surfaceparts(Object: Model | BasePart): { BasePart }
	if Object:IsA("BasePart") then
		return { Object }
	end
	local Result = {}
	local Spots = Object:FindFirstChild("RestorationSpots")
	for _, Descendant in ipairs(Object:GetDescendants()) do
		if Descendant:IsA("BasePart") and (not Spots or not Descendant:IsDescendantOf(Spots)) then
			table.insert(Result, Descendant)
		end
	end
	return Result
end

local function Findsurface(Object: Model | BasePart, Position: Vector3, Normal: Vector3): RaycastResult?
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = Surfaceparts(Object)
	return Workspace:Raycast(Position + Normal * 0.4, -Normal * 1.2, Params)
end

local function Liquidfolder(Object: Model | BasePart): Folder
	local Spots = Object:FindFirstChild("RestorationSpots")
	local Parent = Spots or Object
	local Folder = Parent:FindFirstChild("SolventLiquid")
	if Folder and Folder:IsA("Folder") then
		return Folder
	end
	Folder = Instance.new("Folder")
	Folder.Name = "SolventLiquid"
	Folder.Parent = Parent
	return Folder
end

local function Depositliquid(Object: Model | BasePart, Surfaceposition: Vector3, Surfacenormal: Vector3)
	local Result = Findsurface(Object, Surfaceposition, Surfacenormal)
	if not Result or not Result.Instance:IsA("BasePart") then
		return
	end
	if Lastpuddleposition and (Result.Position - Lastpuddleposition).Magnitude < Minpuddledistance then
		return
	end
	Lastpuddleposition = Result.Position

	local Diameter = math.random(34, 52) / 100
	local Puddle = Instance.new("Part")
	Puddle.Name = "SolventDrop"
	Puddle.Shape = Enum.PartType.Cylinder
	Puddle.Size = Vector3.new(0.018, Diameter, Diameter)
	Puddle.Color = Color3.fromRGB(104, 76, 53)
	Puddle.Material = Enum.Material.Glass
	Puddle.Transparency = 0.32
	Puddle.CastShadow = false
	Puddle.CanCollide = false
	Puddle.CanQuery = false
	Puddle.CanTouch = false
	Puddle.Massless = true

	local Normal = Result.Normal
	local Tangent = Normal:Cross(Vector3.yAxis)
	if Tangent.Magnitude < 0.01 then
		Tangent = Normal:Cross(Vector3.xAxis)
	end
	Tangent = Tangent.Unit
	Puddle.CFrame = CFrame.fromMatrix(Result.Position + Normal * 0.012, Normal, Tangent)
		* CFrame.Angles(math.rad(math.random(0, 359)), 0, 0)
	Puddle.Parent = Liquidfolder(Object)

	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = Result.Instance
	Weld.Part1 = Puddle
	Weld.Parent = Puddle
end

function Solvent.GetDisplayCFrame(Context): CFrame
	local Goalheight = Context.IsUsing and Contactheight or Restheight
	local Alpha = 1 - math.exp(-14 * Context.DeltaTime)
	Currentheight += (Goalheight - Currentheight) * Alpha
	Tiptouching = Context.IsUsing and Currentheight <= Contactheight + 0.045

	local Contact = Context.SurfacePosition + Context.SurfaceNormal * Currentheight
	return CFrame.new(Contact) * CFrame.Angles(math.rad(35), math.rad(0), 0)
end

function Solvent.OnInputBegan(Context)
	if Context.Display.Instance and not Context.Display.OnObject then
		return
	end
	Lastpuddleposition = nil
	Context.SetUsing(true)
end

function Solvent.OnUpdate(Context)
	if not Context.IsUsing or not Tiptouching or not Context.Object then
		return
	end
	Core:GetController("CleaningController"):TryClean(Context.Object, Solvent.Name)
	if os.clock() - Lastpourtime < Pourinterval then
		return
	end
	Lastpourtime = os.clock()
	local Position, Normal = Context.Display.SurfacePosition, Context.Display.SurfaceNormal
	if Position and Normal then
		Depositliquid(Context.Object, Position, Normal)
	end
end

function Solvent.OnInputEnded(Context)
	Context.SetUsing(false)
	Lastpuddleposition = nil
	Tiptouching = false
end

function Solvent.OnDeselected(Context)
	Context.SetUsing(false)
	Currentheight = Restheight
	Lastpuddleposition = nil
	Tiptouching = false
end

return Solvent
