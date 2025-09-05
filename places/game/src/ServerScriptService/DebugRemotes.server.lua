-- Creates RemoteEvents in ReplicatedStorage if missing.
-- Routes generic DebugToggleEvent(key, enabled) to prints or to other systems.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureRemote(name)
	local ev = ReplicatedStorage:FindFirstChild(name)
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = ReplicatedStorage
	end
	return ev
end

-- Dedicated event already used by monsters (client will call this)
ensureRemote("MonsterDebugEvent")

-- Generic key-based toggles
local debugToggleEvent = ensureRemote("DebugToggleEvent")

-- Example: React to generic toggles here (print/log or forward to systems)
debugToggleEvent.OnServerEvent:Connect(function(player, key, enabled)
	print(("[DebugToggle] %s set '%s' = %s"):format(player.Name, tostring(key), tostring(enabled)))

	-- TODO: route to your systems. Examples:
	--  if key == "elevator_sensors" then
	--      -- Set a global BoolValue that your Elevator script reads periodically:
	--      local flagsFolder = ReplicatedStorage:FindFirstChild("DebugFlags") or Instance.new("Folder", ReplicatedStorage)
	--      flagsFolder.Name = "DebugFlags"
	--      local flag = flagsFolder:FindFirstChild("ElevatorSensors") or Instance.new("BoolValue", flagsFolder)
	--      flag.Name = "ElevatorSensors"
	--      flag.Value = enabled
	--  elseif key == "elevator_music" then
	--      -- Same approach; your Elevator script can listen to .Changed on the BoolValue
	--  elseif key == "ai_paths" then
	--      -- Broadcast to your AI manager via BindableEvent, etc.
	--  end
end)

-- Example: forward MonsterDebugEvent to your AI system
local monsterEvent = ensureRemote("MonsterDebugEvent")
monsterEvent.OnServerEvent:Connect(function(player, enabled)
	print(("[MonsterDebug] %s set VisionCones = %s"):format(player.Name, tostring(enabled)))
	-- TODO: forward to your monster system (BindableEvent, module, etc.)
end)