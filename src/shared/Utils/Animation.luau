local Soundservice = game:GetService("SoundService")
local Typewrittersound = Soundservice:WaitForChild("TypeWritter")

local Uianimations = {}

local Tweenservice = game:GetService("TweenService")
local Tweenin = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Buttontweens = {}

function Uianimations.Scale(Frame, In)
	if Frame then
		local Uiscale = Frame:FindFirstChild("UIScale")
		if In then
			local Tween = Tweenservice:Create(Uiscale, Tweenin, { Scale = 1 })
			Tween:Play()
			return Tween
		elseif In == false then
			local Tween = Tweenservice:Create(Uiscale, Tweenin, { Scale = 0 })
			Tween:Play()
			return Tween
		end
	end
end

function Uianimations.Button(Button)
	if not (Button:IsA("TextButton") or Button:IsA("ImageButton")) then
		return
	end

	local Uiscale = Button:FindFirstChild("UIScale") or Instance.new("UIScale")
	Uiscale.Parent = Button

	local Currenttween
	local function Playtween(Scale)
		if Button:GetAttribute("DisableButtonAnimations") then
			return
		end

		if Currenttween then
			Currenttween:Cancel()
		end

		Currenttween = Tweenservice:Create(Uiscale, Tweenin, { Scale = Scale })
		Buttontweens[Button] = Currenttween
		Currenttween:Play()
	end

	local Ishovering = false

	Button.MouseEnter:Connect(function()
		Ishovering = true
		Playtween(1.1)
	end)

	Button.MouseLeave:Connect(function()
		Ishovering = false
		Playtween(1)
	end)

	Button.MouseButton1Down:Connect(function()
		Playtween(0.95)
	end)

	Button.MouseButton1Up:Connect(function()
		if Ishovering then
			Playtween(1.1)
		else
			Playtween(1)
		end
	end)
end

function Uianimations.StopButton(Button)
	Button:SetAttribute("DisableButtonAnimations", true)

	local Currenttween = Buttontweens[Button]
	if Currenttween then
		Currenttween:Cancel()
		Buttontweens[Button] = nil
	end
end

function Uianimations.WaitForTweens(Tweens)
	local Remaining = 0
	local Finished = Instance.new("BindableEvent")

	for _, Tween in pairs(Tweens) do
		if Tween and Tween.PlaybackState == Enum.PlaybackState.Playing then
			Remaining += 1
			Tween.Completed:Once(function()
				Remaining -= 1
				if Remaining == 0 then
					Finished:Fire()
				end
			end)
		end
	end

	if Remaining > 0 then
		Finished.Event:Wait()
	end

	Finished:Destroy()
end

function Uianimations.Fade(Frame, Fadein, Duration)
	Duration = Duration or 0.5
	local Goal = {}
	if Fadein then
		if Frame:IsA("TextLabel") or Frame:IsA("TextButton") then
			Goal.TextTransparency = 0
		elseif Frame:IsA("Frame") then
			Goal.BackgroundTransparency = 0
		end
	else
		Goal.BackgroundTransparency = 1
		if Frame:IsA("TextLabel") or Frame:IsA("TextButton") then
			Goal.TextTransparency = 1
		end
	end

	Tweenservice:Create(Frame, TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), Goal):Play()
	task.wait(Duration)
end

function Uianimations.TypeWritter(Textlabel: Textlabel, Message: string, Wait: number)
	local Wait = Wait or 0.05

	Textlabel.Text = ""
	Typewrittersound:Play()
	for I = 1, #Message do
		Textlabel.Text = string.sub(Message, 1, I)
		task.wait(Wait)
	end
	Typewrittersound:Stop()
	task.wait(4)
	Textlabel.Text = ""
end
return Uianimations
