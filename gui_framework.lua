-- VBL GUI Framework v1 (shared by vbl-scripts)
-- Modern window: rounded panels, gradients, smooth tweens, minimize/close,
-- drag support, and a built-in notification system with fade-in animations.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui")

local GUI = {}
GUI.NotifyQueue = {}
GUI.NotifyBusy = false

GUI.Theme = {
	bg = Color3.fromRGB(12, 14, 19),
	panel = Color3.fromRGB(18, 21, 28),
	elevated = Color3.fromRGB(26, 30, 40),
	border = Color3.fromRGB(38, 43, 56),
	text = Color3.fromRGB(230, 233, 240),
	dim = Color3.fromRGB(138, 144, 158),
	accent = Color3.fromRGB(96, 148, 255),
	accentDark = Color3.fromRGB(52, 92, 176),
	success = Color3.fromRGB(74, 204, 122),
	warn = Color3.fromRGB(240, 180, 70),
	danger = Color3.fromRGB(235, 96, 96),
}

local function tweenInfo(t, e, d)
	return TweenInfo.new(t, e or Enum.EasingStyle.Out, d or Enum.EasingDirection.InOut)
end

local function rounded(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = inst
	return c
end

local function gradient(inst, c1, c2, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rot or 90
	g.Parent = inst
	return g
end

-- ---------- window ----------
function GUI.Window(opts)
	opts = opts or {}
	local size = opts.size or Vector2.new(280, 220)
	local titleText = opts.title or "VBL"
	local accent = opts.accent or GUI.Theme.accent
	local basePos = opts.position or UDim2.new(0.5, -size.X / 2, 0, opts.y or 30)

	local gui = Instance.new("ScreenGui")
	gui.Name = opts.name or "VBLWindow"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	gui.Parent = opts.parent or pg

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromOffset(size.X + 10, size.Y + 10)
	shadow.Position = basePos + UDim2.new(0, 6, 0, 8)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.55
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	rounded(shadow, 16)
	shadow.Parent = gui

	local root = Instance.new("CanvasGroup")
	root.Name = "Root"
	root.Size = UDim2.fromOffset(size.X, size.Y)
	root.Position = basePos
	root.BackgroundColor3 = GUI.Theme.panel
	root.BorderSizePixel = 0
	root.GroupTransparency = 1
	rounded(root, 12)
	root.Parent = gui

	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(1, 0, 0, 3)
	accentBar.BackgroundColor3 = accent
	accentBar.BorderSizePixel = 0
	gradient(accentBar, accent, accent:Lerp(GUI.Theme.bg, 0.55), 0)
	rounded(accentBar, 12)
	accentBar.Parent = root

	local titlebar = Instance.new("Frame")
	titlebar.Size = UDim2.new(1, 0, 0, 34)
	titlebar.BackgroundColor3 = GUI.Theme.elevated
	titlebar.BorderSizePixel = 0
	gradient(titlebar, GUI.Theme.elevated, GUI.Theme.elevated:Lerp(GUI.Theme.bg, 0.4), 90)
	rounded(titlebar, 12)
	titlebar.Parent = root

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -64, 1, 0)
	titleLabel.Position = UDim2.new(0, 14, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = titleText
	titleLabel.TextColor3 = GUI.Theme.text
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 13
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titlebar

	local function titleBtn(text, xOff, danger)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 22, 0, 22)
		b.Position = UDim2.new(1, xOff, 0.5, -11)
		b.BackgroundColor3 = GUI.Theme.bg
		b.BorderSizePixel = 0
		b.Text = text
		b.TextColor3 = GUI.Theme.dim
		b.Font = Enum.Font.GothamBold
		b.TextSize = 12
		b.AutoButtonColor = false
		rounded(b, 6)
		b.Parent = titlebar
		local hoverIn = TweenService:Create(b, tweenInfo(0.15, Enum.EasingStyle.Out, Enum.EasingDirection.Quad), {
			BackgroundColor3 = danger and GUI.Theme.danger or GUI.Theme.accentDark,
			TextColor3 = Color3.new(1, 1, 1),
		})
		local hoverOut = TweenService:Create(b, tweenInfo(0.2, Enum.EasingStyle.Out, Enum.EasingDirection.Quad), {
			BackgroundColor3 = GUI.Theme.bg,
			TextColor3 = GUI.Theme.dim,
		})
		b.MouseEnter:Connect(function() hoverOut:Cancel() hoverIn:Play() end)
		b.MouseLeave:Connect(function() hoverIn:Cancel() hoverOut:Play() end)
		return b
	end

	local closeBtn = titleBtn("X", -28, true)
	local minBtn = titleBtn("-", -52, false)

	local content = Instance.new("CanvasGroup")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 1, -34)
	content.Position = UDim2.new(0, 0, 0, 34)
	content.BackgroundTransparency = 1
	content.Parent = root

	local window = {
		Root = root,
		Content = content,
		Title = titleLabel,
		Accent = accent,
		Gui = gui,
		_closed = false,
	}

	local minimized = false
	local function setMinimized(min, instant)
		minimized = min
		local t = instant and 0 or 0.22
		local sf = TweenService:Create(root, tweenInfo(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(size.X, min and 37 or size.Y),
		})
		local cf = TweenService:Create(content, tweenInfo(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			GroupTransparency = min and 1 or 0,
		})
		local sh = TweenService:Create(shadow, tweenInfo(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(size.X + 10, (min and 37 or size.Y) + 10),
		})
		sf:Play()
		cf:Play()
		sh:Play()
		cf.Completed:Connect(function(playback)
			if playback == Enum.PlaybackState.Completed then
				content.Visible = not min
			end
		end)
	end

	window.Open = function()
		root.Size = UDim2.fromOffset(size.X * 0.96, size.Y * 0.96)
		root.Position = basePos + UDim2.new(0, size.X * 0.02, 0, 6)
		TweenService:Create(root, tweenInfo(0.3, Enum.EasingStyle.Out, Enum.EasingDirection.Back), {
			Size = UDim2.fromOffset(size.X, size.Y),
		}):Play()
		TweenService:Create(root, tweenInfo(0.3, Enum.EasingStyle.Out, Enum.EasingDirection.Quad), {
			Position = basePos,
			GroupTransparency = 0,
		}):Play()
	end

	window.Close = function()
		if window._closed then return end
		window._closed = true
		local f = TweenService:Create(root, tweenInfo(0.2, Enum.EasingStyle.Out, Enum.EasingDirection.Quad), {
			GroupTransparency = 1,
		})
		local s = TweenService:Create(root, tweenInfo(0.2, Enum.EasingStyle.Out, Enum.EasingDirection.Quad), {
			Size = UDim2.fromOffset(size.X * 0.95, size.Y * 0.95),
		})
		f:Play()
		s:Play()
		if opts.OnClose then pcall(opts.OnClose) end
		task.delay(0.25, function()
			gui:Destroy()
		end)
	end

	window.ToggleMinimize = function() setMinimized(not minimized) end
	window.Minimize = function() setMinimized(true) end
	window.Restore = function() setMinimized(false) end
	window.SetTitle = function(t) titleLabel.Text = t end

	closeBtn.MouseButton1Click:Connect(window.Close)
	minBtn.MouseButton1Click:Connect(window.ToggleMinimize)

	local dragging = false
	local dragStart, startPos
	titlebar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = root.Position
		end
	end)
	titlebar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			root.Position = startPos + UDim2.new(0, delta.X, 0, delta.Y)
			shadow.Position = root.Position + UDim2.new(0, 6, 0, 8)
			shadow.Size = root.Size + UDim2.new(0, 10, 0, 10)
		end
	end)

	window.Open()
	return window
end

-- ---------- widgets ----------
function GUI.Button(parent, text, pos, size, opts)
	opts = opts or {}
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = opts.color or GUI.Theme.elevated
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = opts.textColor or GUI.Theme.text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = opts.textSize or 12
	b.AutoButtonColor = false
	rounded(b, opts.radius or 7)
	b.Parent = parent
	local base = opts.color or GUI.Theme.elevated
	local hoverIn = TweenService:Create(b, tweenInfo(0.15, Enum.EasingStyle.Out, Enum.EasingDirection.Quad), {
		BackgroundColor3 = base:Lerp(GUI.Theme.accent, 0.22),
	})
	local hoverOut = TweenService:Create(b, tweenInfo(0.2, Enum.EasingStyle.Out, Enum.EasingDirection.Quad), {
		BackgroundColor3 = base,
	})
	b.MouseEnter:Connect(function() hoverOut:Cancel() hoverIn:Play() end)
	b.MouseLeave:Connect(function() hoverIn:Cancel() hoverOut:Play() end)
	return b
end

function GUI.Input(parent, default, pos, size, opts)
	opts = opts or {}
	local b = Instance.new("TextBox")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = GUI.Theme.bg
	b.BorderSizePixel = 0
	b.Text = default or ""
	b.TextColor3 = GUI.Theme.text
	b.PlaceholderText = opts.placeholder or ""
	b.PlaceholderColor3 = GUI.Theme.dim
	b.Font = Enum.Font.Code
	b.TextSize = 11
	b.TextXAlignment = Enum.TextXAlignment.Center
	b.ClearTextOnFocus = false
	rounded(b, 6)
	b.Parent = parent
	return b
end

function GUI.Label(parent, text, pos, size, opts)
	opts = opts or {}
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = opts.color or GUI.Theme.dim
	l.Font = opts.font or Enum.Font.Code
	l.TextSize = opts.textSize or 11
	l.TextXAlignment = opts.align or Enum.TextXAlignment.Left
	l.TextWrapped = opts.wrap or false
	l.Parent = parent
	return l
end

-- ---------- notifications ----------
function GUI.Notify(text, kind, duration)
	table.insert(GUI.NotifyQueue, {
		text = tostring(text),
		kind = kind or "info",
		duration = duration or 3,
	})
	if not GUI.NotifyBusy then
		GUI.NotifyBusy = true
		GUI._notifyLoop()
	end
end

function GUI._notifyLoop()
	while #GUI.NotifyQueue > 0 do
		local item = table.remove(GUI.NotifyQueue, 1)
		local color = item.kind == "success" and GUI.Theme.success
			or (item.kind == "error" and GUI.Theme.danger or GUI.Theme.accent)

		local gui = Instance.new("ScreenGui")
		gui.Name = "VBLNotif"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 20
		gui.Parent = pg

		local n = Instance.new("CanvasGroup")
		n.Size = UDim2.fromOffset(260, 44)
		n.Position = UDim2.new(0.5, -130, 1, 70)
		n.BackgroundColor3 = GUI.Theme.panel
		n.BorderSizePixel = 0
		n.GroupTransparency = 1
		rounded(n, 10)
		n.Parent = gui

		local strip = Instance.new("Frame")
		strip.Size = UDim2.new(0, 4, 1, 0)
		strip.BackgroundColor3 = color
		strip.BorderSizePixel = 0
		rounded(strip, 10)
		strip.Parent = n

		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.new(1, -18, 1, 0)
		txt.Position = UDim2.new(0, 14, 0, 0)
		txt.BackgroundTransparency = 1
		txt.Text = item.text
		txt.TextColor3 = GUI.Theme.text
		txt.Font = Enum.Font.GothamMedium
		txt.TextSize = 12
		txt.TextXAlignment = Enum.TextXAlignment.Left
		txt.TextTruncate = Enum.TextTruncate.AtEnd
		txt.Parent = n

		local targetPos = UDim2.new(0.5, -130, 1, -60)
		n.Position = targetPos + UDim2.new(0, 0, 0, 14)
		TweenService:Create(n, tweenInfo(0.25, Enum.EasingStyle.Out, Enum.EasingDirection.Quad), {
			GroupTransparency = 0,
		}):Play()
		TweenService:Create(n, tweenInfo(0.32, Enum.EasingStyle.Out, Enum.EasingDirection.Back), {
			Position = targetPos,
		}):Play()

		task.wait(item.duration)

		local out = TweenService:Create(n, tweenInfo(0.25, Enum.EasingStyle.In, Enum.EasingDirection.Quad), {
			GroupTransparency = 1,
		})
		local outPos = TweenService:Create(n, tweenInfo(0.25, Enum.EasingStyle.In, Enum.EasingDirection.Quad), {
			Position = targetPos + UDim2.new(0, 0, 0, -10),
		})
		out:Play()
		outPos:Play()
		out.Completed:Wait()
		gui:Destroy()
	end
	GUI.NotifyBusy = false
end

return GUI
