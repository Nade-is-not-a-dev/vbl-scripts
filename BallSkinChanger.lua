-- Ball Skin Changer (client-side, Volleyball Legends)
-- Swaps the visual of every spawned ball to a skin of your choice.
-- Uses the game's own skin models from ReplicatedStorage.Assets.Ball.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
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
local _fw = httpGet("https://raw.githubusercontent.com/Nade-is-not-a-dev/vbl-scripts/main/gui_framework.lua?cb=" .. tostring(os.time()))
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

local ASSETS = ReplicatedStorage:FindFirstChild("Assets")
local BALL_FOLDER = ASSETS and ASSETS:FindFirstChild("Ball")

local skins = {}
local skinIndex = 0
local currentTarget = "ClassicBall"
local originals = {}
local clones = {}
local seen = {}

-- ---------- GUI (framework) ----------
local win = GUI.Window({
	title = "Ball Skin Changer",
	name = "BallSkinChanger",
	icon = "BS",
	size = Vector2.new(280, 200),
	y = 90,
})
local frame = win.Content

local status = GUI.Label(frame, "Loading skins...", UDim2.new(0, 10, 0, 8), UDim2.new(1, -20, 0, 16))
local nameBox = GUI.Input(frame, "ClassicBall", UDim2.new(0, 10, 0, 28), UDim2.new(1, -20, 0, 26))
local prevBtn = GUI.Button(frame, "<", UDim2.new(0, 10, 0, 62), UDim2.new(0, 30, 0, 26))
local nextBtn = GUI.Button(frame, ">", UDim2.new(0, 44, 0, 62), UDim2.new(0, 30, 0, 26))
local applyBtn = GUI.Button(frame, "APPLY", UDim2.new(0, 78, 0, 62), UDim2.new(0, 80, 0, 26), { color = GUI.Theme.success })
local resetBtn = GUI.Button(frame, "RESET", UDim2.new(0, 162, 0, 62), UDim2.new(0, 52, 0, 26), { color = GUI.Theme.danger })

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
	config.BallSkinChanger = { selected = nameBox.Text }
	saveConfig()
	GUI.Notify("Ball skin applied: " .. nameBox.Text, "success")
end)

resetBtn.MouseButton1Click:Connect(function()
	nameBox.Text = "ClassicBall"
	updateStatus()
	for ball in pairs(seen) do
		restoreBall(ball)
	end
	GUI.Notify("Real ball restored", "info")
end)

loadSkins()
updateStatus()
local saved = config.BallSkinChanger and config.BallSkinChanger.selected
if saved and type(saved) == "string" then
	for _, name in ipairs(skins) do
		if name == saved then
			nameBox.Text = saved
			updateStatus()
			sweep()
			GUI.Notify("Restored saved ball skin: " .. saved, "success")
			break
		end
	end
end
