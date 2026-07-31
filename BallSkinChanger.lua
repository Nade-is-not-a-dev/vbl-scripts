-- Ball Skin Changer (client-side, Volleyball Legends)
-- Swaps the visual of every spawned ball to a skin of your choice.
-- Uses the game's own skin models from ReplicatedStorage.Assets.Ball.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local ASSETS = ReplicatedStorage:FindFirstChild("Assets")
local BALL_FOLDER = ASSETS and ASSETS:FindFirstChild("Ball")

local skins = {}
local skinIndex = 0
local currentTarget = "ClassicBall"
local originals = {}
local clones = {}

-- ---------- GUI ----------
local gui = Instance.new("ScreenGui")
gui.Name = "BallSkinChanger"
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
title.Text = "Ball Skin Changer"
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
status.Text = "Loading skins..."
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
nameBox.Text = "ClassicBall"
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
hint.Text = "APPLY = use this skin on every ball"
hint.TextColor3 = Color3.fromRGB(150, 150, 160)
hint.Font = Enum.Font.Code
hint.TextSize = 9
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = frame

-- ---------- skin list ----------
local function loadSkins()
	skins = {}
	if BALL_FOLDER then
		for _, child in ipairs(BALL_FOLDER:GetChildren()) do
			if child:IsA("Model") then
				table.insert(skins, child.Name)
			end
		end
	end
	table.sort(skins)
	for i, name in ipairs(skins) do
		if name == "ClassicBall" then
			skinIndex = i
			break
		end
	end
	if #skins == 0 then
		status.Text = "No skins found in Assets.Ball"
	else
		status.Text = "Skin list: " .. #skins .. " | " .. skins[skinIndex or 1]
		nameBox.Text = skins[skinIndex or 1]
	end
end

local function updateStatus()
	status.Text = ("Skin: %s (%d/%d)"):format(nameBox.Text, skinIndex, #skins)
end

-- ---------- spoof logic ----------
local function isSpoofTarget()
	local t = nameBox.Text:gsub("%s", "")
	return t ~= "" and t ~= "ClassicBall"
end

local function restoreBall(ball)
	local orig = originals[ball]
	if orig then
		for _, entry in ipairs(orig) do
			pcall(function()
				entry.part.Transparency = entry.t
				entry.part.CanCollide = entry.cc
			end)
		end
		originals[ball] = nil
	end
	if clones[ball] then
		clones[ball]:Destroy()
		clones[ball] = nil
	end
	ball:SetAttribute("SpoofedSkin", nil)
end

local function applySkin(ball, skinName)
	if ball:GetAttribute("SpoofedSkin") == skinName then
		return
	end

	restoreBall(ball)

	local skinModel = BALL_FOLDER and BALL_FOLDER:FindFirstChild(skinName)
	if not skinModel or not skinModel:IsA("Model") then
		return
	end

	local primary = ball.PrimaryPart or ball:FindFirstChildWhichIsA("BasePart")
	if not primary then
		return
	end

	-- hide original visuals (keep collision for client prediction)
	local orig = {}
	for _, part in ipairs(ball:GetDescendants()) do
		if part:IsA("BasePart") then
			table.insert(orig, { part = part, t = part.Transparency, cc = part.CanCollide })
			part.Transparency = 1
			part.CastShadow = false
		elseif part:IsA("Beam") or part:IsA("Trail") or part:IsA("ParticleEmitter") then
			if part.Enabled ~= nil then
				part.Enabled = false
			end
		end
	end
	originals[ball] = orig

	-- clone the target skin and weld it to the ball's primary part
	local clone = skinModel:Clone()
	local okScale = pcall(function()
		clone:ScaleTo(ball:GetScale())
	end)
	local clonePrimary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
	if not clonePrimary then
		restoreBall(ball)
		return
	end

	pcall(function() clone:PivotTo(primary.CFrame) end)

	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CastShadow = false
		end
	end

	clone.Parent = ball

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = primary
	weld.Part1 = clonePrimary
	weld.Parent = clonePrimary

	clones[ball] = clone
	ball:SetAttribute("SpoofedSkin", skinName)
end

local function processBall(ball)
	if not ball:IsA("Model") then return end
	if ball:GetAttribute("SpoofedSkin") == nameBox.Text then return end

	if isSpoofTarget() then
		pcall(applySkin, ball, nameBox.Text)
	else
		restoreBall(ball)
	end
end

local seen = {}

local function sweep()
	for _, ball in ipairs(CollectionService:GetTagged("Ball")) do
		processBall(ball)
		seen[ball] = true
	end
	-- cleanup dead balls
	for ball in pairs(seen) do
		if not ball:IsDescendantOf(workspace) then
			restoreBall(ball)
			seen[ball] = nil
		end
	end
end

-- react to new balls immediately + periodic sweep (catches replacement)
workspace.ChildAdded:Connect(function(child)
	if typeof(child) == "Instance" and child:IsA("Model") and CollectionService:HasTag(child, "Ball") then
		task.spawn(function()
			task.wait(0.1)
			processBall(child)
		end)
	end
end)

RunService.Heartbeat:Connect(function()
	if #CollectionService:GetTagged("Ball") > 0 then
		task.spawn(sweep)
	end
end)

-- ---------- buttons ----------
prevBtn.MouseButton1Click:Connect(function()
	if #skins == 0 then return end
	skinIndex = skinIndex - 1
	if skinIndex < 1 then skinIndex = #skins end
	nameBox.Text = skins[skinIndex]
	updateStatus()
end)

nextBtn.MouseButton1Click:Connect(function()
	if #skins == 0 then return end
	skinIndex = skinIndex + 1
	if skinIndex > #skins then skinIndex = 1 end
	nameBox.Text = skins[skinIndex]
	updateStatus()
end)

applyBtn.MouseButton1Click:Connect(function()
	updateStatus()
	sweep()
end)

resetBtn.MouseButton1Click:Connect(function()
	nameBox.Text = "ClassicBall"
	updateStatus()
	for ball in pairs(seen) do
		restoreBall(ball)
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	for ball in pairs(seen) do
		restoreBall(ball)
	end
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

game:GetService("UserInputService").InputChanged:Connect(function(input)
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

loadSkins()
updateStatus()
