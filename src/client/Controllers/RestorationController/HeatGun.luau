local Replicatedstorage = game:GetService("ReplicatedStorage")

local Core = require(Replicatedstorage.Shared.Packages.Core)

local Heatgun = {
	Name = "HeatGun",
	AssetName = "HeatGun",
}

local Sizescale = 2.5
local Cleanradius = 1.25 / Sizescale
local Liquidfolders = { "SolventLiquid", "PolishLiquid" }

local function Setemitter(Context, Enabled: boolean)
	local Emitter = Context.Display.Tip:WaitForChild("ParticleEmitter") :: ParticleEmitter
	Emitter.EmissionDirection = Enum.NormalId.Right
	Emitter.Enabled = Enabled
end

local function Cleanliquid(Context)
	local Display = Context.Display
	if not Context.Object or not Display.OnObject or not Display.SurfacePosition then
		return
	end
	local Spots = Context.Object:WaitForChild("RestorationSpots")
	for _, Foldername in ipairs(Liquidfolders) do
		local Folder = Spots:FindFirstChild(Foldername)
		if Folder then
			for _, Drop in ipairs(Folder:GetChildren()) do
				if Drop:IsA("BasePart") and (Drop.Position - Display.SurfacePosition).Magnitude <= Cleanradius then
					Drop:Destroy()
				end
			end
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
	if Context.Object then
		Core:GetController("CleaningController"):TryClean(Context.Object, Heatgun.Name)
		Cleanliquid(Context)
	end
end

function Heatgun.OnUpdate(Context)
	if Context.IsUsing and Context.Object then
		Core:GetController("CleaningController"):TryClean(Context.Object, Heatgun.Name)
		Cleanliquid(Context)
	end
end

function Heatgun.OnInputEnded(Context)
	Context.SetUsing(false)
	Setemitter(Context, false)
end

function Heatgun.OnDeselected(Context)
	Context.SetUsing(false)
	Setemitter(Context, false)
end

return Heatgun
