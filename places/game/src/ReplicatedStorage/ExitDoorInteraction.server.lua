-- ExitDoorInteraction.server.lua
--[[
  Door Exit Interaction
  ---------------------
  Purpose:
    - When a player touches the door, move the whole nearby group to the next level.
    - Block exit until floor objectives are completed.
    - Resolve MapBuilder robustly and optional Utils facade (ObjectiveManager support).

  Usage:
    - Place this Script under the door Model. Ensure Model.PrimaryPart is set.
    - (Optional) Set Attribute "TargetLevel" on the door model to override the target map.
]]

local doorModel = script.Parent
local primaryPart = doorModel and doorModel.PrimaryPart
if not primaryPart then
	warn("[ExitDoorInteraction] Missing PrimaryPart on door model.")
	return
end

local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")

-- --- Resolve MapBuilder anywhere under ServerScriptService ---
local MapBuilderModule = SSS:FindFirstChild("MapBuilder", true)
if not MapBuilderModule then
	warn("[ExitDoorInteraction] MapBuilder not found under ServerScriptService.")
	return
end
local MapBuilder = require(MapBuilderModule)

-- --- Resolve Utils facade (optional) to access ObjectiveManager ---
local Utils do
	local Modules = RS:FindFirstChild("Modules")
	local cf = Modules and Modules:FindFirstChild("combinedFunctions")
	if cf then
		local ok, res = pcall(function()
			if cf:IsA("ModuleScript") then
				return require(cf)
			else
				local init = cf:FindFirstChild("Init") or cf:FindFirstChild("init")
				return init and require(init) or nil
			end
		end)
		if ok then Utils = res end
	end
end

local ObjectiveManager = Utils and Utils.objectives and Utils:objectives() or nil

-- --- Config ---
local GROUP_RADIUS = 16        -- studs around the door to bring teammates
local TOUCH_DEBOUNCE = 2.0     -- seconds per player
local isTransitioning = false  -- global guard per-door script
local touchLock: {[number]: number} = {}

-- Helpers
local function getNearbyPlayers(center: Vector3, radius: number)
	local players = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - center).Magnitude <= radius then
			table.insert(players, plr)
		end
	end
	return players
end

local function canLeaveFloor(): boolean
	-- If we have an ObjectiveManager, require all objectives done. Otherwise allow.
	if ObjectiveManager and ObjectiveManager.allDone then
		local ok, done = pcall(function() return ObjectiveManager:allDone() end)
		if ok then return done == true end
	end
	return true
end

-- Allow door model attribute to dictate the next level; default fallback provided.
local function getTargetLevel(): string
	return doorModel:GetAttribute("TargetLevel") or "Backrooms (level 1)"
end

-- Main touch handler
primaryPart.Touched:Connect(function(hit)
	if isTransitioning then return end

	local char = hit and hit.Parent
	local player = char and Players:GetPlayerFromCharacter(char)
	if not player then return end

	local now = time()
	local last = touchLock[player.UserId] or 0
	if (now - last) < TOUCH_DEBOUNCE then return end
	touchLock[player.UserId] = now

	-- Gate: objectives must be completed
	if not canLeaveFloor() then
		-- TODO: fire UI/Hint to player here (e.g., RemoteEvent) to say "Objectives incomplete"
		-- print("[ExitDoorInteraction] Objectives not complete yet.")
		return
	end

	if isTransitioning then return end
	isTransitioning = true

	local targetLevel = getTargetLevel()
	print(("[ExitDoor] %s triggered exit → %s"):format(player.Name, targetLevel))

	-- Generate next map (MapBuilder handles wiping old map & setting start position)
	-- (Optionally pass a seed as 2nd arg if you want deterministic chaining)
	local startPosition = MapBuilder.Generate(targetLevel)

	-- Teleport nearby group (including the toucher)
	if startPosition then
		local toMove = getNearbyPlayers(primaryPart.Position, GROUP_RADIUS)
		if #toMove == 0 then
			table.insert(toMove, player) -- at least move the toucher
		end
		for _, plr in ipairs(toMove) do
			local c = plr.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			if c and root then
				-- Slight vertical offset to avoid clipping on spawn
				local cf = CFrame.new(startPosition + Vector3.new(0, 3, 0))
				-- guard against character being nil while map swaps
				pcall(function()
					c:SetPrimaryPartCFrame(cf)
				end)
			end
		end
	else
		warn("[ExitDoorInteraction] MapBuilder.Generate returned nil startPosition.")
	end

	-- If this script survives the map swap, allow future transitions after a brief delay
	task.delay(2.0, function()
		isTransitioning = false
	end)
end)
