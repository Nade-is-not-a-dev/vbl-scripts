-- Player Card Spoofer (client-side, Volleyball Legends)
-- Swaps the PlayerCard shown on your score card (FlashPlayerCard) to any
-- other PlayerCard variant. Local-only: you see the chosen card design.

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

local cards = {}
local cardIndex = 0
local selectedId = nil

-- ---------- log ----------
local logbuf = {}
local function log(msg)
	table.insert(logbuf, tostring(msg))
	if #logbuf > 100 then table.remove(logbuf, 1) end
	pcall(writefile, "PlayerCardSpoofer_log.txt", table.concat(logbuf, "\n"))
end

-- ---------- card list ----------
local function loadCards()
	cards = {}
	local itemModule = nil
	pcall(function()
		itemModule = require(ReplicatedStorage.Content.Item)
	end)
	local entities = ReplicatedStorage.Content.Item:FindFirstChild("Entities")
	if entities and itemModule and itemModule.Type then
		for _, child in ipairs(entities:GetChildren()) do
			if child:IsA("ModuleScript") then
				local ok, item = pcall(require, child)
				if ok and type(item) == "table" and item.Type == itemModule.Type.PlayerCard then
					table.insert(cards, {
						id = tostring(item.Id or child.Name),
						name = tostring(item.DisplayName or child.Name),
					})
				end
			end
		end
	end
	table.sort(cards, function(a, b) return a.name < b.name end)
	return #cards
end

-- ---------- hook ----------
local function installHook()
	local ok, knit = pcall(require, ReplicatedStorage.Packages.Knit)
	if not ok or type(knit) ~= "table" then
		return false
	end
	local ok2, ctrl = pcall(function()
		return knit.GetController("PlayerCardController")
	end)
	if not ok2 or type(ctrl) ~= "table" or type(ctrl.DisplayFlashCard) ~= "function" then
		return false
	end
	local original = hookfunction(ctrl.DisplayFlashCard, newcclosure(function(self, p15)
		log("FLASH CALL: selectedId=" .. tostring(selectedId))
		if selectedId and type(p15) == "table" then
			local ok, err = pcall(function()
				local clone = {}
				for k, v in pairs(p15) do clone[k] = v end
				clone.PlayerCardItemId = selectedId
				original(self, clone)
			end)
			if not ok then
				log("HOOK ERR: " .. tostring(err))
				original(self, p15)
			end
			return
		end
		return original(self, p15)
	end))
	if original then log("HOOK installed OK") end
	return original ~= nil
end

-- retry until Knit is ready
local hookOk = false
task.spawn(function()
	for _ = 1, 10 do
		hookOk = installHook()
		if hookOk then
			break
		end
		task.wait(1)
	end
	if hookOk then
		status.Text = "Hooked PlayerCardController - READY"
		log("READY")
	else
		status.Text = "Hook FAILED - Knit not available?"
		log("HOOK FAILED after retries")
	end
end)

local function updateStatus()
	if selectedId then
		status.Text = "Card -> " .. selectedId
	else
		status.Text = "OFF - your real card shows"
	end
end

-- ---------- GUI (framework) ----------
local win = GUI.Window({
	title = "Player Card Spoofer",
	name = "PlayerCardSpoofer",
	icon = "PC",
	size = Vector2.new(280, 200),
	y = 90,
})
local frame = win.Content

local status = GUI.Label(frame, "Loading cards...", UDim2.new(0, 10, 0, 8), UDim2.new(1, -20, 0, 16))
local nameBox = GUI.Input(frame, "", UDim2.new(0, 10, 0, 28), UDim2.new(1, -20, 0, 26))
local prevBtn = GUI.Button(frame, "<", UDim2.new(0, 10, 0, 62), UDim2.new(0, 30, 0, 26))
local nextBtn = GUI.Button(frame, ">", UDim2.new(0, 44, 0, 62), UDim2.new(0, 30, 0, 26))
local applyBtn = GUI.Button(frame, "APPLY", UDim2.new(0, 78, 0, 62), UDim2.new(0, 80, 0, 26), { color = GUI.Theme.success })
local resetBtn = GUI.Button(frame, "RESET", UDim2.new(0, 162, 0, 62), UDim2.new(0, 52, 0, 26), { color = GUI.Theme.danger })

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -16, 0, 14)
hint.Position = UDim2.new(0, 8, 1, -42)
hint.BackgroundTransparency = 1
hint.Text = "APPLY = this card on your score card"
hint.TextColor3 = Color3.fromRGB(150, 150, 160)
hint.Font = Enum.Font.Code
hint.TextSize = 9
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = frame

-- ---------- buttons ----------
prevBtn.MouseButton1Click:Connect(function()
	if #cards == 0 then return end
	cardIndex = cardIndex - 1
	if cardIndex < 1 then cardIndex = #cards end
	nameBox.Text = cards[cardIndex].id
	updateStatus()
end)

nextBtn.MouseButton1Click:Connect(function()
	if #cards == 0 then return end
	cardIndex = cardIndex + 1
	if cardIndex > #cards then cardIndex = 1 end
	nameBox.Text = cards[cardIndex].id
	updateStatus()
end)

applyBtn.MouseButton1Click:Connect(function()
	local t = nameBox.Text
	for _, c in ipairs(cards) do
		if c.id == t or c.name == t then
			selectedId = c.id
			status.Text = "Card -> " .. c.name
			log("APPLY: " .. c.name .. " (" .. c.id .. ")")
			config.PlayerCardSpoofer = { selected = c.id }
			saveConfig()
			GUI.Notify("Card applied: " .. c.name, "success")
			return
		end
	end
	status.Text = "Card not found: " .. t
	GUI.Notify("Card not found: " .. t, "error")
end)

resetBtn.MouseButton1Click:Connect(function()
	selectedId = nil
	updateStatus()
	GUI.Notify("Real card restored", "info")
end)

-- ---------- init ----------
local n = loadCards()
if n == 0 then
	status.Text = "No PlayerCards found"
else
	status.Text = "Cards: " .. n .. " | press < > to browse"
	nameBox.Text = cards[1].id
end
	local saved = config.PlayerCardSpoofer and config.PlayerCardSpoofer.selected
	if saved and type(saved) == "string" then
		for _, c in ipairs(cards) do
			if c.id == saved then
				selectedId = saved
				nameBox.Text = saved
				status.Text = "Restored saved card -> " .. c.name
				GUI.Notify("Restored saved card: " .. c.name, "success")
				break
			end
		end
	end
