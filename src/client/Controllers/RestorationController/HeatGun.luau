local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)

local Heatgun = {
	Name = "HeatGun",
	AssetName = "HeatGun",
	Hint = "Use",
}

local Sizescale = 2.5
local Cleanradius = 1.25 / Sizescale
local Liquidfolders = { "SolventLiquid", "PolishLiquid" }

local function Setemitter(Context, Enabled: boolean)
	local Emitter = Context.Display.Tip:WaitForChild("ParticleEmitter") :: ParticleEmitter
	Emitter.EmissionDirection = Enum.NormalId.Right
	Emitter.Enabled = Enabled
end

local function Iswet(Spots: Instance, Stain: Instance): boolean
	for _, Foldername in ipairs(Liquidfolders) do
		local Folder = Spots:FindFirstChild(Foldername)
		if Folder then
			for _, Drop in ipairs(Folder:GetChildren()) do
				local Target = Drop:FindFirstChild("StainTarget") :: ObjectValue?
				if Target and Target.Value == Stain then
					return true
				end
			end
		end
	end
	return false
end

local function Cleanliquid(Context)
	local Display = Context.Display
	if not Context.Object or not Display.OnObject or not Display.SurfacePosition then
		return
	end
	local Spots = Context.Object:WaitForChild("RestorationSpots")
	local Heated: { [Instance]: boolean } = {}
	for _, Foldername in ipairs(Liquidfolders) do
		local Folder = Spots:FindFirstChild(Foldername)
		if Folder then
			for _, Drop in ipairs(Folder:GetChildren()) do
				if Drop:IsA("BasePart") and (Drop.Position - Display.SurfacePosition).Magnitude <= Cleanradius then
					local Target = Drop:FindFirstChild("StainTarget") :: ObjectValue?
					if Target and Target.Value then
						Heated[Target.Value] = true
					end
					Drop:Destroy()
				end
			end
		end
	end
	for Stain in pairs(Heated) do
		if not Iswet(Spots, Stain) then
			Core:GetController("CleaningController"):DryStain(Stain)
		end
	end
end

function Heatgun.GetDisplayCFrame(Context): CFrame
	local Target = Context.SurfacePosition
	local Heatgunposition = Target + Context.SurfaceNormal * (2.4 / Sizescale)
	return CFrame.lookAt(Heatgunposition, Target, Context.Camera.CFrame.RightVector) * CFrame.Angles(0, math.rad(90), 0)
end

function Heatgun.OnSelected(Context)
	Setemitter(Context, false)
end

function Heatgun.OnInputBegan(Context)
	if Context.Display.Instance and not Context.Display.OnObject then
		return
	end
	Context.SetUsing(true)
	Setemitter(Context, true)
	Core:GetController("FeedbackController"):SetLoop("HeatGun", true)
	if Context.Object then
		Cleanliquid(Context)
	end
end

function Heatgun.OnUpdate(Context)
	if Context.IsUsing and Context.Object then
		Cleanliquid(Context)
	end
end

function Heatgun.OnInputEnded(Context)
	Context.SetUsing(false)
	Setemitter(Context, false)
	Core:GetController("FeedbackController"):SetLoop("HeatGun", false)
end

function Heatgun.OnDeselected(Context)
	Context.SetUsing(false)
	Setemitter(Context, false)
	Core:GetController("FeedbackController"):SetLoop("HeatGun", false)
end

return Heatgun
