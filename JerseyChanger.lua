-- Jersey Changer (client-side, Volleyball Legends)
-- Re-applies a jersey of your choice to your character using the game's
-- own Tools.Jersey module. Local-only: you see the chosen jersey,
-- other players see your real one. Re-applied on respawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

-- ---------- GUI framework (fetched from repo) ----------
local function httpGet(url)
	if request then
		local ok, res = pcall(request, {
			Url = url,
			Method = "GET",
			Headers = { ["User-Agent"] = "Mozilla/5.0" },
		})
		if ok then
			if type(res) == "table" and res.Body then return res.Body end
			if type(res) == "string" then return res end
		end
	end
	local ok2, body = pcall(function()
		return HttpService:GetAsync(url)
	end)
	if ok2 and type(body) == "string" then return body end
	return nil
end
local _fw = httpGet("https://raw.githubusercontent.com/Nade-is-not-a-dev/vbl-scripts/main/gui_framework.lua")
local GUI = _fw and loadstring(_fw)()
assert(GUI, "Failed to load GUI framework - check connection")

-- ---------- config ----------
local CONFIG_PATH = "VBLConfig.json"
local config = {}
pcall(function()
	if isfile and isfile(CONFIG_PATH) then
		local data = readfile(CONFIG_PATH)
		if type(data) == "string" and data ~= "" then
			config = HttpService:JSONDecode(data)
		end
	end
end)
local function saveConfig()
	if type(config) ~= "table" then config = {} end
	pcall(writefile, CONFIG_PATH, HttpService:JSONEncode(config))
end

local JerseyTool = nil
pcall(function()
	JerseyTool = require(ReplicatedStorage.Tools.Jersey)
end)

local jerseys = {}
local jerseyIndex = 0
local selectedId = nil

-- ---------- jersey list ----------
local function loadJerseys()
	jerseys = {}
	local itemModule = nil
	pcall(function()
		itemModule = require(ReplicatedStorage.Content.Item)
	end)
	local entities = ReplicatedStorage.Content.Item:FindFirstChild("Entities")
	if entities and itemModule and itemModule.Type then
		for _, child in ipairs(entities:GetChildren()) do
			if child:IsA("ModuleScript") then
				local ok, item = pcall(require, child)
				if ok and type(item) == "table" and item.Type == itemModule.Type.Jersey then
					table.insert(jerseys, {
						id = tostring(item.Id or child.Name),
						name = tostring(item.DisplayName or child.Name),
					})
				end
			end
		end
	end
	if #jerseys == 0 then
		local assets = ReplicatedStorage.Assets and ReplicatedStorage.Assets:FindFirstChild("Jersey")
		if assets then
			for _, child in ipairs(assets:GetChildren()) do
				table.insert(jerseys, { id = child.Name, name = child.Name })
			end
		end
	end
	table.sort(jerseys, function(a, b) return a.name < b.name end)
	for i, j in ipairs(jerseys) do
		if j.id == "ClassicJersey" then
			jerseyIndex = i
			break
		end
	end
	return #jerseys
end

-- ---------- apply ----------
local applyBusy = false

local function applyJersey(id)
	if applyBusy then return end
	applyBusy = true
	local ok, err = pcall(function()
		local char = lp.Character
		if not char or not char:FindFirstChildOfClass("Humanoid") then
			error("no character yet")
		end
		if not JerseyTool or not JerseyTool.set then
			error("Tools.Jersey not loaded")
		end
		JerseyTool.set({ Character = char, Id = id })
	end)
	applyBusy = false
	if ok then
		selectedId = id
	else
		status.Text = "Apply failed: " .. tostring(err)
	end
	return ok
end

local function restoreJersey()
	selectedId = nil
	pcall(function()
		local char = lp.Character
		if char and JerseyTool and JerseyTool._clear then
			JerseyTool._clear(char)
		end
	end)
	pcall(function()
		local knit = require(ReplicatedStorage.Packages.Knit)
		if knit and knit.GetService then
			local svc = knit.GetService("JerseyService")
			if svc and svc.RequestJerseyUpdate then
				svc:RequestJerseyUpdate()
			end
		end
	end)
	status.Text = "Restored - real jersey will return"
end

local function updateStatus()
	if selectedId then
		status.Text = "Jersey -> " .. selectedId
	else
		status.Text = "OFF - your real jersey shows"
	end
end

-- re-apply after respawn (new character arrives with your real jersey)
lp.CharacterAdded:Connect(function(char)
	task.spawn(function()
		for _ = 1, 20 do
			task.wait(0.3)
			if selectedId and char.Parent and char:FindFirstChildOfClass("Humanoid") then
				applyJersey(selectedId)
				return
			end
			if not selectedId then return end
		end
	end)
end)

-- safety sweep: the game may re-apply your real jersey (round start, team change)
task.spawn(function()
	while true do
		task.wait(5)
		if selectedId then
			applyJersey(selectedId)
		end
	end
end)

-- ---------- GUI (framework) ----------
local win = GUI.Window({
	title = "Jersey Changer",
	name = "JerseyChanger",
	size = Vector2.new(280, 200),
	y = 90,
	OnClose = restoreJersey,
})
local frame = win.Content

local status = GUI.Label(frame, "Loading jerseys...", UDim2.new(0, 10, 0, 8), UDim2.new(1, -20, 0, 16))
local nameBox = GUI.Input(frame, "ClassicJersey", UDim2.new(0, 10, 0, 28), UDim2.new(1, -20, 0, 26))
local prevBtn = GUI.Button(frame, "<", UDim2.new(0, 10, 0, 62), UDim2.new(0, 30, 0, 26))
local nextBtn = GUI.Button(frame, ">", UDim2.new(0, 44, 0, 62), UDim2.new(0, 30, 0, 26))
local applyBtn = GUI.Button(frame, "APPLY", UDim2.new(0, 78, 0, 62), UDim2.new(0, 80, 0, 26), { color = GUI.Theme.success })
local resetBtn = GUI.Button(frame, "RESET", UDim2.new(0, 162, 0, 62), UDim2.new(0, 52, 0, 26), { color = GUI.Theme.danger })

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -16, 0, 14)
hint.Position = UDim2.new(0, 8, 1, -42)
hint.BackgroundTransparency = 1
hint.Text = "APPLY = show this jersey on you"
hint.TextColor3 = Color3.fromRGB(150, 150, 160)
hint.Font = Enum.Font.Code
hint.TextSize = 9
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = frame

-- ---------- buttons ----------
prevBtn.MouseButton1Click:Connect(function()
	if #jerseys == 0 then return end
	jerseyIndex = jerseyIndex - 1
	if jerseyIndex < 1 then jerseyIndex = #jerseys end
	nameBox.Text = jerseys[jerseyIndex].id
	updateStatus()
end)

nextBtn.MouseButton1Click:Connect(function()
	if #jerseys == 0 then return end
	jerseyIndex = jerseyIndex + 1
	if jerseyIndex > #jerseys then jerseyIndex = 1 end
	nameBox.Text = jerseys[jerseyIndex].id
	updateStatus()
end)

applyBtn.MouseButton1Click:Connect(function()
	local id = nameBox.Text
	if applyJersey(id) then
		status.Text = "Jersey -> " .. id
		config.JerseyChanger = { selected = id }
		saveConfig()
		GUI.Notify("Jersey applied: " .. id, "success")
	else
		GUI.Notify("Apply failed: " .. id, "error")
	end
end)

resetBtn.MouseButton1Click:Connect(function()
	restoreJersey()
	GUI.Notify("Real jersey restored", "info")
end)

-- ---------- init ----------
local n = loadJerseys()
if n == 0 then
	status.Text = "No jerseys found"
else
	status.Text = "Jersey list: " .. n .. " | " .. (jerseys[jerseyIndex or 1]).id
	nameBox.Text = (jerseys[jerseyIndex or 1]).id
end
if not JerseyTool then
	status.Text = "Tools.Jersey not loaded - cannot spoof"
	GUI.Notify("Tools.Jersey not loaded - cannot spoof", "error")
end
local saved = config.JerseyChanger and config.JerseyChanger.selected
if saved and type(saved) == "string" then
	local found = false
	for _, j in ipairs(jerseys) do
		if j.id == saved then
			found = true
			break
		end
	end
	if found then
		nameBox.Text = saved
		selectedId = saved
		applyJersey(saved)
		status.Text = "Restored saved jersey -> " .. saved
		GUI.Notify("Restored saved jersey: " .. saved, "success")
	end
end
