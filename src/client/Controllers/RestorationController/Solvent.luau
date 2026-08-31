local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)

local Solvent = {
	Name = "Solvent",
	AssetName = "Solvent",
}

local Sizescale = 2.5
local Restheight = 1.15 / Sizescale
local Contactheight = 0.025 / Sizescale
local Pourinterval = 0.055
local Minpuddledistance = 0.38 / Sizescale

local Currentheight = Restheight
local Lastpourtime = 0
local Lastpuddleposition: Vector3? = nil
local Tiptouching = false

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

local function Depositliquid(
	Object: Model | BasePart,
	Surface: BasePart,
	Surfaceposition: Vector3,
	Surfacenormal: Vector3,
	Target: ImageLabel?
)
	local Diameter = math.random(62, 82) / 100
	local Puddle = Instance.new("Part")
	Puddle.Name = "SolventDrop"
	Puddle.Shape = Enum.PartType.Cylinder
	Puddle.Size = Vector3.new(0.012, Diameter * 1.1, Diameter * 0.9) / Sizescale
	Puddle.Color = Color3.fromRGB(78, 88, 96)
	Puddle.Material = Enum.Material.SmoothPlastic
	Puddle.Transparency = 0.8
	Puddle.CastShadow = false
	Puddle.CanCollide = false
	Puddle.CanQuery = false
	Puddle.CanTouch = false
	Puddle.Massless = true

	local Normal = Surfacenormal
	local Tangent = Normal:Cross(Vector3.yAxis)
	if Tangent.Magnitude < 0.01 then
		Tangent = Normal:Cross(Vector3.xAxis)
	end
	Tangent = Tangent.Unit
	Puddle.CFrame = CFrame.fromMatrix(Surfaceposition + Normal * (0.009 / Sizescale), Normal, Tangent)
		* CFrame.Angles(math.rad(math.random(0, 359)), 0, 0)
	Puddle.Parent = Liquidfolder(Object)
	if Target then
		local Inktarget = Instance.new("ObjectValue")
		Inktarget.Name = "InkTarget"
		Inktarget.Value = Target
		Inktarget.Parent = Puddle
	end

	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = Surface
	Weld.Part1 = Puddle
	Weld.Parent = Puddle
end

function Solvent.GetDisplayCFrame(Context): CFrame
	local Goalheight = Context.IsUsing and Contactheight or Restheight
	local Alpha = 1 - math.exp(-14 * Context.DeltaTime)
	Currentheight += (Goalheight - Currentheight) * Alpha
	Tiptouching = Context.IsUsing and Currentheight <= Contactheight + 0.045 / Sizescale

	local Contact = Context.SurfacePosition + Context.SurfaceNormal * Currentheight
	return CFrame.new(Contact) * CFrame.Angles(math.rad(35), math.rad(0), 0)
end

function Solvent.OnInputBegan(Context)
	if Context.Display.Instance and not Context.Display.OnObject then
		return
	end
	Lastpourtime = 0
	Lastpuddleposition = nil
	Context.SetUsing(true)
end

function Solvent.OnUpdate(Context)
	if not Context.IsUsing or not Tiptouching or not Context.Object then
		return
	end
	local Display = Context.Display
	local Cleaningcontroller = Core:GetController("CleaningController")
	local Surface = Display.HitInstance
	local Position = Display.SurfacePosition
	local Normal = Display.SurfaceNormal
	if not Display.OnObject or not Surface or not Surface:IsA("BasePart") or not Position or not Normal then
		return
	end
	if os.clock() - Lastpourtime < Pourinterval then return end
	if Lastpuddleposition and (Position - Lastpuddleposition).Magnitude < Minpuddledistance then return end
	local Target = Cleaningcontroller:TryApplyInkSolvent(Surface, Position, Normal)
	Lastpourtime = os.clock()
	Lastpuddleposition = Position
	Depositliquid(Context.Object, Surface, Position, Normal, Target)
	Core:GetController("FeedbackController"):PlaySound("Solvent", 0.08)
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
