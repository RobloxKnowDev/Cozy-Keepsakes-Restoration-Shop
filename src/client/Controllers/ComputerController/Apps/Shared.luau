local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FormatCurrency = require(ReplicatedStorage.Shared.Utils.CurrencyFormatter)

local Shared = {}
local ButtonTween = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ActiveButtonScale = 1.03
local NoticeText = "!"
local Topbarnotices = setmetatable({}, { __mode = "k" })
local Noticelabels = setmetatable({}, { __mode = "k" })

function Shared.SetTopbarNotice(Icon, Active: boolean)
	local Notice = Topbarnotices[Icon]
	if Notice and (not Active or Notice.Parent ~= Icon.parentIconUID) then
		Topbarnotices[Icon] = nil
		Icon:clearNotices()
		Notice.Clear:Fire()
		Notice = nil
	end
	if Active and not Notice then
		local Clear = Instance.new("BindableEvent")
		Topbarnotices[Icon] = { Clear = Clear, Parent = Icon.parentIconUID }
		Icon:notify(Clear.Event)
		if not Noticelabels[Icon] then
			local Label = Icon.notice:WaitForChild("NoticeLabel")
			Noticelabels[Icon] = Label
			Label:GetPropertyChangedSignal("Text"):Connect(function()
				if Label.Text ~= NoticeText then
					Label.Text = NoticeText
				end
			end)
		end
		Noticelabels[Icon].Text = NoticeText
	end
end

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

function Shared.ApplyActiveScale(Button: GuiButton, IsActive: boolean)
	TweenService:Create(Shared.EnsureScale(Button), ButtonTween, { Scale = if IsActive then ActiveButtonScale else 1 }):Play()
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

function Shared.AnimateNavButton(Button: GuiButton, IsSelected: () -> boolean): () -> ()
	local Scale = Shared.EnsureScale(Button)
	local IsHovering = false
	local function Refresh()
		local Target = if IsHovering then 1.06 elseif IsSelected() then ActiveButtonScale else 1
		TweenService:Create(Scale, ButtonTween, { Scale = Target }):Play()
	end
	Button.MouseEnter:Connect(function()
		IsHovering = true
		Refresh()
	end)
	Button.MouseLeave:Connect(function()
		IsHovering = false
		Refresh()
	end)
	Button.MouseButton1Down:Connect(function()
		TweenService:Create(Scale, ButtonTween, { Scale = 0.96 }):Play()
	end)
	Button.MouseButton1Up:Connect(Refresh)
	return Refresh
end

return Shared
