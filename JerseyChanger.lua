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
local _fw = httpGet("https://raw.githubusercontent.com/Nade-is-not-a-dev/vbl-scripts/main/vbl_framework.lua?cb=" .. tostring(os.time()))
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

local function getStyleInfo()
	local okState, State = pcall(require, ReplicatedStorage.Common.State)
	if not okState or type(State) ~= "table" then return nil, nil end
	local okId, styleId = pcall(function()
		return State.get(lp, State.Id.Gameplay, "Style")
	end)
	if not okId or not styleId then return nil, nil end
	local okStyle, Style = pcall(require, ReplicatedStorage.Content.Style)
	if not okStyle or type(Style) ~= "table" then return nil, nil end
	local okGet, style = pcall(function()
		return Style:Get(styleId)
	end)
	if not okGet or type(style) ~= "table" then return nil, nil end
	return style.DisplayName, style.Number
end

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
		local setArgs = { Character = char, Id = id, Player = lp }
		local sName, sNumber = getStyleInfo()
		if sName and sNumber then
			setArgs.Name = sName
			setArgs.Number = sNumber
		end
		if teamBox and teamBox.Text ~= "" and teamBox.Text:upper() ~= "RANDOM" then
			setArgs.TeamName = teamBox.Text
		end
		JerseyTool.set(setArgs)
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
		task.wait(2)
		if selectedId then
			applyJersey(selectedId)
		end
	end
end)

-- ---------- GUI (framework) ----------
local win = GUI.Window({
	title = "Jersey Changer",
	name = "JerseyChanger",
	icon = "JC",
	size = Vector2.new(280, 200),
	y = 90,
})
local frame = win.Content

local status = GUI.Label(frame, "Loading jerseys...", UDim2.new(0, 10, 0, 8), UDim2.new(1, -20, 0, 16))
local nameBox = GUI.Input(frame, "ClassicJersey", UDim2.new(0, 10, 0, 28), UDim2.new(1, -20, 0, 26))
local teams = { "RANDOM", "White Team", "Red Team", "Purple Team", "Orange Team", "Black Team" }
local teamIndex = 1
local teamBox = GUI.Input(frame, "RANDOM", UDim2.new(0, 44, 0, 58), UDim2.new(1, -54, 0, 26))
local teamCycleBtn = GUI.Button(frame, "COLOR", UDim2.new(0, 10, 0, 58), UDim2.new(0, 30, 0, 26))
local prevBtn = GUI.Button(frame, "<", UDim2.new(0, 10, 0, 92), UDim2.new(0, 30, 0, 26))
local nextBtn = GUI.Button(frame, ">", UDim2.new(0, 44, 0, 92), UDim2.new(0, 30, 0, 26))
local applyBtn = GUI.Button(frame, "APPLY", UDim2.new(0, 78, 0, 92), UDim2.new(0, 80, 0, 26), { color = GUI.Theme.success })
local resetBtn = GUI.Button(frame, "RESET", UDim2.new(0, 162, 0, 92), UDim2.new(0, 52, 0, 26), { color = GUI.Theme.danger })

teamCycleBtn.MouseButton1Click:Connect(function()
	teamIndex = teamIndex % #teams + 1
	teamBox.Text = teams[teamIndex]
end)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -16, 0, 14)
hint.Position = UDim2.new(0, 8, 1, -42)
hint.BackgroundTransparency = 1
hint.Text = "COLOR = jersey color variant | RANDOM = any color"
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
		config.JerseyChanger = { selected = id, team = teamBox.Text }
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
		if config.JerseyChanger.team and type(config.JerseyChanger.team) == "string"
		and config.JerseyChanger.team ~= "" then
			teamBox.Text = config.JerseyChanger.team
		end
		selectedId = saved
		applyJersey(saved)
		status.Text = "Restored saved jersey -> " .. saved
		GUI.Notify("Restored saved jersey: " .. saved, "success")
	end
end

-- ---------- JerseyTool.set hook ----------
-- any caller (including the game's own re-applies) gets our spoof forced,
-- so the color/id can never change under us
if JerseyTool and JerseyTool.set then
	local origSet = JerseyTool.set
	JerseyTool.set = hookfunction(origSet, newcclosure(function(p9)
		if type(p9) == "table" and selectedId then
			p9 = p9 or {}
			p9.Id = selectedId
			if teamBox and teamBox.Text ~= "" and teamBox.Text:upper() ~= "RANDOM" then
				p9.TeamName = teamBox.Text
			end
			local sName, sNumber = getStyleInfo()
			if sName and sNumber then
				p9.Name = sName
				p9.Number = sNumber
			end
		end
		return origSet(p9)
	end))
end
