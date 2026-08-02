-- LocalScript (put in StarterGui or StarterPlayerScripts)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remote (Ranked Rewards)
local RequestRankedReward = ReplicatedStorage
	:WaitForChild("Packages")
	:WaitForChild("_Index")
	:WaitForChild("sleitnick_knit@1.7.0")
	:WaitForChild("knit")
	:WaitForChild("Services")
	:WaitForChild("SeasonService")
	:WaitForChild("RF")
	:WaitForChild("RequestRankedReward")

-- Remote (Style Roll)
local StyleRoll = ReplicatedStorage
	:WaitForChild("Packages")
	:WaitForChild("_Index")
	:WaitForChild("sleitnick_knit@1.7.0")
	:WaitForChild("knit")
	:WaitForChild("Services")
	:WaitForChild("StyleService")
	:WaitForChild("RF")
	:WaitForChild("Roll")

-- Remote (Ability Roll) - tries AbilityService first, falls back to StyleRoll
local ABILITY_ROLL_ARG = true -- change if needed (check via Dex Explorer)
local AbilityRoll
pcall(function()
	AbilityRoll = ReplicatedStorage
		:WaitForChild("Packages")
		:WaitForChild("_Index")
		:WaitForChild("sleitnick_knit@1.7.0")
		:WaitForChild("knit")
		:WaitForChild("Services")
		:WaitForChild("AbilityService")
		:WaitForChild("RF")
		:WaitForChild("Roll")
end)
if not AbilityRoll then
	AbilityRoll = StyleRoll
end

-- ========== UI ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RankedRewardUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(0, 720, 0, 180) -- horizontal layout (no bottom cutoff)
mainFrame.Position = UDim2.new(0.5, -360, 0.5, -90)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
title.BorderSizePixel = 0
title.Text = "Ranked Rewards"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = title

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 12)
titleFix.Position = UDim2.new(0, 0, 1, -12)
titleFix.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
titleFix.BorderSizePixel = 0
titleFix.Parent = title

-- ========== DATA ==========
-- name → {arg, color}
local rewards = {
	style   = {arg = 1, color = Color3.fromRGB(80, 160, 255)},
	yen     = {arg = 2, color = Color3.fromRGB(80, 220, 140)},
	ability = {arg = 4, color = Color3.fromRGB(255, 140, 80)},
}

local order = {"style", "yen", "ability"} -- display order
local currentMode = nil -- nil | "style" | "yen" | "ability"
local buttons = {}

-- ========== ROLL DELAY ==========
-- Delay (seconds) between successive auto-rolls (shared by style & ability)
local rollDelay = 1.0

-- The actual remote call (no loop inside)
local function fireReward(arg)
	pcall(function()
		RequestRankedReward:InvokeServer(arg)
	end)
end

-- Single controlled 3.5s loop for ranked rewards
task.spawn(function()
	while true do
		task.wait(3.5)
		if currentMode and rewards[currentMode] then
			fireReward(rewards[currentMode].arg)
		end
	end
end)

-- Update all button visuals
local function updateButtons()
	for name, btn in pairs(buttons) do
		local data = rewards[name]
		if currentMode == name then
			btn.BackgroundColor3 = data.color
			btn.Text = name:upper() .. "  [ON]"
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
			btn.Text = name:upper() .. "  [OFF]"
			btn.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
	end
end

-- ========== CREATE BUTTONS ==========
for i, name in ipairs(order) do
	local data = rewards[name]

	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, 220, 0, 30)
	btn.Position = UDim2.new(0, 15 + (i - 1) * 230, 0, 40)
	btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	btn.BorderSizePixel = 0
	btn.Text = name:upper() .. "  [OFF]"
	btn.TextColor3 = Color3.fromRGB(200, 200, 200)
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 14
	btn.AutoButtonColor = false
	btn.Parent = mainFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn

	buttons[name] = btn

	btn.MouseButton1Click:Connect(function()
		if currentMode == name then
			-- Turn OFF
			currentMode = nil
		else
			-- Turn this ON (automatically turns others off)
			currentMode = name
			-- Fire once immediately when enabling
			fireReward(data.arg)
		end
		updateButtons()
	end)
end

-- ========== STYLE AUTO-ROLL SECTION ==========
local styleToggleEnabled = false

-- Label
local styleLabel = Instance.new("TextLabel")
styleLabel.Size = UDim2.new(0, 330, 0, 16)
styleLabel.Position = UDim2.new(0, 15, 0, 82)
styleLabel.BackgroundTransparency = 1
styleLabel.Text = "Style Auto-Roll"
styleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
styleLabel.Font = Enum.Font.GothamMedium
styleLabel.TextSize = 12
styleLabel.TextXAlignment = Enum.TextXAlignment.Left
styleLabel.Parent = mainFrame

-- TextBox for desired style name
local styleBox = Instance.new("TextBox")
styleBox.Name = "StyleTarget"
styleBox.Size = UDim2.new(0, 330, 0, 26)
styleBox.Position = UDim2.new(0, 15, 0, 100)
styleBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
styleBox.BorderSizePixel = 0
styleBox.PlaceholderText = "Desired Style Name..."
styleBox.Text = ""
styleBox.TextColor3 = Color3.fromRGB(255, 255, 255)
styleBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
styleBox.Font = Enum.Font.Gotham
styleBox.TextSize = 13
styleBox.ClearTextOnFocus = false
styleBox.Parent = mainFrame

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 6)
boxCorner.Parent = styleBox

-- Toggle button
local styleToggleBtn = Instance.new("TextButton")
styleToggleBtn.Name = "StyleToggle"
styleToggleBtn.Size = UDim2.new(0, 330, 0, 30)
styleToggleBtn.Position = UDim2.new(0, 15, 0, 132)
styleToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
styleToggleBtn.BorderSizePixel = 0
styleToggleBtn.Text = "AUTO-ROLL  [OFF]"
styleToggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
styleToggleBtn.Font = Enum.Font.GothamMedium
styleToggleBtn.TextSize = 14
styleToggleBtn.AutoButtonColor = false
styleToggleBtn.Parent = mainFrame

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 6)
toggleCorner.Parent = styleToggleBtn

local function updateStyleToggleVisual()
	if styleToggleEnabled then
		styleToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 220)
		styleToggleBtn.Text = "AUTO-ROLL  [ON]"
		styleToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		styleToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		styleToggleBtn.Text = "AUTO-ROLL  [OFF]"
		styleToggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
end

-- Helper: get current StyleName (case-insensitive comparison later)
local function getCurrentStyleName()
	local character = workspace:FindFirstChild(player.Name)
	if not character then return nil end

	local jerseyBack = character:FindFirstChild("JerseyBack")
	if not jerseyBack then return nil end

	local styleNameObj = jerseyBack:FindFirstChild("StyleName")
	if not styleNameObj then return nil end

	-- StyleName could be a StringValue or a TextLabel / other instance with .Text / .Value
	if styleNameObj:IsA("StringValue") then
		return styleNameObj.Value
	elseif styleNameObj:IsA("TextLabel") or styleNameObj:IsA("TextBox") then
		return styleNameObj.Text
	end

	-- Fallback: try .Value then .Text
	local ok, val = pcall(function() return styleNameObj.Value end)
	if ok and typeof(val) == "string" then return val end

	ok, val = pcall(function() return styleNameObj.Text end)
	if ok and typeof(val) == "string" then return val end

	return nil
end

local function fireStyleRoll()
	pcall(function()
		StyleRoll:InvokeServer(true)
	end)
end

-- Controlled loop for style auto-roll
task.spawn(function()
	while true do
		task.wait(0.1) -- reasonable check rate (not too aggressive)

		if not styleToggleEnabled then
			continue
		end

		local target = styleBox.Text
		if target == nil or target:gsub("%s+", "") == "" then
			-- empty target → do nothing
			continue
		end

		local current = getCurrentStyleName()
		if current == nil then
			continue
		end

		-- Case-insensitive compare
		if string.lower(current) ~= string.lower(target) then
			fireStyleRoll()
			task.wait(rollDelay)
		else
			-- Match found → turn toggle off
			styleToggleEnabled = false
			updateStyleToggleVisual()
		end
	end
end)

styleToggleBtn.MouseButton1Click:Connect(function()
	styleToggleEnabled = not styleToggleEnabled
	updateStyleToggleVisual()

	-- Optional: fire once immediately when turning on
	if styleToggleEnabled then
		local target = styleBox.Text
		if target and target:gsub("%s+", "") ~= "" then
			local current = getCurrentStyleName()
			if current and string.lower(current) ~= string.lower(target) then
				fireStyleRoll()
			end
		end
	end
end)

-- ========== ROLL DELAY SECTION ==========
local delayLabel = Instance.new("TextLabel")
delayLabel.Size = UDim2.new(0, 170, 0, 16)
delayLabel.Position = UDim2.new(0, 365, 0, 82)
delayLabel.BackgroundTransparency = 1
delayLabel.Text = "Roll Delay (sec)"
delayLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
delayLabel.Font = Enum.Font.GothamMedium
delayLabel.TextSize = 12
delayLabel.TextXAlignment = Enum.TextXAlignment.Left
delayLabel.Parent = mainFrame

local delayBox = Instance.new("TextBox")
delayBox.Name = "RollDelay"
delayBox.Size = UDim2.new(0, 170, 0, 26)
delayBox.Position = UDim2.new(0, 365, 0, 100)
delayBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
delayBox.BorderSizePixel = 0
delayBox.PlaceholderText = "1.0"
delayBox.Text = "1.0"
delayBox.TextColor3 = Color3.fromRGB(255, 255, 255)
delayBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
delayBox.Font = Enum.Font.Gotham
delayBox.TextSize = 13
delayBox.ClearTextOnFocus = false
delayBox.Parent = mainFrame

local delayBoxCorner = Instance.new("UICorner")
delayBoxCorner.CornerRadius = UDim.new(0, 6)
delayBoxCorner.Parent = delayBox

local function applyRollDelay()
	local n = tonumber(delayBox.Text)
	if n == nil then
		delayBox.Text = tostring(rollDelay)
		return
	end
	rollDelay = math.max(0, n)
	delayBox.Text = tostring(rollDelay)
end

delayBox.FocusLost:Connect(function()
	applyRollDelay()
end)

-- ========== ABILITY AUTO-ROLL SECTION ==========
local abilityToggleEnabled = false

-- Helper: extract a string from StringValue / TextLabel / generic
local function extractString(obj)
	if typeof(obj) ~= "Instance" then return nil end
	if obj:IsA("StringValue") then
		return obj.Value
	elseif obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("TextButton") then
		return obj.Text
	end
	local ok, val = pcall(function() return obj.Value end)
	if ok and typeof(val) == "string" then return val end
	ok, val = pcall(function() return obj.Text end)
	if ok and typeof(val) == "string" then return val end
	return nil
end

-- Strip rich text tags like <font color=...>...</font>
local function stripRich(text)
	if not text then return nil end
	return (text:gsub("<[^>]*>", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Helper: get current ability name from the Abilities UI
-- (requires the Abilities tab to be open in-game)
local function getCurrentAbilityName()
	local abilities = playerGui:FindFirstChild("Interface")
		and playerGui.Interface:FindFirstChild("Lobby")
		and playerGui.Interface.Lobby:FindFirstChild("Abilities")
	if not abilities then return nil end

	-- 1) Slot marked "EQUIPPED"
	for _, v in ipairs(abilities:GetDescendants()) do
		if v:IsA("TextLabel") and v.Name == "Subheader" and v.Text == "EQUIPPED" then
			for _, sibling in ipairs(v.Parent:GetChildren()) do
				if sibling:IsA("TextLabel") and sibling.Name == "Title" then
					local name = stripRich(sibling.Text)
					if name and name ~= "" and name ~= "LOCKED" then
						return name
					end
				end
			end
		end
	end

	-- 2) "Current Ability:" panel
	for _, v in ipairs(abilities:GetDescendants()) do
		if v:IsA("TextLabel") and tostring(v.Text):find("Current Ability") then
			for _, sibling in ipairs(v.Parent:GetChildren()) do
				if sibling:IsA("TextLabel") and sibling.Name == "DisplayName" then
					local name = stripRich(sibling.Text)
					if name and name ~= "" then
						return name
					end
				end
			end
		end
	end

	return nil
end

-- Label
local abilityLabel = Instance.new("TextLabel")
abilityLabel.Size = UDim2.new(0, 145, 0, 16)
abilityLabel.Position = UDim2.new(0, 560, 0, 82)
abilityLabel.BackgroundTransparency = 1
abilityLabel.Text = "Ability Auto-Roll"
abilityLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
abilityLabel.Font = Enum.Font.GothamMedium
abilityLabel.TextSize = 12
abilityLabel.TextXAlignment = Enum.TextXAlignment.Left
abilityLabel.Parent = mainFrame

-- TextBox for desired ability name
local abilityBox = Instance.new("TextBox")
abilityBox.Name = "AbilityTarget"
abilityBox.Size = UDim2.new(0, 145, 0, 26)
abilityBox.Position = UDim2.new(0, 560, 0, 100)
abilityBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
abilityBox.BorderSizePixel = 0
abilityBox.PlaceholderText = "Desired Ability Name..."
abilityBox.Text = ""
abilityBox.TextColor3 = Color3.fromRGB(255, 255, 255)
abilityBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
abilityBox.Font = Enum.Font.Gotham
abilityBox.TextSize = 13
abilityBox.ClearTextOnFocus = false
abilityBox.Parent = mainFrame

local abilityBoxCorner = Instance.new("UICorner")
abilityBoxCorner.CornerRadius = UDim.new(0, 6)
abilityBoxCorner.Parent = abilityBox

-- Toggle button
local abilityToggleBtn = Instance.new("TextButton")
abilityToggleBtn.Name = "AbilityToggle"
abilityToggleBtn.Size = UDim2.new(0, 145, 0, 30)
abilityToggleBtn.Position = UDim2.new(0, 560, 0, 132)
abilityToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
abilityToggleBtn.BorderSizePixel = 0
abilityToggleBtn.Text = "AUTO-ROLL  [OFF]"
abilityToggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
abilityToggleBtn.Font = Enum.Font.GothamMedium
abilityToggleBtn.TextSize = 14
abilityToggleBtn.AutoButtonColor = false
abilityToggleBtn.Parent = mainFrame

local abilityToggleCorner = Instance.new("UICorner")
abilityToggleCorner.CornerRadius = UDim.new(0, 6)
abilityToggleCorner.Parent = abilityToggleBtn

local function updateAbilityToggleVisual()
	if abilityToggleEnabled then
		abilityToggleBtn.BackgroundColor3 = Color3.fromRGB(220, 140, 60)
		abilityToggleBtn.Text = "AUTO-ROLL  [ON]"
		abilityToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		abilityToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		abilityToggleBtn.Text = "AUTO-ROLL  [OFF]"
		abilityToggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
end

local function fireAbilityRoll()
	pcall(function()
		AbilityRoll:InvokeServer(ABILITY_ROLL_ARG)
	end)
end

-- Controlled loop for ability auto-roll
task.spawn(function()
	while true do
		task.wait(0.1)

		if not abilityToggleEnabled then
			continue
		end

		local target = abilityBox.Text
		if target == nil or target:gsub("%s+", "") == "" then
			continue
		end

		local current = getCurrentAbilityName()
		if current == nil then
			continue
		end

		if string.lower(current) ~= string.lower(target) then
			fireAbilityRoll()
			task.wait(rollDelay)
		else
			abilityToggleEnabled = false
			updateAbilityToggleVisual()
		end
	end
end)

abilityToggleBtn.MouseButton1Click:Connect(function()
	abilityToggleEnabled = not abilityToggleEnabled
	updateAbilityToggleVisual()

	if abilityToggleEnabled then
		local target = abilityBox.Text
		if target and target:gsub("%s+", "") ~= "" then
			local current = getCurrentAbilityName()
			if current and string.lower(current) ~= string.lower(target) then
				fireAbilityRoll()
			end
		end
	end
end)

-- ========== DRAGGABLE ==========
local dragging = false
local dragStart, startPos

title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
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
		mainFrame.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end
end)