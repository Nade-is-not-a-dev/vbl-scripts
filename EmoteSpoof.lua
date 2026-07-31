pcall(writefile, "EmoteSpoof_probe.txt", "L0 parse ok\n")
-- Emote Spoofer v13 (client-side, Volleyball Legends)
-- paths: hook LoadAnimation + patch Animation instances + flush LoadedAnimations cache
-- + force-play fallback: if wheel slot click doesn't trigger the game's own
-- PlayAnimation within 0.3s, play it via the game controller ourselves.

local LOG_PATH = "EmoteSpoof_log.txt"

local logbuf = {}
local function log(msg)
	table.insert(logbuf, tostring(msg))
	if #logbuf > 200 then
		local cut = #logbuf - 200
		for _ = 1, cut do table.remove(logbuf, 1) end
	end
	local ok = pcall(writefile, LOG_PATH, table.concat(logbuf, "\n"))
	if not ok then
		pcall(writefile, LOG_PATH, "ERROR: failed writing log\n" .. tostring(msg))
	end
end

local function logerr(err, tb)
	log("!! ERROR: " .. tostring(err))
	if tb then log("!! TRACEBACK:\n" .. tostring(tb)) end
end

local setStatus
local function main()
	pcall(writefile, "EmoteSpoof_probe.txt", "L1 main started\n")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local UserInputService = game:GetService("UserInputService")
	local Workspace = game:GetService("Workspace")
	local StarterPlayer = game:GetService("StarterPlayer")
	local GuiService = game:GetService("GuiService")

	local lp
	for _ = 1, 300 do
		lp = Players.LocalPlayer
		if lp then break end
		task.wait(0.1)
	end
	if not lp then
		error("LocalPlayer never spawned (300 waits)")
	end
	local pg = lp:WaitForChild("PlayerGui", 20)
	if not pg then error("PlayerGui not found") end

	local ItemModule = nil
	pcall(function()
		ItemModule = require(ReplicatedStorage.Content.Item)
	end)
	local ENTITIES = ReplicatedStorage.Content.Item:FindFirstChild("Entities")
	log("startup: ItemModule loaded: " .. tostring(ItemModule ~= nil) .. ", Entities found: " .. tostring(ENTITIES ~= nil))

	local emotes = {}
	local emoteAssets = {}
	local targetAsset = nil
	local targetName = "OFF"
	local spoofed = {}
	local attached = {}
	local spoofCount = 0
	local dbgCount = 0
	local apFire = 0
	local hookFire = 0

	local function dbgAnim(inst, source)
		if dbgCount >= 20 then return end
		dbgCount = dbgCount + 1
		log("DBG " .. source .. ": Animation '" .. tostring(inst.AnimationId)
			.. "' parent=" .. tostring(inst.Parent and inst.Parent:GetFullName()))
	end

	local function installDebug()
		local function watch(parent, src)
			parent.DescendantAdded:Connect(function(inst)
				if inst:IsA("Animation") then
					dbgAnim(inst, src)
				end
			end)
		end
		if lp.Character then
			watch(lp.Character, "char")
		end
		lp.CharacterAdded:Connect(function(char)
			watch(char, "char")
		end)
		watch(Workspace, "ws")
		watch(ReplicatedStorage, "rs")
		watch(StarterPlayer, "sp")
		task.delay(3, function()
			local function scan(parent, name)
				local n = 0
				local samples = {}
				for _, inst in ipairs(parent:GetDescendants()) do
					if inst:IsA("Animation") then
						n = n + 1
						if #samples < 3 then
							table.insert(samples, tostring(inst.AnimationId))
						end
					end
				end
				if n > 0 then
					log("SCAN " .. name .. ": " .. n .. " animations (" .. table.concat(samples, ",") .. ")")
				else
					log("SCAN " .. name .. ": 0 animations")
				end
			end
			scan(lp.Character or Workspace, "char")
			scan(Workspace, "ws")
			scan(ReplicatedStorage, "rs")
			scan(StarterPlayer, "sp")
		end)
	end

	-- ---------- collect emotes ----------
	local function loadEmotes()
		emotes = {}
		emoteAssets = {}
		if not ENTITIES then
			log("no Entities folder, emotes list empty")
			return
		end
		for _, child in ipairs(ENTITIES:GetChildren()) do
			if child:IsA("ModuleScript") then
				local ok, item = pcall(require, child)
				if ok and type(item) == "table" then
					local isEmote = false
					if ItemModule and ItemModule.Type and item.Type == ItemModule.Type.Emote then
						isEmote = true
					else
						isEmote = type(item.Asset) == "string" and item.Asset:find("rbxassetid://") ~= nil
					end
					if isEmote and type(item.Asset) == "string" and item.Asset ~= "" then
						table.insert(emotes, {
							id = tostring(item.Id or child.Name),
							name = tostring(item.DisplayName or child.Name),
							asset = item.Asset,
						})
						emoteAssets[item.Asset] = true
					end
				end
			end
		end
		table.sort(emotes, function(a, b) return a.name < b.name end)
		log("emotes found: " .. #emotes)
	end

	-- ---------- spoof engine ----------
	local function swapAnim(anim, source)
		if not targetAsset then return end
		local id = anim.AnimationId
		if typeof(id) ~= "string" then return end
		if not emoteAssets[id] then return end
		if id == targetAsset then return end
		anim.AnimationId = targetAsset
		spoofCount = spoofCount + 1
		if spoofCount <= 30 then
			log("SWAP " .. spoofCount .. " [" .. source .. "]: " .. id .. " -> " .. targetAsset)
		end
	end

	-- path 1: metatable hook on Animator:LoadAnimation (catches local + replicated + rigs)
	local hookOk = false
	local function installHook()
		local mt = getrawmetatable(game)
		if not mt then
			log("HOOK: getrawmetatable nil")
			return
		end
		local oldNamecall = mt.__namecall
		if not oldNamecall then
			log("HOOK: __namecall nil")
			return
		end
		local getMethod = getnamecallmethod or namecallmethod
		if not getMethod then
			log("HOOK: no getnamecallmethod")
			getMethod = function() return nil end
		end
		setreadonly(mt, false)
		mt.__namecall = newcclosure(function(self, ...)
			local anim = ...
			local ok, err = pcall(function()
				if getMethod() == "LoadAnimation"
				and typeof(self) == "Instance"
				and self:IsA("Animator") then
					hookFire = hookFire + 1
					if hookFire <= 10 then
						log("HOOK FIRE " .. hookFire .. ": id=" .. tostring(anim and typeof(anim) == "Instance" and anim.AnimationId))
					end
					if typeof(anim) == "Instance" and anim:IsA("Animation") then
						swapAnim(anim, "hook")
					end
				end
			end)
			if not ok then
				logerr(err, debug.traceback())
			end
			return oldNamecall(self, ...)
		end)
		setreadonly(mt, true)
		hookOk = true
		log("HOOK installed OK")
	end

	-- path 2: AnimationPlayed backup (replicated plays / anything the hook misses)
	local function attachAnimator(animator)
		if attached[animator] then return end
		attached[animator] = true
		animator.AnimationPlayed:Connect(function(track, anim)
			apFire = apFire + 1
			if apFire <= 15 then
				local animatorParent = animator.Parent
				log("AP FIRE " .. apFire .. ": id=" .. tostring(anim and anim.AnimationId)
					.. " animatorParent=" .. tostring(animatorParent and animatorParent.Name)
					.. " targetSet=" .. tostring(targetAsset ~= nil))
			end
			if not targetAsset then return end
			local id = anim.AnimationId
			if typeof(id) == "string" and emoteAssets[id] and id ~= targetAsset then
				track:Stop()
				local ok, err = pcall(function()
					local newAnim = Instance.new("Animation")
					newAnim.AnimationId = targetAsset
					newAnim.Parent = anim.Parent or animator:FindFirstAncestorOfClass("Humanoid")
					if not newAnim.Parent then
						newAnim:Destroy()
						return
					end
					local newTrack = animator:LoadAnimation(newAnim)
					newTrack.Looped = track.Looped
					newTrack.Priority = track.Priority
					newTrack:Play(track.TimePosition)
					spoofed[track] = newTrack
					track.Stopped:Connect(function()
						local t = spoofed[track]
						if t and t.IsPlaying then
							t:Stop()
						end
						spoofed[track] = nil
					end)
				end)
				if not ok then
					logerr(err, debug.traceback())
				else
					spoofCount = spoofCount + 1
					if spoofCount <= 5 then
						log("SWAP " .. spoofCount .. " [AP]: " .. id .. " -> " .. targetAsset)
					end
				end
			end
		end)
	end

	local function attachCharacter(char)
		if not char then return end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
			task.spawn(function()
				for _ = 1, 50 do
					task.wait(0.2)
					local animator = humanoid:FindFirstChildOfClass("Animator")
					if animator then
						attachAnimator(animator)
						log("animator attached: " .. char.Name)
						break
					end
				end
			end)
	end

	-- path 3: patch replicated Animation instances before the engine plays them
	local function watchPatch()
		local char = lp.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.DescendantAdded:Connect(function(inst)
					if targetAsset and inst:IsA("Animation") then
						swapAnim(inst, "patch")
					end
				end)
				task.spawn(function()
					local sweepCount = 0
					while true do
						task.wait(0.3)
						if targetAsset then
							sweepCount = sweepCount + 1
							local total = 0
							for _, inst in ipairs(hum:GetDescendants()) do
								if inst:IsA("Animation") then
									total = total + 1
									swapAnim(inst, "sweep")
								end
							end
							if sweepCount == 1 then
								log("SWEEP first run: " .. total .. " animations in humanoid")
							end
						end
					end
				end)
			end
		end
		Workspace.DescendantAdded:Connect(function(inst)
			if targetAsset and inst:IsA("Animation") then
				swapAnim(inst, "wsPatch")
			end
		end)
		log("watch installed (patch replicated animations)")
	end

	lp.CharacterAdded:Connect(attachCharacter)
	lp.CharacterAdded:Connect(watchPatch)
	pcall(attachCharacter, lp.Character)
	pcall(watchPatch)
	installDebug()

	-- ---------- GUI ----------
	local gui = Instance.new("ScreenGui")
	gui.Name = "EmoteSpoof"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = pg
	log("GUI parented to PlayerGui")
	pcall(writefile, "EmoteSpoof_probe.txt", "L2 gui created\n")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 280, 0, 200)
	frame.Position = UDim2.new(0.5, -140, 0, 30)
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
	title.Text = "Emote Spoofer"
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
	status.Text = "Starting..."
	status.TextColor3 = Color3.fromRGB(220, 220, 220)
	status.Font = Enum.Font.Code
	status.TextSize = 11
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextWrapped = true
	status.Parent = frame

	setStatus = function(text)
		status.Text = tostring(text)
	end

	local selBox = Instance.new("TextBox")
	selBox.Size = UDim2.new(1, -16, 0, 28)
	selBox.Position = UDim2.new(0, 8, 0, 56)
	selBox.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	selBox.BorderSizePixel = 0
	selBox.Text = "OFF"
	selBox.TextColor3 = Color3.fromRGB(220, 220, 220)
	selBox.Font = Enum.Font.Code
	selBox.TextSize = 11
	selBox.TextXAlignment = Enum.TextXAlignment.Center
	selBox.ClearTextOnFocus = false
	selBox.Parent = frame

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 6)
	boxCorner.Parent = selBox

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
	local closeBtn = makeBtn("X", 236, 20)

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
		if targetAsset then
			setStatus("Spoofing -> " .. targetName)
		else
			setStatus("OFF - emotes play normally")
		end
	end

	local function flushControllerCache()
		local ok, knit = pcall(require, ReplicatedStorage.Packages.Knit)
		if not ok or type(knit) ~= "table" then
			log("CACHE flush: knit require failed")
			return
		end
		local ok2, ctrl = pcall(function()
			return knit.GetController("AnimationController")
		end)
		if ok2 and ctrl and type(ctrl) == "table" and ctrl.LoadedAnimations then
			local removed = 0
			for _, e in ipairs(emotes) do
				if ctrl.LoadedAnimations[e.id] then
					ctrl.LoadedAnimations[e.id] = nil
					removed = removed + 1
				end
			end
			log("CACHE flushed (removed " .. removed .. " emote tracks, walk/idle kept)")
		else
			log("CACHE flush: controller not accessible")
		end
	end

	local ctrlLog = 0
	local animCtrl, invSvc, interfaceCtrl = nil, nil, nil
	local pendingPlay = nil

	local function forcePlayEmote(pe)
		if not pe then return end
		local okState, State = pcall(require, ReplicatedStorage.Common.State)
		local now = workspace:GetServerTimeNow()
		if okState and State and State.Id and State.Id.Debounce then
			local cur = State.get(lp, State.Id.Debounce, "EmoteDebounce", 0)
			if cur and cur > now then
				log("FORCE PLAY skipped: debounce active until " .. tostring(cur))
				return
			end
			State.set(lp, State.Id.Debounce, "EmoteDebounce", now + 1)
		end
		pendingPlay = nil
		if not animCtrl then
			log("FORCE PLAY failed: AnimationController not accessible")
			return
		end
		log("FORCE PLAY: " .. pe.name .. " (" .. pe.id .. ") via game controller")
		pcall(function() animCtrl:PlayAnimation(pe.id) end)
		if invSvc then
			pcall(function() invSvc:Use(pe.id) end)
			local okLen, len = pcall(function()
				return animCtrl:GetAnimationLength(pe.id)
			end)
			if okLen and len then
				task.delay(len, function()
					pcall(function() invSvc:StopEmotes() end)
				end)
			end
		end
	end

	local function hookWheelFunctions()
		local ok, knit = pcall(require, ReplicatedStorage.Packages.Knit)
		if not ok or type(knit) ~= "table" then
			log("WHEEL HOOK: knit require failed")
			return
		end
		local ok2, ctrl = pcall(function()
			return knit.GetController("AnimationController")
		end)
		if ok2 and ctrl and type(ctrl) == "table" then
			animCtrl = ctrl
			for _, name in ipairs({ "PlayAnimation", "GetAnimationLength", "StopAllEmotes", "ClearAllAnimations" }) do
				if type(ctrl[name]) == "function" then
					local old = ctrl[name]
					local original = hookfunction(old, newcclosure(function(self, ...)
						local a1 = ...
						ctrlLog = ctrlLog + 1
						if ctrlLog <= 20 then
							log("CTRL " .. name .. "(" .. tostring(a1) .. ")")
						end
						if name == "PlayAnimation" and pendingPlay and pendingPlay.id == tostring(a1) then
							pendingPlay = nil
						end
						return original(self, ...)
					end))
					log("hooked CTRL " .. name)
				end
			end
		else
			log("WHEEL HOOK: AnimationController not accessible")
		end
		local ok3, inv = pcall(function()
			return knit.GetService("InventoryService")
		end)
		if ok3 and inv and type(inv) == "table" then
			invSvc = inv
			for _, name in ipairs({ "Use", "StopEmotes" }) do
				if type(inv[name]) == "function" then
					local old = inv[name]
					local original = hookfunction(old, newcclosure(function(self, ...)
						local a1 = ...
						ctrlLog = ctrlLog + 1
						if ctrlLog <= 20 then
							log("SVC " .. name .. "(" .. tostring(a1) .. ")")
						end
						return original(self, ...)
					end))
					log("hooked SVC " .. name)
				end
			end
		else
			log("WHEEL HOOK: InventoryService not accessible")
		end
		local ok4, ic = pcall(function()
			return knit.GetController("InterfaceController")
		end)
		if ok4 and ic and type(ic) == "table" then
			interfaceCtrl = ic
			log("WHEEL HOOK: InterfaceController accessible")
		end
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
		local name = selBox.Text
		for _, e in ipairs(emotes) do
			if e.name == name or e.id == name then
				targetAsset = e.asset
				targetName = e.name
				log("APPLY: " .. targetName .. " (" .. targetAsset .. ")")
				flushControllerCache()
				updateStatus()
				return
			end
		end
		targetAsset = nil
		targetName = "OFF"
		updateStatus()
	end)

	resetBtn.MouseButton1Click:Connect(function()
		targetAsset = nil
		targetName = "OFF"
		selBox.Text = "OFF"
		updateStatus()
		flushControllerCache()
		log("RESET")
	end)

	closeBtn.MouseButton1Click:Connect(function()
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

	-- keep-alive: re-parent if the game clears PlayerGui
	local guiDestroyed = false
	gui.Destroying:Connect(function()
		guiDestroyed = true
	end)
	task.spawn(function()
		while not guiDestroyed do
			task.wait(0.5)
			if not guiDestroyed and gui.Parent == nil then
				gui.Parent = pg
				log("GUI re-parented to PlayerGui")
			end
		end
	end)

	log("spoof engine attached (AnimationPlayed path ready)")
	installHook()

	loadEmotes()
	if #emotes == 0 then
		setStatus("No emotes found")
	else
		setStatus("Emotes: " .. #emotes)
		selBox.Text = emotes[emoteIndex].name
	end
	local function hookWheelButtons()
		local function tryHook(btn, name)
			if btn:FindFirstChild("EmoteSpoofHooked") then return end
			local tag = Instance.new("StringValue")
			tag.Name = "EmoteSpoofHooked"
			tag.Parent = btn
			local ev = btn.Activated
			if not ev then return end
			ev:Connect(function()
				local lp2 = Players.LocalPlayer
				local char = lp2 and lp2.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local md = hum and hum.MoveDirection
				log("WHEELBTN pressed: " .. name
					.. " moving=" .. tostring(md and md.Magnitude > 0)
					.. " health=" .. tostring(hum and hum.Health)
					.. " parent=" .. tostring(btn.Parent and btn.Parent.Name))
				local slotName = ""
				local dn = btn:FindFirstChild("DisplayName")
				if dn and dn:IsA("TextLabel") then slotName = dn.Text end
				local slotEmote = nil
				for _, e in ipairs(emotes) do
					if e.name == slotName then
						slotEmote = e
						break
					end
				end
				if not slotEmote then
					log("WHEELBTN slot unknown: displayName='" .. tostring(slotName) .. "'")
					return
				end
				local selVal = "?"
				if interfaceCtrl then
					pcall(function()
						local s = interfaceCtrl.SelectedEquippable
						if s and s.get then selVal = tostring(s:get()) end
					end)
				end
				log("WHEELBTN slot: " .. slotEmote.name .. " id=" .. slotEmote.id
					.. " selected=" .. selVal)
				local token = os.clock()
				pendingPlay = { id = slotEmote.id, name = slotEmote.name, token = token }
				task.delay(0.3, function()
					if pendingPlay and pendingPlay.token == token then
						forcePlayEmote(pendingPlay)
					end
				end)
			end)
		end
		pg.DescendantAdded:Connect(function(inst)
			if inst:IsA("GuiButton") and (inst.Name == "EmoteOpenerBtn" or tostring(inst.Name):match("^WheelButton_")) then
				tryHook(inst, inst.Name)
			end
		end)
		for _, inst in ipairs(pg:GetDescendants()) do
			if inst:IsA("GuiButton") and (inst.Name == "EmoteOpenerBtn" or tostring(inst.Name):match("^WheelButton_")) then
				tryHook(inst, inst.Name)
			end
		end
		log("wheel UI watcher installed")
	end

	updateStatus()
	log("READY")
	hookWheelFunctions()
	hookWheelButtons()

	-- diagnostics probe: is the GUI actually rendered and where?
	task.delay(2, function()
		local okf, fx, fy, fw, fh = pcall(function()
			local a = frame.AbsolutePosition
			local b = frame.AbsoluteSize
			return a.X, a.Y, b.X, b.Y
		end)
		local okr, res = pcall(function()
			return GuiService:GetScreenResolution()
		end)
		log("PROBE: parent=" .. tostring(gui.Parent and gui.Parent.Name)
			.. " enabled=" .. tostring(gui.Enabled)
			.. " framePos=" .. tostring(fx) .. "," .. tostring(fy)
			.. " frameSize=" .. tostring(fw) .. "x" .. tostring(fh)
			.. " screen=" .. tostring(res)
			.. " desc=" .. tostring(gui:IsDescendantOf(game)))
	end)
end

local ok, err = xpcall(main, function(e)
	logerr(e, debug.traceback("", 2))
end)
if not ok then
	log("FATAL: main() failed to complete")
end
