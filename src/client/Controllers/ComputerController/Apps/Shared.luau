local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FormatCurrency = require(ReplicatedStorage.Shared.Utils.CurrencyFormatter)

local Shared = {}
local ButtonTween = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ActiveButtonScale = 1.03

function Shared.FormatCurrency(Value: number): string
	return FormatCurrency(Value)
end

function Shared.FormatProfit(Value: number): string
	local Rounded = math.round(Value * 100) / 100
	if Rounded < 0 then
		return "-" .. FormatCurrency(math.abs(Rounded))
	end
	return "+" .. FormatCurrency(Rounded)
end

function Shared.EnsureScale(Target: Instance): UIScale
	local Existing = Target:FindFirstChildOfClass("UIScale")
	if Existing then return Existing end
	local Scale = Instance.new("UIScale")
	Scale.Parent = Target
	return Scale
end

function Shared.AnimateButton(Button: GuiButton, IsActive: () -> boolean)
	local Scale = Shared.EnsureScale(Button)
	local IsHovering = false
	Button.MouseEnter:Connect(function()
		if IsActive() then return end
		IsHovering = true
		TweenService:Create(Scale, ButtonTween, { Scale = 1.06 }):Play()
	end)
	Button.MouseLeave:Connect(function()
		if IsActive() then return end
		IsHovering = false
		TweenService:Create(Scale, ButtonTween, { Scale = 1 }):Play()
	end)
	Button.MouseButton1Down:Connect(function()
		if IsActive() then return end
		TweenService:Create(Scale, ButtonTween, { Scale = 0.96 }):Play()
	end)
	Button.MouseButton1Up:Connect(function()
		if IsActive() then
			TweenService:Create(Scale, ButtonTween, { Scale = ActiveButtonScale }):Play()
			return
		end
		TweenService:Create(Scale, ButtonTween, { Scale = if IsHovering then 1.06 else 1 }):Play()
	end)
end

return Shared
