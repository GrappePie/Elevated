-- Creates RemoteEvents in ReplicatedStorage if missing.
-- Routes generic DebugToggleEvent(key, enabled) to flags and debug events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Maid = require(ReplicatedStorage.Modules.combinedFunctions.Maid)

local DEBUG_FLAGS_FOLDER = "DebugFlags"
local DEBUG_EVENTS_FOLDER = "DebugEvents"

local flagsFolder = ReplicatedStorage:FindFirstChild(DEBUG_FLAGS_FOLDER)
if not flagsFolder then
        flagsFolder = Instance.new("Folder")
        flagsFolder.Name = DEBUG_FLAGS_FOLDER
        flagsFolder.Parent = ReplicatedStorage
end

local eventsFolder = ReplicatedStorage:FindFirstChild(DEBUG_EVENTS_FOLDER)
if not eventsFolder then
        eventsFolder = Instance.new("Folder")
        eventsFolder.Name = DEBUG_EVENTS_FOLDER
        eventsFolder.Parent = ReplicatedStorage
end

local flagMaids = {}

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

local function toFlagName(key: string)
        local flagName = key:gsub("_(%w)", function(s)
                return s:upper()
        end)
        return flagName:sub(1,1):upper() .. flagName:sub(2)
end

local function updateFlag(key: string, enabled: boolean)
        local flagName = toFlagName(key)

        local flag = flagsFolder:FindFirstChild(flagName)
        if not flag then
                flag = Instance.new("BoolValue")
                flag.Name = flagName
                flag.Parent = flagsFolder
        end
        flag.Value = enabled

        local event = eventsFolder:FindFirstChild(flagName)
        if not event then
                event = Instance.new("BindableEvent")
                event.Name = flagName
                event.Parent = eventsFolder
        end
        event:Fire(enabled)

        local maid = flagMaids[flagName]
        if maid then
                maid:EndAllTasks()
        else
                maid = Maid.new()
                flagMaids[flagName] = maid
        end
        maid:GiveSignal(flag.Changed, function(value)
                event:Fire(value)
        end)
end

debugToggleEvent.OnServerEvent:Connect(function(_player, key, enabled)
        updateFlag(tostring(key), not not enabled)
end)

-- Example: forward MonsterDebugEvent to your AI system
local monsterEvent = ensureRemote("MonsterDebugEvent")
monsterEvent.OnServerEvent:Connect(function(player, enabled)
        print(("[MonsterDebug] %s set VisionCones = %s"):format(player.Name, tostring(enabled)))
        -- TODO: forward to your monster system (BindableEvent, module, etc.)
end)
