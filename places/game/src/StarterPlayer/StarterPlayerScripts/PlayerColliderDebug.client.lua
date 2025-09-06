-- PlayerColliderDebug.client.lua
-- Visualizes player collision boxes via SelectionBox instances.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage.Modules.combinedFunctions.Maid)

local eventsFolder = ReplicatedStorage:FindFirstChild("DebugEvents")
local flagsFolder = ReplicatedStorage:FindFirstChild("DebugFlags")

local debugEvent = eventsFolder and eventsFolder:FindFirstChild("PlayerColliders")
local flagValue = flagsFolder and flagsFolder:FindFirstChild("PlayerColliders")

local activeMaid = Maid.new()

local function addBoxes(character, charMaid)
        local function attach(inst)
                if inst:IsA("BasePart") then
                        local box = Instance.new("SelectionBox")
                        box.Adornee = inst
                        box.LineThickness = 0.05
                        box.SurfaceTransparency = 1
                        box.Parent = inst
                        charMaid:GiveInstance(box)
                end
        end

        for _, inst in ipairs(character:GetDescendants()) do
                attach(inst)
        end

        charMaid:GiveSignal(character.DescendantAdded, attach)
end

local function watchPlayer(player)
        local pMaid = Maid.new()
        activeMaid:GiveCleanup(tostring(player.UserId), function()
                pMaid:Destroy()
        end)

        local function onCharacter(char)
                pMaid:EndAllTasks()
                local cMaid = Maid.new()
                pMaid:GiveCleanup("char", function()
                        cMaid:Destroy()
                end)
                cMaid:BindToInstance(char)
                addBoxes(char, cMaid)
        end

        if player.Character then
                onCharacter(player.Character)
        end
        pMaid:GiveSignal(player.CharacterAdded, onCharacter)
end

local function enable()
        for _, plr in ipairs(Players:GetPlayers()) do
                watchPlayer(plr)
        end
        activeMaid:GiveSignal(Players.PlayerAdded, watchPlayer)
        activeMaid:GiveSignal(Players.PlayerRemoving, function(plr)
                activeMaid:EndTaskByTaskId(tostring(plr.UserId))
        end)
end

local function disable()
        activeMaid:EndAllTasks()
end

local function setEnabled(v)
        disable()
        if v then
                enable()
        end
end

if debugEvent then
        debugEvent.Event:Connect(setEnabled)
end

if flagValue and flagValue:IsA("BoolValue") then
        setEnabled(flagValue.Value)
        flagValue.Changed:Connect(function()
                setEnabled(flagValue.Value)
        end)
end

