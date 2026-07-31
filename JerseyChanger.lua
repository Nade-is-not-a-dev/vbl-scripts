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

-- ---------- GUI ----------
local gui = Instance.new("ScreenGui")
gui.Name = "JerseyChanger"
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
title.Text = "Jersey Changer"
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

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 24, 0, 22)
minBtn.Position = UDim2.new(1, -28, 0, 4)
minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
minBtn.BorderSizePixel = 0
minBtn.Text = "-"
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 14
minBtn.AutoButtonColor = false
minBtn.Parent = title

local mCorner = Instance.new("UICorner")
mCorner.CornerRadius = UDim.new(0, 6)
mCorner.Parent = minBtn

local minimized = false
local fullFrameSize = frame.Size
local function setMinimized(min)
	minimized = min
	frame.Size = min and UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, 30) or fullFrameSize
	for _, child in ipairs(frame:GetChildren()) do
		if child ~= title then
			child.Visible = not min
		end
	end
end
minBtn.MouseButton1Click:Connect(function()
	setMinimized(not minimized)
end)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 16)
status.Position = UDim2.new(0, 8, 0, 36)
status.BackgroundTransparency = 1
status.Text = "Loading jerseys..."
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
nameBox.Text = "ClassicJersey"
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
	end
end)

resetBtn.MouseButton1Click:Connect(function()
	restoreJersey()
end)

closeBtn.MouseButton1Click:Connect(function()
	restoreJersey()
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
local n = loadJerseys()
if n == 0 then
	status.Text = "No jerseys found"
else
	status.Text = "Jersey list: " .. n .. " | " .. (jerseys[jerseyIndex or 1]).id
	nameBox.Text = (jerseys[jerseyIndex or 1]).id
end
if not JerseyTool then
	status.Text = "Tools.Jersey not loaded - cannot spoof"
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
	end
end
