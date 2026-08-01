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
		and item.name ~= "Launcher.lua"
		and item.name ~= "gui_framework.lua"
		and item.name ~= "vbl_framework.lua" then
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

-- ---------- GUI framework (fetched from repo) ----------
local _fw = fetch(RAW_URL .. "vbl_framework.lua?cb=" .. tostring(os.time()))
local GUI = _fw and loadstring(_fw)()
assert(GUI, "Failed to load GUI framework - check connection")

-- ---------- GUI (framework) ----------
local win = GUI.Window({
	title = "VBL Script Launcher",
	name = "VBLLauncher",
	icon = "VL",
	size = Vector2.new(280, 240),
	y = 30,
})
local frame = win.Content

local status = GUI.Label(frame, "Loading script list...", UDim2.new(0, 10, 0, 6), UDim2.new(1, -20, 0, 16))
local refreshBtn = GUI.Button(frame, "REFRESH", UDim2.new(0, 10, 0, 26), UDim2.new(0, 100, 0, 24))

local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, -20, 1, -66)
listFrame.Position = UDim2.new(0, 10, 0, 56)
listFrame.BackgroundColor3 = GUI.Theme.input
listFrame.BorderSizePixel = 0
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.ScrollBarThickness = 4
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.Parent = frame
local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 6)
listCorner.Parent = listFrame

local function addScriptButton(name, index)
	local b = GUI.Button(listFrame, name:gsub("%.lua$", ""),
		UDim2.new(0, 4, 0, (index - 1) * 30), UDim2.new(1, -8, 0, 26))
	b.MouseButton1Click:Connect(function()
		status.Text = "Running " .. name .. "..."
		local ok = runScript(name)
		if ok then
			status.Text = "Started: " .. name
			GUI.Notify("Started: " .. name, "success")
		else
			status.Text = "Failed: " .. name .. " (see console)"
			GUI.Notify("Failed to run: " .. name, "error")
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
		GUI.Notify("Failed to fetch repo list", "error")
		return
	end
	for i, name in ipairs(list) do
		addScriptButton(name, i)
	end
	status.Text = "Scripts: " .. #list
end

refreshBtn.MouseButton1Click:Connect(renderList)

renderList()
