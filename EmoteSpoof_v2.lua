-- Emote Spoofer (client-side, Volleyball Legends)
-- Any emote YOU trigger (wheel, quick chat, chat command) gets replaced by
-- the chosen emote. The game plays every emote through
--   AnimationController:PlayAnimation(id) -> Animator:LoadAnimation(anim)
-- so a single LoadAnimation hook + one AnimationPlayed backup covers all paths.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local _fw = httpGet("https://raw.githubusercontent.com/Nade-is-not-a-dev/vbl-scripts/main/framework_v3.lua?cb=" .. tostring(os.time()))
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

-- ---------- logging ----------
local LOG_PATH = "EmoteSpoof_log.txt"
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
log("=== EmoteSpoof v2 started ===")
if GUI and GUI.Version then
	log("framework version: " .. tostring(GUI.Version))
end
if GUI then
	GUI.Log = log
end

-- single-instance guard: any newer launch of this script takes over
local instanceStamp = os.time()
_G.VBL_ES_STAMP = instanceStamp
log("instance stamp: " .. tostring(instanceStamp))
local function stillMine()
	return _G.VBL_ES_STAMP == instanceStamp
end

-- ---------- emote collection ----------
local ENTITIES = ReplicatedStorage.Content.Item:FindFirstChild("Entities")
local ItemModule = nil
pcall(function()
	ItemModule = require(ReplicatedStorage.Content.Item)
end)

local emotes = {}            -- { id, name, asset }
local emoteAssets = {}       -- asset -> true (emote detection for the hook)
local emoteIds = {}          -- id -> true (emote detection for PlayAnimation hook)

local function loadEmotes()
	if not ENTITIES then
		log("no Content.Item.Entities folder - emotes list empty")
		return
	end
	for _, child in ipairs(ENTITIES:GetChildren()) do
		if child:IsA("ModuleScript") then
			local ok, item = pcall(require, child)
			if ok and type(item) == "table" then
				local isEmote = false
				if ItemModule and ItemModule.Type and item.Type == ItemModule.Type.Emote then
					isEmote = true
				elseif type(item.Asset) == "string" then
					isEmote = item.Asset:find("rbxassetid://") ~= nil
				end
				if isEmote and type(item.Asset) == "string" and item.Asset ~= "" then
					table.insert(emotes, {
						id = tostring(item.Id or child.Name),
						name = tostring(item.DisplayName or child.Name),
						asset = item.Asset,
					})
					emoteAssets[item.Asset] = true
					emoteIds[tostring(item.Id or child.Name)] = true
				end
			end
		end
	end
	table.sort(emotes, function(a, b) return a.name < b.name end)
	log("emotes found: " .. #emotes)
end

-- ---------- spoof engine ----------
local target = nil -- { id, name, asset }
local swapCount = 0

local function swapAnim(anim, source)
	if not target then return end
	local id = anim.AnimationId
	if typeof(id) ~= "string" then return end
	if not emoteAssets[id] then return end -- only emotes, never walk/idle
	if id == target.asset then return end
	anim.AnimationId = target.asset
	swapCount = swapCount + 1
	if swapCount <= 20 then
		log("SWAP [" .. source .. "]: " .. id .. " -> " .. target.asset)
	end
end

-- path 0 (main): AnimationController:PlayAnimation is called on EVERY emote
-- trigger (wheel, quick chat, chat command) and is NOT cached, unlike
-- Animator:LoadAnimation (tracks live in LoadedAnimations after first load).
local animCtrl = nil
local function installPlayHook()
	local ok, knit = pcall(require, ReplicatedStorage.Packages.Knit)
	if not ok or type(knit) ~= "table" then
		log("PLAY HOOK FAILED: Knit not accessible")
		return
	end
	local ok2, ctrl = pcall(function()
		return knit.GetController("AnimationController")
	end)
	if not ok2 or type(ctrl) ~= "table" or type(ctrl.PlayAnimation) ~= "function" then
		log("PLAY HOOK FAILED: AnimationController not accessible")
		return
	end
	animCtrl = ctrl
	local orig = ctrl.PlayAnimation
	local ok3, err = pcall(function()
		ctrl.PlayAnimation = hookfunction(orig, newcclosure(function(self, name, ...)
			if stillMine() and target and type(name) == "string"
			and emoteIds[name] and name ~= target.id then
				log("PLAY: " .. name .. " -> " .. target.id)
				local res = orig(self, target.id, ...)
				-- the caller (EmoteWheel) reads GetAnimationLength(name) to
				-- schedule StopEmotes; mirror the loaded track under the
				-- original name so it finds a length and doesn't stop us at 0s
				local lc = ctrl.LoadedAnimations
				if type(lc) == "table" and lc[target.id] and not lc[name] then
					lc[name] = lc[target.id]
					log("MIRROR: LoadedAnimations[" .. tostring(name) .. "] -> " .. tostring(target.id))
				end
				return res
			end
			return orig(self, name, ...)
		end))
	end)
	if not ok3 then
		log("PLAY HOOK FAILED: " .. tostring(err))
		return
	end
	log("PLAY HOOK installed: AnimationController:PlayAnimation patched")
end

local function flushCache()
	if not animCtrl or type(animCtrl.LoadedAnimations) ~= "table" then return end
	local n = 0
	for _, e in ipairs(emotes) do
		if animCtrl.LoadedAnimations[e.id] then
			animCtrl.LoadedAnimations[e.id] = nil
			n = n + 1
		end
	end
	if n > 0 then
		log("CACHE: flushed " .. n .. " emote tracks")
	end
end

-- path 1 (main): patch the Animation instance before Animator loads it
local function installHook()
	local mt = getrawmetatable(game)
	if not mt then
		log("HOOK FAILED: getrawmetatable returned nil (backup path still active)")
		return false
	end
	local oldNamecall = mt.__namecall
	if not oldNamecall then
		log("HOOK FAILED: __namecall missing (backup path still active)")
		return false
	end
	local getMethod = getnamecallmethod or namecallmethod
	local ok, err = pcall(function()
		setreadonly(mt, false)
		mt.__namecall = newcclosure(function(self, ...)
			local args = { ... }
			local ok2, err2 = pcall(function()
				if getMethod() == "LoadAnimation"
				and typeof(self) == "Instance"
				and self:IsA("Animator") then
					local anim = args[1]
					if typeof(anim) == "Instance" and anim:IsA("Animation") then
						swapAnim(anim, "load")
					end
				end
			end)
			if not ok2 then
				log("HOOK error: " .. tostring(err2))
			end
			return oldNamecall(self, ...)
		end)
		setreadonly(mt, true)
	end)
	if not ok then
		log("HOOK FAILED: " .. tostring(err))
		return false
	end
	log("HOOK installed: Animator:LoadAnimation patched")
	return true
end

-- path 2 (backup): stop + replay anything that already played unpatched
local attached = {}
local function attachAnimator(animator)
	if attached[animator] then return end
	attached[animator] = true
	animator.AnimationPlayed:Connect(function(track, anim)
		if not stillMine() then return end
		if not target then return end
		if typeof(anim) ~= "Instance" or not anim:IsA("Animation") then return end
		local id = anim.AnimationId
		if typeof(id) ~= "string" or not emoteAssets[id] then return end
		if id == target.asset then return end
		log("AP backup: " .. id .. " -> " .. target.asset)
		track:Stop()
		task.spawn(function()
			pcall(function()
				local na = Instance.new("Animation")
				na.AnimationId = target.asset
				na.Parent = anim.Parent or animator:FindFirstAncestorOfClass("Humanoid")
				if not na.Parent then
					na:Destroy()
					return
				end
				local nt = animator:LoadAnimation(na)
				nt.Looped = track.Looped
				nt.Priority = track.Priority
				nt:Play()
			end)
		end)
	end)
end

local function attachCharacter(char)
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	task.spawn(function()
		for _ = 1, 50 do
			task.wait(0.2)
			if not stillMine() then return end
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				attachAnimator(animator)
				log("animator attached: " .. char.Name)
				return
			end
		end
	end)
end

lp.CharacterAdded:Connect(attachCharacter)
pcall(attachCharacter, lp.Character)
installHook()

-- ---------- GUI (framework) ----------
local win = GUI.Window({
	title = "Emote Spoofer",
	name = "EmoteSpoof",
	icon = "ES",
	size = Vector2.new(280, 200),
	y = 30,
})
local frame = win.Content

local status = GUI.Label(frame, "Starting...", UDim2.new(0, 10, 0, 8), UDim2.new(1, -20, 0, 16))
local selBox = GUI.Input(frame, "OFF", UDim2.new(0, 10, 0, 28), UDim2.new(1, -20, 0, 26))
local prevBtn = GUI.Button(frame, "<", UDim2.new(0, 10, 0, 58), UDim2.new(0, 30, 0, 26))
local nextBtn = GUI.Button(frame, ">", UDim2.new(0, 44, 0, 58), UDim2.new(0, 30, 0, 26))
local listBtn = GUI.Button(frame, "LIST", UDim2.new(0, 78, 0, 58), UDim2.new(0, 42, 0, 26))
local applyBtn = GUI.Button(frame, "APPLY", UDim2.new(0, 124, 0, 58), UDim2.new(0, 80, 0, 26), { color = GUI.Theme.success })
local resetBtn = GUI.Button(frame, "RESET", UDim2.new(0, 208, 0, 58), UDim2.new(0, 52, 0, 26), { color = GUI.Theme.danger })

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -16, 0, 14)
hint.Position = UDim2.new(0, 8, 1, -42)
hint.BackgroundTransparency = 1
hint.Text = "emotes YOU play get replaced with this one"
hint.TextColor3 = Color3.fromRGB(150, 150, 160)
hint.Font = Enum.Font.Code
hint.TextSize = 9
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = frame

local emoteIndex = 1

local function updateStatus()
	if target then
		status.Text = "Spoofing -> " .. target.name
	else
		status.Text = "OFF - emotes play normally"
	end
end

local function applyEmote(name)
	for _, e in ipairs(emotes) do
		if e.name == name or e.id == name then
			target = { id = e.id, name = e.name, asset = e.asset }
			log("APPLY: " .. e.name .. " (" .. e.asset .. ")")
			flushCache()
			updateStatus()
			config.EmoteSpoof = { selected = e.name }
			saveConfig()
			GUI.Notify("Spoofing emote: " .. e.name, "success")
			return true
		end
	end
	GUI.Notify("Emote not found: " .. name, "error")
	return false
end

-- ---------- buttons ----------
prevBtn.MouseButton1Click:Connect(function()
	if #emotes == 0 then return end
	emoteIndex = emoteIndex - 1
	if emoteIndex < 1 then emoteIndex = #emotes end
	selBox.Text = emotes[emoteIndex].name
end)

nextBtn.MouseButton1Click:Connect(function()
	if #emotes == 0 then return end
	emoteIndex = emoteIndex + 1
	if emoteIndex > #emotes then emoteIndex = 1 end
	selBox.Text = emotes[emoteIndex].name
end)

applyBtn.MouseButton1Click:Connect(function()
	applyEmote(selBox.Text)
end)

resetBtn.MouseButton1Click:Connect(function()
	target = nil
	selBox.Text = "OFF"
	updateStatus()
	flushCache()
	log("RESET: spoof disabled")
	GUI.Notify("Emote spoof disabled", "info")
end)

local previewItems = {}
local previewList = GUI.PreviewList({
	parent = win.Root,
	position = UDim2.fromOffset(20, win.Root.AbsoluteSize.Y + 4),
	width = 240,
	height = 320,
	title = "Emotes",
	items = previewItems,
	onPick = function(id)
		log("LIST pick: " .. tostring(id))
		selBox.Text = id
		applyEmote(id)
	end,
})
listBtn.MouseButton1Click:Connect(function()
	if #emotes == 0 then return end
	if #previewItems == 0 then
		log("LIST: building items from " .. #emotes .. " emotes")
		for _, e in ipairs(emotes) do
			table.insert(previewItems, { id = e.name, name = e.name })
		end
		log("LIST: items ready (" .. #previewItems .. ")")
	end
	previewList.Open()
end)

-- ---------- init ----------
loadEmotes()
installPlayHook()
if #emotes == 0 then
	status.Text = "No emotes found"
else
	status.Text = "Emotes: " .. #emotes
	selBox.Text = emotes[emoteIndex].name
end
local saved = config.EmoteSpoof and config.EmoteSpoof.selected
if saved and type(saved) == "string" then
	selBox.Text = saved
	log("INIT: saved selection restored: " .. saved)
end
updateStatus()
log("READY - " .. #emotes .. " emotes, spoofing " .. tostring(target and target.name or "OFF"))
