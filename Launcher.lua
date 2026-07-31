-- VBL Script Launcher (Volleyball Legends)
-- Fetches the script list from the GitHub repo and runs the one you pick.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local REPO = "Nade-is-not-a-dev/vbl-scripts"
local API_URL = "https://api.github.com/repos/" .. REPO .. "/contents/"
local RAW_URL = "https://raw.githubusercontent.com/" .. REPO .. "/main/"

local function fetch(url)
	if request then
		local ok, res = pcall(request, {
			Url = url,
			Method = "GET",
			Headers = { ["User-Agent"] = "Mozilla/5.0" },
		})
		if ok and res then
			if type(res) == "table" and res.Body then
				return res.Body
			end
			if type(res) == "string" then
				return res
			end
		end
	end
	local ok2, res2 = pcall(HttpService.GetAsync, HttpService, url)
	if ok2 and type(res2) == "string" then
		return res2
	end
	return nil
end

local function getScripts()
	local json = fetch(API_URL)
	if not json then return nil end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(data) ~= "table" then return nil end
	local list = {}
	for _, item in ipairs(data) do
		if type(item) == "table" and item.type == "file" and item.name:sub(-4) == ".lua"
		and item.name ~= "Launcher.lua" then
			table.insert(list, item.name)
		end
	end
	table.sort(list)
	return list
end

local function runScript(name)
	local code = fetch(RAW_URL .. name)
	if not code then return false end
	local fn, err = loadstring(code)
	if not fn then
		warn("Launcher: parse error in " .. name .. ": " .. tostring(err))
		return false
	end
	local ok, perr = xpcall(fn, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	if not ok then
		warn("Launcher: runtime error in " .. name .. "\n" .. tostring(perr))
		return false
	end
	return true
end

-- ---------- GUI ----------
local gui = Instance.new("ScreenGui")
gui.Name = "VBLLauncher"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 280, 0, 240)
frame.Position = UDim2.new(0.5, -140, 0, 30)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
title.BorderSizePixel = 0
title.Text = "VBL Script Launcher"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.Parent = frame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = title

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 12)
titleFix.Position = UDim2.new(0, 0, 1, -12)
titleFix.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
titleFix.BorderSizePixel = 0
titleFix.Parent = title

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 16)
status.Position = UDim2.new(0, 8, 0, 34)
status.BackgroundTransparency = 1
status.Text = "Loading script list..."
status.TextColor3 = Color3.fromRGB(220, 220, 220)
status.Font = Enum.Font.Code
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 100, 0, 24)
refreshBtn.Position = UDim2.new(0, 8, 0, 52)
refreshBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
refreshBtn.BorderSizePixel = 0
refreshBtn.Text = "REFRESH"
refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshBtn.Font = Enum.Font.GothamMedium
refreshBtn.TextSize = 11
refreshBtn.AutoButtonColor = false
refreshBtn.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 60, 0, 24)
closeBtn.Position = UDim2.new(0, 212, 0, 52)
closeBtn.BackgroundColor3 = Color3.fromRGB(190, 70, 70)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "CLOSE"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamMedium
closeBtn.TextSize = 11
closeBtn.AutoButtonColor = false
closeBtn.Parent = frame

local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, -16, 1, -88)
listFrame.Position = UDim2.new(0, 8, 0, 80)
listFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
listFrame.BorderSizePixel = 0
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.ScrollBarThickness = 4
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.Parent = frame

local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 6)
listCorner.Parent = listFrame

local function addScriptButton(name, index)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -8, 0, 26)
	b.Position = UDim2.new(0, 4, 0, (index - 1) * 30)
	b.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	b.BorderSizePixel = 0
	b.Text = name:gsub("%.lua$", "")
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 11
	b.AutoButtonColor = false
	b.Parent = listFrame

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 6)
	bc.Parent = b

	b.MouseButton1Click:Connect(function()
		status.Text = "Running " .. name .. "..."
		local ok = runScript(name)
		if ok then
			status.Text = "Started: " .. name
		else
			status.Text = "Failed: " .. name .. " (see console)"
		end
	end)
end

local function renderList()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local list = getScripts()
	if not list then
		status.Text = "Failed to fetch repo list"
		return
	end
	for i, name in ipairs(list) do
		addScriptButton(name, i)
	end
	status.Text = "Scripts: " .. #list
end

refreshBtn.MouseButton1Click:Connect(renderList)

closeBtn.MouseButton1Click:Connect(function()
	gui:Destroy()
end)

-- Draggable
local dragging = false
local dragStart, startPos

title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
	end
end)

title.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end
end)

renderList()
