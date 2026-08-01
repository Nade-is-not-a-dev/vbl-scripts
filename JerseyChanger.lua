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

-- ---------- team color mapping ----------
local TEAM_COLORS = {
	{ "Red Team", Color3.fromRGB(255, 48, 48) },
	{ "Purple Team", Color3.fromRGB(170, 0, 255) },
	{ "White Team", Color3.fromRGB(255, 255, 255) },
	{ "Black Team", Color3.fromRGB(56, 70, 79) },
	{ "Orange Team", Color3.fromRGB(255, 162, 0) },
}
local function nearestTeamName()
	local team = lp.Team
	if not team or not team.TeamColor then return nil end
	local c = team.TeamColor.Color
	local best, bestD = nil, math.huge
	for _, v in ipairs(TEAM_COLORS) do
		local d = (v[2].R - c.R) ^ 2 + (v[2].G - c.G) ^ 2 + (v[2].B - c.B) ^ 2
		if d < bestD then
			bestD = d
			best = v[1]
		end
	end
	return best
end
local function resolveTeamName(text)
	if not text or text == "" then return nil end
	local u = text:upper()
	if u == "RANDOM" then return nil end
	if u == "AUTO" then return nearestTeamName() end
	return text
end

-- ---------- deep logging ----------
local LOG_PATH = "JerseyChanger_log.txt"
local logbuf = {}
local function now()
	local ok, s = pcall(os.date, "%H:%M:%S")
	return ok and s or tostring(os.time())
end
local function log(msg)
	table.insert(logbuf, "[" .. now() .. "] " .. tostring(msg))
	if #logbuf > 300 then table.remove(logbuf, 1) end
	pcall(writefile, LOG_PATH, table.concat(logbuf, "\n"))
end
log("=== JerseyChanger started === selectedId=" .. tostring(selectedId))

local RARITY_COLORS = {
	[-2] = Color3.fromRGB(255, 70, 90),
	[-1] = Color3.new(1, 1, 1),
	[0] = Color3.fromRGB(255, 90, 180),
	[1] = Color3.fromRGB(255, 200, 60),
	[2] = Color3.fromRGB(255, 130, 40),
	[3] = Color3.fromRGB(200, 110, 255),
	[4] = Color3.fromRGB(90, 160, 255),
	[5] = Color3.fromRGB(200, 205, 210),
}
local function rarityColor(r)
	return RARITY_COLORS[r] or Color3.fromRGB(220, 220, 220)
end

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
						rarity = item.Rarity,
						renderId = item.Metadata and item.Metadata.RenderId or nil,
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
local appliedShirt = nil

local function captureShirt()
	appliedShirt = nil
	local char = lp.Character
	if char then
		local s = char:FindFirstChildOfClass("Shirt")
		if s then
			appliedShirt = { t = s.Texture, m = s.Mesh }
		end
	end
end

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
		local teamName = resolveTeamName(teamBox and teamBox.Text or "")
		if teamName then
			setArgs.TeamName = teamName
		end
		JerseyTool.set(setArgs)
	end)
	applyBusy = false
	if ok then
		selectedId = id
		captureShirt()
		log("APPLY ok id=" .. tostring(id)
			.. " team=" .. tostring(teamBox and teamBox.Text or "?")
			.. " shirt=" .. tostring(appliedShirt and appliedShirt.t or "none"))
	else
		status.Text = "Apply failed: " .. tostring(err)
		log("APPLY FAILED: " .. tostring(err))
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
local teams = { "RANDOM", "AUTO", "White Team", "Red Team", "Purple Team", "Orange Team", "Black Team" }
local teamIndex = 1
local teamBox = GUI.Input(frame, "RANDOM", UDim2.new(0, 44, 0, 58), UDim2.new(1, -54, 0, 26))
local teamCycleBtn = GUI.Button(frame, "COLOR", UDim2.new(0, 10, 0, 58), UDim2.new(0, 30, 0, 26))
local prevBtn = GUI.Button(frame, "<", UDim2.new(0, 10, 0, 92), UDim2.new(0, 30, 0, 26))
local nextBtn = GUI.Button(frame, ">", UDim2.new(0, 44, 0, 92), UDim2.new(0, 30, 0, 26))
local listBtn = GUI.Button(frame, "LIST", UDim2.new(0, 78, 0, 92), UDim2.new(0, 42, 0, 26))
local applyBtn = GUI.Button(frame, "APPLY", UDim2.new(0, 124, 0, 92), UDim2.new(0, 80, 0, 26), { color = GUI.Theme.success })
local resetBtn = GUI.Button(frame, "RESET", UDim2.new(0, 208, 0, 92), UDim2.new(0, 52, 0, 26), { color = GUI.Theme.danger })

teamCycleBtn.MouseButton1Click:Connect(function()
	teamIndex = teamIndex % #teams + 1
	teamBox.Text = teams[teamIndex]
end)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -16, 0, 14)
hint.Position = UDim2.new(0, 8, 1, -42)
hint.BackgroundTransparency = 1
hint.Text = "COLOR = variant | AUTO = follow team | RANDOM = any"
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

local function applyById(id)
	if applyJersey(id) then
		status.Text = "Jersey -> " .. id
		config.JerseyChanger = { selected = id, team = teamBox.Text }
		saveConfig()
		GUI.Notify("Jersey applied: " .. id, "success")
		return true
	end
	GUI.Notify("Apply failed: " .. id, "error")
	return false
end

applyBtn.MouseButton1Click:Connect(function()
	applyById(nameBox.Text)
end)

resetBtn.MouseButton1Click:Connect(function()
	restoreJersey()
	GUI.Notify("Real jersey restored", "info")
end)

-- ---------- preview list (dropdown) ----------
local previewItems = {}
local previewList = GUI.PreviewList({
	parent = win.Root,
	position = UDim2.fromOffset(20, win.Root.AbsoluteSize.Y + 4),
	width = 240,
	height = 320,
	title = "Jerseys",
	items = previewItems,
	onPick = function(id)
		nameBox.Text = id
		applyById(id)
	end,
})
listBtn.MouseButton1Click:Connect(function()
	if #jerseys == 0 then return end
	if #previewItems == 0 then
		for _, j in ipairs(jerseys) do
			local entry = {
				id = j.id,
				name = j.name,
				color = rarityColor(j.rarity),
				build = function()
					local teamName = resolveTeamName(teamBox and teamBox.Text or "") or "White Team"
					return GUI.BuildJerseyView(j.renderId or j.id, teamName)
				end,
				camCFrame = CFrame.lookAt(Vector3.new(0, 1.8, 2.9), Vector3.new(0, 1, 0)),
			}
			table.insert(previewItems, entry)
		end
	end
	previewList.Open()
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
			if not applyBusy then
				log("HOOK(game) set called: id=" .. tostring(p9.Id)
					.. " team=" .. tostring(p9.TeamName)
					.. " (we force id=" .. tostring(selectedId)
					.. " team=" .. tostring(teamBox and teamBox.Text or "?"))
			end
			p9.Id = selectedId
			local teamName = resolveTeamName(teamBox and teamBox.Text or "")
			if teamName then
				p9.TeamName = teamName
			end
			local sName, sNumber = getStyleInfo()
			if sName and sNumber then
				p9.Name = sName
				p9.Number = sNumber
			end
		end
		return origSet(p9)
	end))
	log("HOOK installed on JerseyTool.set")
end

-- watchdog: detect when the game replaces our shirt/jersey on the character
task.spawn(function()
	local tickCount = 0
	while true do
		task.wait(5)
		tickCount = tickCount + 1
		local char = lp.Character
		if char then
			local s = char:FindFirstChildOfClass("Shirt")
			local t = s and s.Texture or "none"
			if appliedShirt and t ~= appliedShirt.t then
				log("OVERRIDE: shirt changed " .. tostring(appliedShirt.t) .. " -> " .. tostring(t))
				if selectedId then
					applyJersey(selectedId)
				end
			end
			local jb = char:FindFirstChild("JerseyBack")
			if not jb and selectedId then
				log("OVERRIDE: JerseyBack missing, re-applying")
				applyJersey(selectedId)
			end
			if tickCount % 12 == 0 then
				log("WATCH: shirt=" .. tostring(t)
					.. " jerseyBack=" .. tostring(jb and "yes" or "no")
					.. " selected=" .. tostring(selectedId))
			end
		end
	end
end)
