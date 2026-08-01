-- VBL GUI Framework v2 (simple)
-- Plain, reliable GUI: flat rounded windows with a title bar, minimize/close,
-- drag support. Notifications use Roblox's built-in SetCore notifications.

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui")

local GUI = {}

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
}

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
	root.BorderSizePixel = 0
	root.Active = true
	rounded(root, 10)
	root.Parent = gui

	local titlebar = Instance.new("Frame")
	titlebar.Size = UDim2.new(1, 0, 0, 30)
	titlebar.BackgroundColor3 = GUI.Theme.elevated
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
		b.BackgroundColor3 = danger and GUI.Theme.danger or GUI.Theme.bg
		b.BorderSizePixel = 0
		b.Text = text
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 14
		b.AutoButtonColor = false
		rounded(b, 6)
		b.Parent = titlebar
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

	local logo = Instance.new("Frame")
	logo.Name = "Logo"
	logo.Size = UDim2.fromOffset(38, 38)
	logo.Position = basePos + UDim2.new(0, 8, 0, 8)
	logo.BackgroundColor3 = GUI.Theme.accent
	logo.BorderSizePixel = 0
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
		root.Visible = false
		logo.Visible = false
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
	b.TextSize = opts.textSize or 11
	b.AutoButtonColor = false
	rounded(b, opts.radius or 6)
	b.Parent = parent
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
