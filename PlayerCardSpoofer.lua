-- Player Card Spoofer (client-side, Volleyball Legends)
-- Swaps the PlayerCard shown on your score card (FlashPlayerCard) to any
-- other PlayerCard variant. Local-only: you see the chosen card design.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

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

-- ---------- GUI ----------
local gui = Instance.new("ScreenGui")
gui.Name = "PlayerCardSpoofer"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 260, 0, 190)
frame.Position = UDim2.new(0.5, -130, 0, 120)
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
title.Text = "Player Card Spoofer"
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
status.Position = UDim2.new(0, 8, 0, 36)
status.BackgroundTransparency = 1
status.Text = "Loading cards..."
status.TextColor3 = Color3.fromRGB(220, 220, 220)
status.Font = Enum.Font.Code
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local nameBox = Instance.new("TextBox")
nameBox.Size = UDim2.new(1, -16, 0, 28)
nameBox.Position = UDim2.new(0, 8, 0, 56)
nameBox.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
nameBox.BorderSizePixel = 0
nameBox.Text = ""
nameBox.TextColor3 = Color3.fromRGB(220, 220, 220)
nameBox.Font = Enum.Font.Code
nameBox.TextSize = 11
nameBox.TextXAlignment = Enum.TextXAlignment.Center
nameBox.ClearTextOnFocus = false
nameBox.Parent = frame

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 6)
boxCorner.Parent = nameBox

local function makeBtn(label, x, w, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, w, 0, 26)
	b.Position = UDim2.new(0, x, 0, 92)
	b.BackgroundColor3 = color or Color3.fromRGB(50, 50, 60)
	b.BorderSizePixel = 0
	b.Text = label
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 11
	b.AutoButtonColor = false
	b.Parent = frame

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 6)
	bc.Parent = b
	return b
end

local prevBtn = makeBtn("<", 8, 30)
local nextBtn = makeBtn(">", 42, 30)
local applyBtn = makeBtn("APPLY", 76, 80, Color3.fromRGB(60, 160, 90))
local resetBtn = makeBtn("RESET", 160, 52, Color3.fromRGB(190, 70, 70))
local closeBtn = makeBtn("X", 232, 20)

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
			return
		end
	end
	status.Text = "Card not found: " .. t
end)

resetBtn.MouseButton1Click:Connect(function()
	selectedId = nil
	updateStatus()
end)

closeBtn.MouseButton1Click:Connect(function()
	selectedId = nil
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

-- ---------- init ----------
local n = loadCards()
if n == 0 then
	status.Text = "No PlayerCards found"
else
	status.Text = "Cards: " .. n .. " | press < > to browse"
	nameBox.Text = cards[1].id
end
