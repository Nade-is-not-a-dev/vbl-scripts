-- VBL GUI Framework v2 (simple)
-- Plain, reliable GUI: flat rounded windows with a title bar, minimize/close,
-- drag support. Notifications use Roblox's built-in SetCore notifications.

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui")

local GUI = {}

GUI.Version = "1.1.0"
GUI.Log = function() end

local function normalizeAssetURL(s)
	if type(s) ~= "string" or s == "" then return s end
	local id = s:match("asset/?%?id=(%d+)")
	if id then
		return "rbxassetid://" .. id
	end
	return s
end

GUI.Theme = {
	bg = Color3.fromRGB(12, 12, 16),
	panel = Color3.fromRGB(20, 20, 25),
	elevated = Color3.fromRGB(40, 40, 50),
	border = Color3.fromRGB(38, 43, 56),
	text = Color3.fromRGB(230, 233, 240),
	dim = Color3.fromRGB(150, 150, 160),
	accent = Color3.fromRGB(96, 148, 255),
	success = Color3.fromRGB(60, 160, 90),
	warn = Color3.fromRGB(240, 180, 70),
	danger = Color3.fromRGB(190, 70, 70),
	input = Color3.fromRGB(12, 12, 16),
	surface = Color3.fromRGB(30, 30, 38),
	hover = Color3.fromRGB(45, 48, 58),
	disabled = Color3.fromRGB(25, 26, 32),
	shadow = Color3.fromRGB(8, 8, 12),
	focus = Color3.fromRGB(130, 170, 255),
	surfaceHover = Color3.fromRGB(40, 42, 52),
}

-- ---------- theme helpers ----------
local function isColor3(v)
	if type(v) == "userdata" then
		local ok = pcall(function()
			local r, g, b = v.R, v.G, v.B
			if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
				error("not a Color3", 0)
			end
		end)
		return ok
	end
	if type(v) == "table" then
		return type(v.R) == "number" and type(v.G) == "number" and type(v.B) == "number"
	end
	return false
end

function GUI.Token(name, fallback)
	local v = GUI.Theme[name]
	if isColor3(v) then return v end
	if fallback ~= nil then return fallback end
	return GUI.Theme.panel
end

function GUI.hoverColor(base)
	local ok, result = pcall(function()
		if not isColor3(base) then
			return GUI.Theme.hover
		end
		return base:Lerp(Color3.new(1, 1, 1), 0.18)
	end)
	if ok and isColor3(result) then
		return result
	end
	return GUI.Theme.hover
end

local function rounded(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = inst
	return c
end

-- ---------- window ----------
function GUI.Window(opts)
	opts = opts or {}
	local size = opts.size or Vector2.new(280, 220)
	local titleText = opts.title or "VBL"
	local basePos = opts.position or UDim2.new(0.5, -size.X / 2, 0, opts.y or 30)

	local gui = Instance.new("ScreenGui")
	gui.Name = opts.name or "VBLWindow"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	gui.Parent = opts.parent or pg

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromOffset(size.X, size.Y)
	root.Position = basePos
	root.BackgroundColor3 = GUI.Theme.panel
	root.BackgroundTransparency = 1 -- t5: fade-in starts transparent
	root.BorderSizePixel = 1
	root.BorderColor3 = GUI.Theme.shadow -- t5: soft shadow border (token)
	root.Active = true
	rounded(root, 10)
	root.Parent = gui

	local titlebar = Instance.new("Frame")
	titlebar.Name = "WinTitlebar" -- t5: named for fade/hover testing
	titlebar.Size = UDim2.new(1, 0, 0, 30)
	titlebar.BackgroundColor3 = GUI.Theme.elevated
	titlebar.BackgroundTransparency = 1 -- t5: fades in with root
	titlebar.BorderSizePixel = 0
	rounded(titlebar, 10)
	titlebar.Parent = root

	local titleFix = Instance.new("Frame")
	titleFix.Size = UDim2.new(1, 0, 0, 12)
	titleFix.Position = UDim2.new(0, 0, 1, -12)
	titleFix.BackgroundColor3 = GUI.Theme.elevated
	titleFix.BorderSizePixel = 0
	titleFix.Parent = titlebar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -64, 1, 0)
	titleLabel.Position = UDim2.new(0, 12, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = titleText
	titleLabel.TextColor3 = GUI.Theme.text
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 13
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titlebar

	local function titleBtn(text, xOff, danger)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 24, 0, 22)
		b.Position = UDim2.new(1, xOff, 0.5, -11)
		local base = danger and GUI.Theme.danger or GUI.Theme.bg
		b.BackgroundColor3 = base
		b.BorderSizePixel = 0
		b.Text = text
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 14
		b.AutoButtonColor = false
		b.Name = danger and "WinClose" or "WinMin" -- t5: named for hover/consistency
		rounded(b, 6)
		b.Parent = titlebar
		-- t5: titlebar button hover (close → danger family, minimize → hover token)
		b.MouseEnter:Connect(function()
			GUI.Animate(b, { BackgroundColor3 = danger and GUI.hoverColor(GUI.Theme.danger) or GUI.Theme.hover }, 0.1)
		end)
		b.MouseLeave:Connect(function()
			GUI.Animate(b, { BackgroundColor3 = base }, 0.1)
		end)
		return b
	end

	local closeBtn = titleBtn("X", -30, true)
	local minBtn = titleBtn("-", -58, false)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 1, -30)
	content.Position = UDim2.new(0, 0, 0, 30)
	content.BackgroundTransparency = 1
	content.Parent = root

	local logo = Instance.new("TextButton")
	logo.Name = "Logo"
	logo.Size = UDim2.fromOffset(38, 38)
	logo.Position = basePos + UDim2.new(0, 8, 0, 8)
	logo.BackgroundColor3 = GUI.Theme.accent
	logo.BorderSizePixel = 0
	logo.Text = ""
	logo.AutoButtonColor = false
	logo.Active = true
	logo.Visible = false
	rounded(logo, 19)
	logo.Parent = gui

	local logoLabel = Instance.new("TextLabel")
	logoLabel.Size = UDim2.new(1, 0, 1, 0)
	logoLabel.BackgroundTransparency = 1
	logoLabel.Text = opts.icon or "🏐"
	logoLabel.TextColor3 = Color3.new(1, 1, 1)
	logoLabel.Font = Enum.Font.GothamBold
	logoLabel.TextSize = 20
	logoLabel.Parent = logo

	local window = {
		Root = root,
		Content = content,
		Title = titleLabel,
		Gui = gui,
		Logo = logo,
		_closed = false,
	}

	local minimized = false
	local function setMinimized(min)
		minimized = min
		root.Visible = not min
		logo.Visible = min
		if min then
			logo.Position = root.Position + UDim2.new(0, 8, 0, 8)
		end
	end

	window.Close = function()
		if window._closed then return end
		window._closed = true
		if opts.OnClose then pcall(opts.OnClose) end
		-- t5: fade out first, hide only after fade completes (task.delay guard)
		GUI.Animate(root, { BackgroundTransparency = 1 }, 0.12)
		GUI.Animate(titlebar, { BackgroundTransparency = 1 }, 0.12)
		task.delay(0.12, function()
			if window._closed then
				root.Visible = false
				logo.Visible = false
			end
		end)
	end

	window.ToggleMinimize = function() setMinimized(not minimized) end
	window.Minimize = function() setMinimized(true) end
	window.Restore = function() setMinimized(false) end
	window.SetTitle = function(t) titleLabel.Text = t end

	closeBtn.MouseButton1Click:Connect(window.Close)
	minBtn.MouseButton1Click:Connect(window.ToggleMinimize)

	logo.MouseButton1Click:Connect(function()
		if not window._closed then
			setMinimized(false)
		end
	end)

	local dragging = false
	local dragStart, startPos
	local logoDragging = false
	local logoDragStart, logoStartPos
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
	logo.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			logoDragging = true
			logoDragStart = input.Position
			logoStartPos = logo.Position
		end
	end)
	logo.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			logoDragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			root.Position = startPos + UDim2.new(0, delta.X, 0, delta.Y)
		end
		if logoDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - logoDragStart
			logo.Position = logoStartPos + UDim2.new(0, delta.X, 0, delta.Y)
		end
	end)

	-- t5: fade in on open (GUI.Animate pcall-safe; instant-assign when no TweenService)
	GUI.Animate(root, { BackgroundTransparency = 0 }, 0.15)
	GUI.Animate(titlebar, { BackgroundTransparency = 0 }, 0.15)

	return window
end

-- ---------- widgets ----------
function GUI.Button(parent, text, pos, size, opts)
	opts = opts or {}
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	local base = opts.color or GUI.Theme.elevated
	b.BackgroundColor3 = base
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = opts.textColor or GUI.Theme.text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = opts.textSize or 11
	b.AutoButtonColor = false
	rounded(b, opts.radius or 6)
	b.Parent = parent

	-- t4 restyle: hover/press feedback via GUI.Animate (public tween, 0.1s)
	-- (local `tween` T2 declared later in the file is lexically out of scope here)
	local function setBg(c)
		GUI.Animate(b, { BackgroundColor3 = c }, 0.1)
	end
	local function darkColor()
		local dark = nil
		local ok = pcall(function()
			dark = base:Lerp(Color3.new(0, 0, 0), 0.2)
		end)
		if not ok or not isColor3(dark) then
			dark = GUI.Theme.disabled
		end
		return dark
	end
	b.MouseEnter:Connect(function() setBg(GUI.hoverColor(base)) end)
	b.MouseLeave:Connect(function() setBg(base) end)
	b.MouseButton1Down:Connect(function() setBg(darkColor()) end)
	b.MouseButton1Up:Connect(function() setBg(GUI.hoverColor(base)) end)
	return b
end

function GUI.Input(parent, default, pos, size, opts)
	opts = opts or {}
	local b = Instance.new("TextBox")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = GUI.Theme.input
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

	-- t4 restyle: focus border state (GUI.Theme.focus on focus, normal border on blur)
	local function setBorder(c, px)
		GUI.Animate(b, { BorderColor3 = c, BorderSizePixel = px or 1 }, 0.1)
	end
	b.Focused:Connect(function() setBorder(GUI.Theme.focus, 1) end)
	b.FocusLost:Connect(function() setBorder(GUI.Theme.border, 0) end)
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

-- ---------- t2: tabs, checkbox, toggle ----------
local function tween(inst, props, dur)
	local ok = pcall(function()
		local ts = game:GetService("TweenService")
		local tw = ts:Create(inst, TweenInfo.new(dur or 0.12), props)
		tw:Play()
	end)
	if not ok then
		for k, v in pairs(props) do
			inst[k] = v
		end
	end
end

function GUI.Tabs(opts)
	opts = opts or {}
	local tabs = opts.tabs or {}
	local n = #tabs

	local function tabName(t, j)
		if type(t) == "table" then return t.name or ("Tab " .. j) end
		return tostring(t)
	end
	local function tabContent(t)
		return type(t) == "table" and t.content or nil
	end

	local size = opts.size or UDim2.new(1, 0, 0, 32)

	local root = Instance.new("Frame")
	root.Name = "Tabs"
	root.Size = size
	root.Position = opts.position or UDim2.fromOffset(0, 0)
	root.BackgroundTransparency = 1
	root.Parent = opts.parent or pg

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(1, 0, 0, 32)
	bar.BackgroundColor3 = GUI.Theme.surface
	bar.BorderSizePixel = 0
	rounded(bar, 8)
	bar.Parent = root

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 0, 0)
	content.Position = UDim2.new(0, 0, 0, 36)
	content.BackgroundTransparency = 1
	content.Parent = root
	if size.Y and (size.Y.Scale > 0 or size.Y.Offset > 36) then
		content.Size = UDim2.new(1, 0, 1, -36)
	end

	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(1 / math.max(n, 1), 0, 0, 3)
	indicator.Position = UDim2.new(0, 0, 1, -3)
	indicator.BackgroundColor3 = GUI.Theme.accent
	indicator.BorderSizePixel = 0
	rounded(indicator, 2)
	indicator.Parent = bar

	local buttons = {}
	local hovered = {}
	local current = 1
	local api = {}

	local function paint(j)
		local b = buttons[j]
		if not b then return end
		local active = (j == current)
		b.TextColor3 = active and GUI.Theme.text or GUI.Theme.dim
		b.BackgroundColor3 = active and GUI.Theme.surfaceHover or (hovered[j] and GUI.Theme.hover or GUI.Theme.surface)
	end

	local function selectTab(i)
		if n == 0 then return end
		if i < 1 then i = 1 elseif i > n then i = n end
		if i == current then return end
		current = i
		api.Selected = i
		for j = 1, n do
			local c = tabContent(tabs[j])
			if c then c.Visible = (j == i) end
			paint(j)
		end
		tween(indicator, {
			Size = UDim2.new(1 / n, 0, 0, 3),
			Position = UDim2.new((i - 1) / n, 0, 1, -3),
		}, 0.15)
		local name = tabName(tabs[i], i)
		GUI.Log(("[TABS] selected %d: %s"):format(i, tostring(name)))
		if opts.onSelect then pcall(opts.onSelect, i, name) end
	end

	if n > 0 then
		for j = 1, n do
			local b = Instance.new("TextButton")
			b.Name = tabName(tabs[j], j)
			b.Size = UDim2.new(1 / n, 0, 1, 0)
			b.BackgroundColor3 = GUI.Theme.surface
			b.BorderSizePixel = 0
			b.Text = tabName(tabs[j], j)
			b.TextColor3 = GUI.Theme.dim
			b.Font = Enum.Font.GothamMedium
			b.TextSize = 12
			b.AutoButtonColor = false
			rounded(b, 6)
			b.Parent = bar
			b.MouseButton1Click:Connect(function() selectTab(j) end)
			b.MouseEnter:Connect(function()
				hovered[j] = true
				paint(j)
			end)
			b.MouseLeave:Connect(function()
				hovered[j] = false
				paint(j)
			end)
			buttons[j] = b
		end
		current = 1
		for j = 1, n do
			local c = tabContent(tabs[j])
			if c then
				c.Parent = content
				c.Visible = (j == 1)
			end
			paint(j)
		end
	end

	api.Frame = root
	api.Bar = bar
	api.Content = content
	api.Selected = current
	api.Select = function(i) selectTab(i) end
	return api
end

function GUI.Checkbox(parent, opts)
	opts = opts or {}
	local checked = not not opts.checked

	local root = Instance.new("Frame")
	root.Name = "Checkbox"
	root.Size = opts.size or UDim2.fromOffset(180, 24)
	root.Position = opts.position or UDim2.fromOffset(0, 0)
	root.BackgroundTransparency = 1
	root.Parent = parent

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.Size = UDim2.fromOffset(18, 18)
	box.Position = UDim2.new(0, 0, 0.5, -9)
	box.BackgroundColor3 = checked and GUI.Theme.accent or GUI.Theme.disabled
	box.BorderSizePixel = 0
	rounded(box, 4)
	box.Parent = root

	local check = Instance.new("TextLabel")
	check.Name = "Check"
	check.Size = UDim2.new(1, 0, 1, 0)
	check.BackgroundTransparency = 1
	check.Text = "✓"
	check.TextColor3 = GUI.Theme.text
	check.Font = Enum.Font.GothamBold
	check.TextSize = 12
	check.Visible = checked
	check.Parent = box

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -24, 1, 0)
	label.Position = UDim2.new(0, 24, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = opts.text or ""
	label.TextColor3 = checked and GUI.Theme.text or GUI.Theme.dim
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = root

	local btn = Instance.new("TextButton")
	btn.Name = "Hitbox"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = root

	local api = {}

	local function setChecked(v, fire)
		v = not not v
		if v == checked then return end
		checked = v
		api.Checked = checked
		check.Visible = checked
		tween(box, { BackgroundColor3 = checked and GUI.Theme.accent or GUI.Theme.disabled }, 0.12)
		label.TextColor3 = checked and GUI.Theme.text or GUI.Theme.dim
		GUI.Log(("[CHECKBOX] %s -> %s"):format(tostring(opts.text), tostring(checked)))
		if fire and opts.onChange then pcall(opts.onChange, checked) end
	end

	btn.MouseButton1Click:Connect(function() setChecked(not checked, true) end)
	btn.MouseEnter:Connect(function()
		tween(box, { BackgroundColor3 = checked and GUI.hoverColor(GUI.Theme.accent) or GUI.Theme.surfaceHover }, 0.1)
	end)
	btn.MouseLeave:Connect(function()
		tween(box, { BackgroundColor3 = checked and GUI.Theme.accent or GUI.Theme.disabled }, 0.1)
	end)

	api.Frame = root
	api.Box = box
	api.Check = check
	api.Label = label
	api.Checked = checked
	api.Set = function(v) setChecked(v, true) end
	api.Toggle = function() setChecked(not checked, true) end
	return api
end

function GUI.Toggle(parent, opts)
	opts = opts or {}
	local checked = not not opts.checked

	local root = Instance.new("Frame")
	root.Name = "Toggle"
	root.Size = opts.size or UDim2.fromOffset(180, 24)
	root.Position = opts.position or UDim2.fromOffset(0, 0)
	root.BackgroundTransparency = 1
	root.Parent = parent

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.fromOffset(40, 20)
	track.Position = UDim2.new(0, 0, 0.5, -10)
	track.BackgroundColor3 = checked and GUI.Theme.accent or GUI.Theme.disabled
	track.BorderSizePixel = 0
	rounded(track, 10)
	track.Parent = root

	local thumb = Instance.new("Frame")
	thumb.Name = "Thumb"
	thumb.Size = UDim2.fromOffset(16, 16)
	thumb.Position = UDim2.new(0, checked and 22 or 2, 0.5, -8)
	thumb.BackgroundColor3 = checked and GUI.Theme.text or GUI.Theme.dim
	thumb.BorderSizePixel = 0
	rounded(thumb, 8)
	thumb.Parent = track

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -48, 1, 0)
	label.Position = UDim2.new(0, 48, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = opts.text or ""
	label.TextColor3 = checked and GUI.Theme.text or GUI.Theme.dim
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = root

	local btn = Instance.new("TextButton")
	btn.Name = "Hitbox"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = root

	local api = {}

	local function setChecked(v, fire)
		v = not not v
		if v == checked then return end
		checked = v
		api.Checked = checked
		tween(track, { BackgroundColor3 = checked and GUI.Theme.accent or GUI.Theme.disabled }, 0.12)
		tween(thumb, {
			Position = UDim2.new(0, checked and 22 or 2, 0.5, -8),
			BackgroundColor3 = checked and GUI.Theme.text or GUI.Theme.dim,
		}, 0.12)
		label.TextColor3 = checked and GUI.Theme.text or GUI.Theme.dim
		GUI.Log(("[TOGGLE] %s -> %s"):format(tostring(opts.text), tostring(checked)))
		if fire and opts.onChange then pcall(opts.onChange, checked) end
	end

	btn.MouseButton1Click:Connect(function() setChecked(not checked, true) end)
	btn.MouseEnter:Connect(function()
		tween(track, { BackgroundColor3 = checked and GUI.hoverColor(GUI.Theme.accent) or GUI.Theme.surfaceHover }, 0.1)
	end)
	btn.MouseLeave:Connect(function()
		tween(track, { BackgroundColor3 = checked and GUI.Theme.accent or GUI.Theme.disabled }, 0.1)
	end)

	api.Frame = root
	api.Track = track
	api.Thumb = thumb
	api.Label = label
	api.Checked = checked
	api.Set = function(v) setChecked(v, true) end
	api.Toggle = function() setChecked(not checked, true) end
	return api
end

-- ---------- t3: slider, dropdown, tooltip ----------

-- GUI.Slider(parent, opts)
-- opts: position (UDim2), size (UDim2, default UDim2.new(1, -24, 0, 26)),
--       min (number, default 0), max (number, default 100), value (number, default min),
--       step (number, optional rounding), text (string, optional label), onChange(value)
-- drag: InputBegan jumps + starts drag, UserInputService.InputChanged moves, InputEnded stops
-- ratio = (x - trackOrigin) / trackWidth, clamped to [0, 1]
-- api: { Frame, Track, Fill, Knob, Label?, Value, Set(v), Get() }
function GUI.Slider(parent, opts)
	opts = opts or {}
	local pos = opts.position or UDim2.new(0, 12, 0, 12)
	local size = opts.size or UDim2.new(1, -24, 0, 26)
	local min = tonumber(opts.min) or 0
	local max = tonumber(opts.max) or 100
	local step = opts.step
	local value = tonumber(opts.value)
	if not value then value = min end
	if value < min then value = min elseif value > max then value = max end

	local root = Instance.new("Frame")
	root.Name = "Slider"
	root.Size = size
	root.Position = pos
	root.BackgroundTransparency = 1
	root.Parent = parent

	local label
	if opts.text then
		label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, 0, 0, 14)
		label.Position = UDim2.new(0, 2, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = opts.text
		label.TextColor3 = GUI.Theme.text
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 12
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = root
	end

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.new(0, 0, 1, -10)
	track.Size = UDim2.new(1, 0, 0, 4)
	track.BackgroundColor3 = GUI.Theme.disabled
	track.BorderSizePixel = 0
	rounded(track, 2)
	track.Parent = root

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = GUI.Theme.accent
	fill.BorderSizePixel = 0
	rounded(fill, 2)
	fill.Parent = track

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(14, 14)
	knob.Position = UDim2.new(0, -7, 0.5, -7)
	knob.BackgroundColor3 = GUI.Theme.text
	knob.BorderSizePixel = 0
	rounded(knob, 7)
	knob.Parent = track

	local api = {}

	local function ratio()
		if max <= min then return 0 end
		return (value - min) / (max - min)
	end

	local function trackWidth()
		local w = nil
		pcall(function() w = root.AbsoluteSize.X end)
		if type(w) ~= "number" or w <= 0 then
			w = nil
			pcall(function() w = size.X.Offset end)
		end
		return w or 0
	end

	local function trackOrigin()
		local x = nil
		pcall(function() x = root.AbsolutePosition.X end)
		if type(x) ~= "number" then
			x = nil
			pcall(function() x = pos.X.Offset end)
		end
		return x or 0
	end

	local function render()
		local r = ratio()
		if r < 0 then r = 0 elseif r > 1 then r = 1 end
		local w = trackWidth()
		if w <= 0 then w = 0 end
		local px = math.floor(w * r + 0.5)
		fill.Size = UDim2.new(0, px, 1, 0)
		knob.Position = UDim2.new(0, px - 7, 0.5, -7)
	end

	local function apply(v, fire)
		v = tonumber(v)
		if not v then return end
		if v < min then v = min elseif v > max then v = max end
		if step and step > 0 then
			v = min + math.floor((v - min) / step + 0.5) * step
			if v < min then v = min elseif v > max then v = max end
		end
		if v == value then
			render()
			return
		end
		value = v
		api.Value = value
		render()
		GUI.Log(("[SLIDER] %s -> %s"):format(tostring(opts.text or ""), tostring(value)))
		if fire and opts.onChange then pcall(opts.onChange, value) end
	end

	local dragging = false
	local function setFromInput(input)
		local x = input.Position and input.Position.X
		if type(x) ~= "number" then return end
		local w = trackWidth()
		if w <= 0 then return end
		local ox = trackOrigin()
		local r = (x - ox) / w
		if r < 0 then r = 0 elseif r > 1 then r = 1 end
		apply(min + (max - min) * r, true)
	end

	root.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromInput(input)
		end
	end)
	root.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
			setFromInput(input)
		end
	end)

	api.Frame = root
	api.Track = track
	api.Fill = fill
	api.Knob = knob
	api.Label = label
	api.Value = value
	api.Set = function(v) apply(v, true) end
	api.Get = function() return value end
	render()
	return api
end

-- GUI.Dropdown(parent, opts)
-- opts: position, size (default UDim2.new(1, -24, 0, 30)),
--       options (array of string | { name = ..., value = ... }), value (initial index or option value),
--       onChange(index, name)
-- api: { Frame, Header, Panel, Value, Selected, Select(i), Open(), Close(), Toggle() }
-- panel: elevated bg + border, rounded 8, ZIndex 20; click outside closes (best-effort)
function GUI.Dropdown(parent, opts)
	opts = opts or {}
	local pos = opts.position or UDim2.new(0, 12, 0, 12)
	local size = opts.size or UDim2.new(1, -24, 0, 30)
	local options = opts.options or {}
	local n = #options

	local function optionName(o, j)
		if type(o) == "table" then return tostring(o.name or o[1] or ("Option " .. j)) end
		return tostring(o)
	end
	local function optionValue(o)
		if type(o) == "table" then return o.value ~= nil and o.value or o.name end
		return o
	end

	local selected = 1
	if n > 0 then
		selected = tonumber(opts.value)
		if not selected then
			for j = 1, n do
				if optionValue(options[j]) == opts.value then
					selected = j
					break
				end
			end
		end
		if not selected or selected < 1 then selected = 1
		elseif selected > n then selected = n end
	end

	local root = Instance.new("Frame")
	root.Name = "Dropdown"
	root.Size = size
	root.Position = pos
	root.BackgroundTransparency = 1
	root.Parent = parent

	local header = Instance.new("TextButton")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 1, 0)
	header.BackgroundColor3 = GUI.Theme.surface
	header.BorderSizePixel = 0
	header.Text = ""
	header.TextColor3 = GUI.Theme.text
	header.Font = Enum.Font.GothamMedium
	header.TextSize = 12
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.AutoButtonColor = false
	rounded(header, 6)
	header.Parent = root

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Size = UDim2.new(0, 20, 1, 0)
	arrow.Position = UDim2.new(1, -20, 0, 0)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▾"
	arrow.TextColor3 = GUI.Theme.dim
	arrow.Font = Enum.Font.Gotham
	arrow.TextSize = 12
	arrow.Parent = header

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(1, 0, 0, 0)
	panel.Position = UDim2.new(0, 0, 1, 4)
	panel.BackgroundColor3 = GUI.Theme.elevated
	panel.BorderSizePixel = 1
	panel.BorderColor3 = GUI.Theme.border
	panel.ZIndex = 20
	panel.Visible = false
	rounded(panel, 8)
	panel.Parent = root

	local api = {}
	local open = false
	local items = {}

	local function paint()
		header.Text = n > 0 and ("  " .. optionName(options[selected], selected)) or ""
		for j = 1, n do
			local b = items[j]
			if b then
				local active = (j == selected)
				b.TextColor3 = active and GUI.Theme.accent or GUI.Theme.text
				b.BackgroundColor3 = active and GUI.Theme.surfaceHover or GUI.Theme.surface
			end
		end
	end

	local function close()
		open = false
		panel.Visible = false
		arrow.Text = "▾"
	end

	local function select(i, fire)
		if n == 0 then return end
		if i < 1 then i = 1 elseif i > n then i = n end
		selected = i
		api.Value = optionValue(options[i])
		api.Selected = i
		paint()
		close()
		GUI.Log(("[DROPDOWN] %s -> %d"):format(optionName(options[i], i), i))
		if fire and opts.onChange then pcall(opts.onChange, i, optionName(options[i], i)) end
	end

	if n > 0 then
		panel.Size = UDim2.new(1, 0, 0, 4 + n * 24 + 4)
		for j = 1, n do
			local b = Instance.new("TextButton")
			b.Name = "Item" .. j
			b.Size = UDim2.new(1, -8, 0, 24)
			b.Position = UDim2.new(0, 4, 0, 4 + (j - 1) * 24)
			b.BackgroundColor3 = GUI.Theme.surface
			b.BorderSizePixel = 0
			b.Text = "  " .. optionName(options[j], j)
			b.TextColor3 = GUI.Theme.text
			b.Font = Enum.Font.Gotham
			b.TextSize = 12
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.AutoButtonColor = false
			rounded(b, 4)
			b.Parent = panel
			b.MouseButton1Click:Connect(function() select(j, true) end)
			b.MouseEnter:Connect(function()
				b.BackgroundColor3 = GUI.Theme.surfaceHover
			end)
			b.MouseLeave:Connect(function()
				b.BackgroundColor3 = (j == selected) and GUI.Theme.surfaceHover or GUI.Theme.surface
			end)
			items[j] = b
		end
	end

	header.MouseButton1Click:Connect(function()
		open = not open
		panel.Visible = open
		arrow.Text = open and "▴" or "▾"
	end)

	-- click outside closes (best-effort geometry check)
	local function pointInFrame(f, x, y)
		local ap, as = f.AbsolutePosition, f.AbsoluteSize
		if not ap or not as then return false end
		if not ap.X or not ap.Y or not as.X or not as.Y then return false end
		return x >= ap.X and x <= ap.X + as.X and y >= ap.Y and y <= ap.Y + as.Y
	end
	UserInputService.InputBegan:Connect(function(input)
		if not open then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local p = input.Position
		if not p or not p.X or not p.Y then return end
		if pointInFrame(header, p.X, p.Y) then return end
		if pointInFrame(panel, p.X, p.Y) then return end
		close()
	end)

	paint()
	api.Frame = root
	api.Header = header
	api.Panel = panel
	api.Value = n > 0 and optionValue(options[selected]) or nil
	api.Selected = selected
	api.Select = function(i) select(i, true) end
	api.Open = function()
		open = true
		panel.Visible = true
		arrow.Text = "▴"
	end
	api.Close = close
	api.Toggle = function()
		if open then close() else api.Open() end
	end
	return api
end

-- GUI.Tooltip(parent, target, text)
-- parent: frame to parent the tooltip into; target: GuiObject to hover; text: string | function() -> string
-- auto-shows after ~0.5s hover (task.delay + guard), fades in, hides on MouseLeave
-- api: { Frame, Label, Show(), Hide(), SetText(t) }
function GUI.Tooltip(parent, target, text)
	local root = Instance.new("Frame")
	root.Name = "Tooltip"
	root.BackgroundColor3 = GUI.Theme.elevated
	root.BorderSizePixel = 1
	root.BorderColor3 = GUI.Theme.border
	root.BackgroundTransparency = 1
	root.ZIndex = 50
	root.Visible = false
	rounded(root, 6)
	root.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -12, 1, 0)
	label.Position = UDim2.new(0, 6, 0, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = GUI.Theme.text
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = root

	local api = {}
	local visible = false
	local scheduled = false

	local function currentText()
		local t = text
		if type(t) == "function" then
			local ok, res = pcall(t)
			if ok then t = res end
		end
		return tostring(t or "")
	end

	local function sizeToText()
		label.Text = currentText()
		local w = 60
		pcall(function()
			if label.TextBounds and label.TextBounds.X then
				w = label.TextBounds.X + 16
			end
		end)
		if type(w) ~= "number" or w < 40 then w = 60 end
		root.Size = UDim2.new(0, w, 0, 24)
	end

	local function show()
		if visible then return end
		visible = true
		root.Visible = true
		tween(root, { BackgroundTransparency = 0 }, 0.12)
		local ap = target and target.AbsolutePosition
		local x, y = 0, 0
		if ap and ap.X and ap.Y then
			x, y = ap.X, ap.Y - 30
		end
		root.Position = UDim2.new(0, x, 0, y)
		sizeToText()
	end

	local function hide()
		visible = false
		scheduled = false
		root.Visible = false
	end

	local function schedule()
		if visible then return end
		scheduled = true
		task.delay(0.5, function()
			if scheduled then
				scheduled = false
				show()
			end
		end)
	end

	api.Frame = root
	api.Label = label
	api.Show = show
	api.Hide = hide
	api.SetText = function(t)
		text = t
		sizeToText()
	end

	if target and target.MouseEnter and target.MouseEnter.Connect then
		target.MouseEnter:Connect(schedule)
	end
	if target and target.MouseLeave and target.MouseLeave.Connect then
		target.MouseLeave:Connect(hide)
	end
	return api
end

-- ---------- t4: spinner, animate, button/input feedback ----------
-- GUI.Animate(obj, props, duration): PUBLIC tween (pcall TweenService + instant-assign fallback). Returns obj (chainable).
function GUI.Animate(obj, props, duration)
	if not obj or type(props) ~= "table" then return obj end
	local ok = pcall(function()
		local ts = game:GetService("TweenService")
		local tw = ts:Create(obj, TweenInfo.new(duration or 0.12), props)
		tw:Play()
	end)
	if not ok then
		for k, v in pairs(props) do
			obj[k] = v
		end
	end
	return obj
end

-- GUI.Spinner(parent, opts): rotating loading indicator.
-- opts: position, size (default 20x20), color (default Theme.accent), speed (default 6 deg per 0.03s tick)
-- api: { Frame, Ring, Dot, Start(), Stop(), SetColor(c) }
function GUI.Spinner(parent, opts)
	opts = opts or {}
	local pos = opts.position or UDim2.new(0, 12, 0, 12)
	local size = opts.size or UDim2.new(0, 20, 0, 20)
	local speed = tonumber(opts.speed) or 6
	local color = opts.color or GUI.Theme.accent

	local root = Instance.new("Frame")
	root.Name = "Spinner"
	root.Size = size
	root.Position = pos
	root.BackgroundTransparency = 1
	root.Parent = parent

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.new(1, 0, 1, 0)
	ring.BackgroundTransparency = 1
	ring.BorderSizePixel = 2
	ring.BorderColor3 = color
	pcall(function()
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = ring
	end)
	ring.Parent = root

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.new(0, 4, 0, 4)
	dot.Position = UDim2.new(0.5, -2, 0, 0)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	pcall(function()
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = dot
	end)
	dot.Parent = root

	local api = {}
	local running = false

	local function tick()
		local r = root.Rotation
		if type(r) ~= "number" then r = 0 end
		pcall(function()
			root.Rotation = r + speed
		end)
	end

	local function loop()
		while running do
			tick()
			task.wait(0.03)
		end
	end

	api.Frame = root
	api.Ring = ring
	api.Dot = dot
	api.Start = function()
		if running then return end
		running = true
		task.spawn(loop)
	end
	api.Stop = function()
		running = false
	end
	api.SetColor = function(c)
		if c then
			color = c
			pcall(function()
				ring.BorderColor3 = c
				dot.BackgroundColor3 = c
			end)
		end
	end
	return api
end

-- ---------- item thumbnails (2D, straight from game assets) ----------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- returns { texture = rbxassetid or nil, color = Color3 or nil }
function GUI.JerseyThumbnail(assetName, teamName)
	if not assetName then return nil end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local jf = assets and assets:FindFirstChild("Jersey")
	if not jf then return nil end
	local asset = jf:FindFirstChild(assetName)
	if not asset then return nil end
	local folder = asset:FindFirstChild(teamName or "White Team")
	if not folder then
		for _, c in ipairs(asset:GetChildren()) do
			if c:IsA("Model") and c.Name:find("Team") then
				folder = c
				break
			end
		end
	end
	local texture, color = nil, nil
	local function pickTex(id)
		if not texture and type(id) == "string" and id ~= "" then
			texture = normalizeAssetURL(id)
		end
	end
	if folder then
		for _, c in ipairs(folder:GetChildren()) do
			if c:IsA("Shirt") then
				pcall(function() pickTex(c.ShirtTemplate) end)
				pcall(function() pickTex(c.Texture) end)
			elseif c:IsA("ShirtGraphic") then
				pcall(function() pickTex(c.Graphic) end)
			elseif c:IsA("Pants") then
				pcall(function() pickTex(c.PantsTemplate) end)
			elseif c:IsA("BasePart") then
				if not color then color = c.Color end
				local d = c:FindFirstChildOfClass("Decal")
				if d then pickTex(d.Texture) end
			end
		end
		if not color then
			for _, c in ipairs(folder:GetDescendants()) do
				if c:IsA("BasePart") then
					color = c.Color
					break
				end
			end
		end
	end
	GUI.Log(("[PREVIEW] %s: thumb=%s color=%s"):format(tostring(assetName), tostring(texture or "none"), tostring(color and ("%.3f,%.3f,%.3f"):format(color.R, color.G, color.B) or "none")))
	return { texture = texture, color = color }
end

-- returns { texture = rbxassetid or nil, color = Color3 or nil }
function GUI.BallThumbnail(id)
	if not id then return nil end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local bf = assets and assets:FindFirstChild("Ball")
	local model = bf and bf:FindFirstChild(id)
	if not model or not model:IsA("Model") then return nil end
	local texture, color = nil, nil
	local function pickTex(t)
		if not texture and type(t) == "string" and t ~= "" then
			texture = normalizeAssetURL(t)
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ImageLabel") then
			pcall(function() pickTex(d.Image) end)
		elseif d:IsA("Decal") then
			pickTex(d.Texture)
		elseif d:IsA("Texture") then
			pickTex(d.Texture)
		elseif d:IsA("MeshPart") then
			pickTex(d.TextureID)
		elseif d:IsA("BasePart") then
			if not color then color = d.Color end
		end
	end
	GUI.Log(("[PREVIEW] ball %s: thumb=%s color=%s"):format(tostring(id), tostring(texture or "none"), tostring(color and ("%.3f,%.3f,%.3f"):format(color.R, color.G, color.B) or "none")))
	return { texture = texture, color = color }
end

-- ---------- preview list (dropdown with 2D thumbnails) ----------
function GUI.PreviewList(opts)
	opts = opts or {}
	local w = opts.width or 240
	local h = opts.height or 300
	local list = Instance.new("Frame")
	list.Name = "PreviewList"
	list.Size = UDim2.fromOffset(w, h)
	list.Position = opts.position or UDim2.fromOffset(0, 0)
	list.BackgroundColor3 = GUI.Theme.panel
	list.BorderSizePixel = 0
	list.Visible = false
	list.ZIndex = 9
	rounded(list, 8)
	list.Parent = opts.parent or pg

	local head = Instance.new("Frame", list)
	head.Size = UDim2.new(1, 0, 0, 26)
	head.BackgroundColor3 = GUI.Theme.elevated
	head.BorderSizePixel = 0
	rounded(head, 8)
	local headFix = Instance.new("Frame", head)
	headFix.Size = UDim2.new(1, 0, 0, 10)
	headFix.Position = UDim2.new(0, 0, 1, -10)
	headFix.BackgroundColor3 = GUI.Theme.elevated
	headFix.BorderSizePixel = 0
	local headLabel = Instance.new("TextLabel", head)
	headLabel.Size = UDim2.new(1, -44, 1, 0)
	headLabel.Position = UDim2.fromOffset(10, 0)
	headLabel.BackgroundTransparency = 1
	headLabel.Text = opts.title or "List"
	headLabel.Font = Enum.Font.GothamBold
	headLabel.TextSize = 12
	headLabel.TextColor3 = GUI.Theme.text
	headLabel.TextXAlignment = Enum.TextXAlignment.Left
	local closeBtn = Instance.new("TextButton", head)
	closeBtn.Name = "PreviewClose"
	closeBtn.Size = UDim2.fromOffset(22, 18)
	closeBtn.Position = UDim2.new(1, -28, 0.5, -9)
	closeBtn.BackgroundColor3 = GUI.Theme.bg
	closeBtn.BorderSizePixel = 0
	closeBtn.AutoButtonColor = false
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 11
	rounded(closeBtn, 4)
	closeBtn.MouseEnter:Connect(function()
		GUI.Animate(closeBtn, { BackgroundColor3 = GUI.hoverColor(GUI.Theme.danger) }, 0.1)
	end)
	closeBtn.MouseLeave:Connect(function()
		GUI.Animate(closeBtn, { BackgroundColor3 = GUI.Theme.bg }, 0.1)
	end)

	local scroll = Instance.new("ScrollingFrame", list)
	scroll.Name = "PreviewScroll" -- t5: named for scrollbar token testing
	scroll.Position = UDim2.fromOffset(0, 28)
	scroll.Size = UDim2.fromOffset(w, h - 28)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarColor = GUI.Theme.surface
	scroll.ScrollBarImageColor3 = GUI.Theme.hover
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local layout = Instance.new("UIListLayout", scroll)
	layout.Padding = UDim.new(0, 3)

	local status = GUI.Label(list, "Memuat...", UDim2.new(0.5, -60, 0, 40), UDim2.fromOffset(120, 18), { align = Enum.TextXAlignment.Center })

	local built = false
	local function addRow(item, idx)
		local row = Instance.new("Frame", scroll)
		row.Name = "PreviewRow"
		row.Size = UDim2.fromOffset(w - 8, 46)
		row.BackgroundColor3 = GUI.Theme.surface
		row.BorderSizePixel = 0
		rounded(row, 6)
		local rowBase = item.selected and GUI.Theme.accent or GUI.Theme.surface
		if item.selected then
			GUI.Animate(row, { BackgroundColor3 = rowBase }, 0.14)
		end
		local img = Instance.new("ImageLabel", row)
		img.Position = UDim2.fromOffset(3, 3)
		img.Size = UDim2.fromOffset(40, 40)
		img.BackgroundColor3 = item.color or GUI.Theme.shadow
		img.BorderSizePixel = 0
		rounded(img, 4)
		img.ScaleType = Enum.ScaleType.Stretch
		if item.thumbnail then
			img.Image = item.thumbnail
		end
		local lbl = Instance.new("TextLabel", row)
		lbl.Position = UDim2.fromOffset(48, 0)
		lbl.Size = UDim2.fromOffset(w - 58, 46)
		lbl.BackgroundTransparency = 1
		lbl.Text = item.name or item.id or "?"
		lbl.TextColor3 = item.color or GUI.Theme.text
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 12
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		local btn = Instance.new("TextButton", row)
		btn.Name = "PreviewRowBtn"
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.MouseEnter:Connect(function()
			GUI.Animate(row, { BackgroundColor3 = item.selected and GUI.hoverColor(GUI.Theme.accent) or GUI.Theme.surfaceHover }, 0.1)
		end)
		btn.MouseLeave:Connect(function()
			GUI.Animate(row, { BackgroundColor3 = rowBase }, 0.1)
		end)
		btn.MouseButton1Click:Connect(function()
			list.Visible = false
			if opts.onPick then pcall(opts.onPick, item.id, item) end
		end)
	end

	local api = {
		Frame = list,
		Open = function()
			list.Visible = true
			if built then return end
			built = true
			GUI.Log(("[PREVIEW] list '%s': opening with %d items"):format(tostring(opts.title or "?"), #(opts.items or {})))
			task.spawn(function()
				local items = opts.items or {}
				for idx, item in ipairs(items) do
					addRow(item, idx)
					if idx % 6 == 0 then
						status.Text = ("Memuat %d/%d..."):format(idx, #items)
						task.wait()
					end
				end
				status.Visible = false
				GUI.Log(("[PREVIEW] list '%s': %d rows built"):format(tostring(opts.title or "?"), #items))
			end)
		end,
		Close = function() list.Visible = false end,
	}
	closeBtn.MouseButton1Click:Connect(api.Close)
	return api
end

-- ---------- notifications (Roblox built-in) ----------
function GUI.Notify(text, kind, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = kind == "success" and "Success"
				or (kind == "error" and "Error" or "Info"),
			Text = tostring(text),
			Duration = duration or 3,
		})
	end)
end

return GUI
