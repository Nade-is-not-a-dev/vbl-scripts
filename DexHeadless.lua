-- DexHeadless Dumper v2 (resume-friendly)
-- Targets game code only: ReplicatedStorage, StarterPlayer, StarterGui, PlayerGui
-- Skips Roblox built-in (CorePackages/CoreGui). Resumes where it left off.
-- Writes instance tree incrementally so a crash never loses progress.

local ROOT = "DexHeadless"
local CODE_DIR = ROOT .. "/code"
local TREE_FILE = ROOT .. "/instance_tree.txt"
local SUMMARY_FILE = ROOT .. "/summary.txt"

local TARGET_ROOTS = { "ReplicatedStorage", "StarterPlayer", "StarterGui", "PlayerGui", "ReplicatedFirst", "Workspace" }
local SKIP_ROOTS = { CorePackages = true, CoreGui = true, Lighting = true, SoundService = true }

local PLACEHOLDER = "-- failed"

local function safeWrite(path, content)
	local ok, err = pcall(function()
		if not isfile then error("writefile unavailable") end
		writefile(path, content)
	end)
	if not ok then
		warn("[DexHeadless] write failed: " .. path .. " -> " .. tostring(err))
	end
	return ok
end

local function appendToFile(path, content)
	pcall(function()
		if isfile(path) then
			appendfile(path, content)
		else
			writefile(path, content)
		end
	end)
end

local function init()
	if not pcall(function() return isfile end) then
		error("Executor does not support filesystem (writefile/isfile). Aborting.")
	end
	if not isfolder(ROOT) then makefolder(ROOT) end
	if not isfolder(CODE_DIR) then makefolder(CODE_DIR) end
end

local counts = { instances = 0, scripts = 0, source = 0, decompiled = 0, bytecode = 0, locked = 0, skipped = 0 }
local lockedScripts = {}
local usedPaths = {}
local treeBuffer = {}

local function makePathKey(inst)
	local full = inst:GetFullName()
	local key = full:gsub("[<>:\"/\\|?*%%]", "_")
	if #key > 120 then
		key = key:sub(1, 80) .. "_" .. key:sub(-35)
	end
	local base = key
	local n = 1
	while usedPaths[key] do
		n = n + 1
		key = base .. "_" .. n
	end
	usedPaths[key] = true
	return key
end

local function dumpScript(script)
	counts.scripts = counts.scripts + 1
	local base = CODE_DIR .. "/" .. makePathKey(script)
	local ext = script:IsA("ModuleScript") and "module.lua"
		or (script:IsA("LocalScript") and "client.lua")
		or "server.lua"

	local src = ""
	local okSrc = pcall(function() src = script.Source end)
	if okSrc and src and src ~= "" then
		local path = base .. "." .. ext
		if isfile(path) then
			counts.skipped = counts.skipped + 1
			return "SKIPPED"
		end
		counts.source = counts.source + 1
		safeWrite(path, src)
		return "SOURCE"
	end

	local dec = nil
	local okDec = pcall(function()
		local fn = getgenv().decompile or decompile
		dec = fn(script)
	end)
	if okDec and type(dec) == "string" and #dec > 10 and not dec:find(PLACEHOLDER, 1, true) then
		local path = base .. ".decompiled." .. ext
		if isfile(path) then
			counts.skipped = counts.skipped + 1
			return "SKIPPED"
		end
		counts.decompiled = counts.decompiled + 1
		safeWrite(path, dec)
		return "DECOMPILED"
	end

	local bc = nil
	local okBc = pcall(function() bc = getscriptbytecode(script) end)
	if not okBc then okBc = pcall(function() bc = dumpstring(script) end) end
	if okBc and bc and bc ~= "" then
		local path = base .. "." .. ext .. ".lubc.hex.txt"
		if isfile(path) then
			counts.skipped = counts.skipped + 1
			return "SKIPPED"
		end
		counts.bytecode = counts.bytecode + 1
		local hex = (bc:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
		safeWrite(path, hex)
		table.insert(lockedScripts, script:GetFullName())
		return "BYTECODE"
	end

	counts.locked = counts.locked + 1
	table.insert(lockedScripts, script:GetFullName())
	return "LOCKED"
end

local function getCuratedProps(v)
	local props = {}
	local function tryGet(fn)
		local ok, val = pcall(fn)
		if ok and val ~= nil and val ~= "" then return val end
		return nil
	end
	local val = tryGet(function() return v.Value end)
	if val ~= nil then
		table.insert(props, "Value=" .. tostring(val))
	end
	local text = tryGet(function() return v.Text end)
	if text then
		table.insert(props, "Text=\"" .. tostring(text) .. "\"")
	end
	for _, p in ipairs({ "TextureId", "Texture", "MeshId" }) do
		local t = tryGet(function() return v[p] end)
		if t then
			table.insert(props, p .. "=" .. tostring(t))
		end
	end
	return table.concat(props, "  ")
end

local lastFlush = 0

local function flushTree()
	appendToFile(TREE_FILE, table.concat(treeBuffer, "\n") .. "\n")
	treeBuffer = {}
	lastFlush = 0
end

local function walk(inst, depth)
	counts.instances = counts.instances + 1
	local indent = string.rep("  ", depth)
	local props = getCuratedProps(inst)
	local line = indent .. inst.Name .. " [" .. inst.ClassName .. "]"
	local isScript = inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript")
	local status = ""
	if isScript then
		status = dumpScript(inst)
		line = line .. " <" .. status .. ">"
	elseif props ~= "" then
		line = line .. "  " .. props
	end
	treeBuffer[#treeBuffer + 1] = line

	lastFlush = lastFlush + 1
	if lastFlush >= 200 then
		flushTree()
	end
	if counts.instances % 50 == 0 then
		print("[DexHeadless] " .. counts.instances .. " inst, " .. counts.scripts .. " scripts, " .. counts.skipped .. " skipped")
		task.wait()
	end

	for _, child in ipairs(inst:GetChildren()) do
		walk(child, depth + 1)
	end
end

local function run()
	init()

	if isfile(TREE_FILE) then
		delfile(TREE_FILE)
	end
	safeWrite(ROOT .. "/dump_state.txt", "started at " .. os.time())

	local startTime = os.clock()

	for _, rootName in ipairs(TARGET_ROOTS) do
		local root = game:FindFirstChild(rootName)
		if root then
			print("[DexHeadless] walking " .. rootName .. " ...")
			walk(root, 0)
			flushTree()
		end
	end

	flushTree()

	local summaryLines = {}
	table.insert(summaryLines, "== DexHeadless Summary ==")
	table.insert(summaryLines, "Instance count      : " .. counts.instances)
	table.insert(summaryLines, "Script count        : " .. counts.scripts)
	table.insert(summaryLines, "  with Source       : " .. counts.source)
	table.insert(summaryLines, "  decompiled        : " .. counts.decompiled)
	table.insert(summaryLines, "  bytecode saved    : " .. counts.bytecode)
	table.insert(summaryLines, "  locked (no code)  : " .. counts.locked)
	table.insert(summaryLines, "  skipped (exists)  : " .. counts.skipped)
	table.insert(summaryLines, "Time taken          : " .. string.format("%.1fs", os.clock() - startTime))
	table.insert(summaryLines, "")
	table.insert(summaryLines, "== Locked scripts (bytecode or no client-side code) ==")
	for _, name in ipairs(lockedScripts) do
		table.insert(summaryLines, "  " .. name)
	end

	safeWrite(SUMMARY_FILE, table.concat(summaryLines, "\n"))
	safeWrite(ROOT .. "/dump_state.txt", "done at " .. os.time())

	print("[DexHeadless] DONE - " .. counts.instances .. " instances, " .. counts.scripts .. " scripts, " .. counts.skipped .. " skipped")
	print("[DexHeadless] files: " .. TREE_FILE .. ", " .. SUMMARY_FILE .. ", " .. CODE_DIR .. "/")
end

local okInit, initErr = pcall(run)
if not okInit then
	warn("[DexHeadless] FAILED: " .. tostring(initErr))
end
