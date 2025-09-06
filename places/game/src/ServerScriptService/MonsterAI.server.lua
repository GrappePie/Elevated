
-- MonsterAI.server.lua
-- Modular monster AI with state machine, automatic patrol points, and type-based behavior

-- === SERVICES & MODULES ===

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")

-- Use combinedFunctions init for modular utilities
local Combined = require(ReplicatedStorage.Modules.combinedFunctions)
local Animation = Combined:animation()
local Timer = Combined:timer()
local Tween = Combined:tween()
-- Fast vector utilities (optional, provides cone checks and fast magnitude functions)
local okFV, FastVector = pcall(function()
    return require(ReplicatedStorage.Modules.FastVector).new()
end)
if not okFV then
    warn("FastVector module not found or failed to load; using built-in vision math")
    FastVector = nil
end


-- State tables
local MonsterAIControllers = {}
local MonsterAnimState = {}
local MonsterAttackCooldown = {}
local MonsterNoticeState = {}
local MonsterState = {}
local MonsterTarget = {}
local MonsterLastSeen = {}
local MonsterPatrolPoints = {}
local MonsterPatrolIndex = {}
local MonsterType = {}


local CHASE_PERSIST = 2.5 -- seconds to keep chasing after losing sight


-- Animation asset IDs (replace with your own as needed)
local ANIMATIONS = {
    Idle = "rbxassetid://507766388",
    Walk = "rbxassetid://507777826",
    Run  = "rbxassetid://616163682",
    Attack = "rbxassetid://507777826",
}

local VISION_ANGLE = math.rad(60)
local VISION_DISTANCE = 30

-- Monster type definitions
local MONSTER_TYPES = {
    Hallway = {
        name = "Hallway",
        patrolFilter = function(part)
            -- Only patrol parts named "Hallway" or tagged as such
            return part.Name:lower():find("hallway") or (part:GetAttribute("IsHallway") == true)
        end,
        canEnterRooms = false,
        canEnterVents = false,
    },
    Vent = {
        name = "Vent",
        patrolFilter = function(part)
            -- Only patrol parts named "Vent" or tagged as such
            return part.Name:lower():find("vent") or (part:GetAttribute("IsVent") == true)
        end,
        canEnterRooms = false,
        canEnterVents = true,
        attackOnlyIfAlone = true,
    },
    -- Add more types here
}

-- Clean up all monster state and resources
local function cleanupMonster(monsterModel)
    if not monsterModel then
        return
    end

    -- Remove from controller map
    MonsterAIControllers[monsterModel.Name] = nil

    -- Stop and destroy any animation tracks
    local state = MonsterAnimState[monsterModel]
    if state and state.tracks then
        for _, track in pairs(state.tracks) do
            pcall(function()
                track:Destroy()
            end)
        end
    end

    -- Stop and remove lingering sounds
    for _, obj in ipairs(monsterModel:GetDescendants()) do
        if obj:IsA("Sound") then
            pcall(function()
                obj:Stop()
                obj:Destroy()
            end)
        end
    end

    -- Remove vision cone adornment if present
    local head = monsterModel:FindFirstChild("Head")
    if head then
        local cone = head:FindFirstChild("VisionCone")
        if cone then
            cone:Destroy()
        end
    end

    -- Clear state tables
    MonsterAnimState[monsterModel] = nil
    MonsterAttackCooldown[monsterModel] = nil
    MonsterNoticeState[monsterModel] = nil
    MonsterState[monsterModel] = nil
    MonsterTarget[monsterModel] = nil
    MonsterLastSeen[monsterModel] = nil
    MonsterPatrolPoints[monsterModel] = nil
    MonsterPatrolIndex[monsterModel] = nil
    MonsterType[monsterModel] = nil
end

-- === UTIL / ANIMATIONS ===
local function playMonsterAnimation(monster, animType)
    if not monster or not monster.Parent then return end
    local humanoid = monster:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    if not MonsterAnimState[monster] then MonsterAnimState[monster] = { tracks = {} } end
    local state = MonsterAnimState[monster]
    local tracks = state.tracks
    if state.currentTrack and state.currentType ~= animType then
        state.currentTrack:Stop(0.1)
    end
    if state.currentType ~= animType then
        local track = tracks[animType]
        if not track then
            local anim = Instance.new("Animation")
            anim.Name = "_monster_anim"
            anim.AnimationId = ANIMATIONS[animType] or ANIMATIONS.Idle
            track = humanoid:LoadAnimation(anim)
            tracks[animType] = track
            Debris:AddItem(anim, 2)
        end
        track:Play(0.1)
        state.currentTrack = track
        state.currentType = animType
    end
end

local function setIdle(monster)
    playMonsterAnimation(monster, "Idle")
end

local function playAttackAnimation(monster)
    playMonsterAnimation(monster, "Attack")
end

local function playNotice(monster)
    local head = monster:FindFirstChild("Head")
    if head then
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://4929575301"
        s.Volume = 1.2
        s.Parent = head
        s:Play()
        Debris:AddItem(s, 3)
    end
end

local function playAttackEffects(monster)
    local head = monster:FindFirstChild("Head")
    if head then
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://406913243"
        sound.Volume = 1
        sound.Parent = head
        sound:Play()
        Debris:AddItem(sound, 2)
        local particle = Instance.new("ParticleEmitter")
        particle.Texture = "rbxassetid://243660364"
        particle.Lifetime = NumberRange.new(0.2)
        particle.Rate = 100
        particle.Speed = NumberRange.new(8,12)
        particle.Parent = head
        particle:Emit(20)
        Debris:AddItem(particle, 1)
    end
end

-- === VISION & AI HELPERS ===
local function updateVisionConeColor(monster, detected)
    local head = monster and monster:FindFirstChild("Head")
    if not head then return end
    local cone = head:FindFirstChild("VisionCone")
    if cone then
        if detected then
            cone.Color3 = Color3.fromRGB(255, 140, 0)
        else
            cone.Color3 = Color3.fromRGB(0, 255, 255)
        end
    end
end

local function isPlayerInVision(monster, playerChar)
    -- Use FastVector if available to check cone + height + distance, then raycast for LOS
    local head = monster and monster:FindFirstChild("Head")
    local targetHead = playerChar and playerChar:FindFirstChild("Head")
    if not head or not targetHead then return false end

    -- FastVector path
    if FastVector then
        -- Build config: HeightMin, HeightMax, MagnitudeXZ, ConeAngle (degrees), LookVector, Origin, CheckPos
        local cfg = FastVector:BuildConfig(-3, 3, VISION_DISTANCE, math.deg(VISION_ANGLE), head.CFrame.LookVector, head.Position, targetHead.Position)
        local inCone = FastVector:CalculateScalarBounds2D3D(cfg)
        if not inCone then return false end
        -- Raycast to ensure not obstructed
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {monster}
        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
        rayParams.IgnoreWater = true
        local dir = (targetHead.Position - head.Position)
        local result = workspace:Raycast(head.Position, dir, rayParams)
        if result then
            if result.Instance and result.Instance:IsDescendantOf(playerChar) then
                return true
            end
            return false
        end
        return true
    end

    -- Fallback: original math-based check
    local dir = (targetHead.Position - head.Position)
    local dist = dir.Magnitude
    if dist > VISION_DISTANCE then return false end
    dir = dir.Unit
    local look = head.CFrame.LookVector
    local dot = look:Dot(dir)
    if dot > 1 then dot = 1 elseif dot < -1 then dot = -1 end
    local angle = math.acos(dot)
    -- Raycast fallback
    if angle <= VISION_ANGLE/2 then
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {monster}
        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
        rayParams.IgnoreWater = true
        local result = workspace:Raycast(head.Position, (targetHead.Position - head.Position), rayParams)
        if result then
            return result.Instance and result.Instance:IsDescendantOf(playerChar)
        end
        return true
    end
    return false
end


-- Move monster to next patrol point using pathfinding
local function patrol(monster)
    local humanoid = monster:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    playMonsterAnimation(monster, "Walk")
    humanoid.WalkSpeed = 8
    local points = MonsterPatrolPoints[monster]
    if not points or #points == 0 then return end
    local idx = MonsterPatrolIndex[monster] or 1
    local nextPoint = points[idx]
    if not nextPoint then return end
    -- Pathfinding
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = 7,
        AgentMaxSlope = 45,
        WaypointSpacing = 4,
        Costs = {},
    })
    local MOVE_TIMEOUT = 5
    local function followPath(pathObj)
        for _, waypoint in ipairs(pathObj:GetWaypoints()) do
            humanoid:MoveTo(waypoint.Position)
            local reached = false
            local conn
            conn = humanoid.MoveToFinished:Connect(function()
                reached = true
            end)
            local start = os.clock()
            while not reached and os.clock() - start <= MOVE_TIMEOUT do
                if (monster.PrimaryPart.Position - waypoint.Position).Magnitude <= 2 then
                    reached = true
                    break
                end
                task.wait()
            end
            conn:Disconnect()
            if not reached then
                return false
            end
        end
        return true
    end

    path:ComputeAsync(monster.PrimaryPart.Position, nextPoint.Position)
    if path.Status == Enum.PathStatus.Complete then
        if not followPath(path) then
            warn("[MonsterAI] Patrol move timed out; recalculating path.")
            path:ComputeAsync(monster.PrimaryPart.Position, nextPoint.Position)
            if path.Status == Enum.PathStatus.Complete then
                if not followPath(path) then
                    warn("[MonsterAI] Patrol move timed out again; skipping point.")
                end
            else
                warn("[MonsterAI] Pathfinding failed after timeout; skipping point.")
            end
        end
    else
        warn("[MonsterAI] Pathfinding failed for patrol.")
    end
    -- Advance patrol index
    MonsterPatrolIndex[monster] = (idx % #points) + 1
end


-- Monster chase and attack logic with state messages
local function chaseAndAttack(monster, target)
    if not monster or not monster.Parent then return end
    local humanoid = monster:FindFirstChildOfClass("Humanoid")
    if humanoid and target and target:FindFirstChild("HumanoidRootPart") then
        if not MonsterNoticeState[monster] then
            playNotice(monster)
            MonsterNoticeState[monster] = true
        end
        humanoid.WalkSpeed = 20
        playMonsterAnimation(monster, "Run")
        print("[MonsterAI] " .. monster.Name .. " is chasing " .. (target.Name or "player"))
        humanoid:MoveTo(target.HumanoidRootPart.Position)
        local primary = monster.PrimaryPart or monster:FindFirstChild("HumanoidRootPart")
        if primary then
            local dist = (primary.Position - target.HumanoidRootPart.Position).Magnitude
            if dist < 4 then
                local now = os.clock()
                if not MonsterAttackCooldown[monster] or now - MonsterAttackCooldown[monster] > 1.5 then
                    MonsterAttackCooldown[monster] = now
                    local targetHum = target:FindFirstChildOfClass("Humanoid")
                    if targetHum then
                        targetHum:TakeDamage(10)
                        playAttackAnimation(monster)
                        playAttackEffects(monster)
                        print("[MonsterAI] " .. monster.Name .. " attacked " .. (targetHum.Parent.Name or "player"))
                    end
                end
            end
        end
    end
end

local function setIdleIfNotMoving(monster)
    local humanoid = monster:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.MoveDirection.Magnitude == 0 then
        setIdle(monster)
    end
end

local function getAllMonsterRigs()
    local monsters = {}
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("Humanoid") and model:FindFirstChild("Head") then
            table.insert(monsters, model)
        end
    end
    return monsters
end


-- Setup AI for a monster model, assign type, and generate patrol points
local function setupMonsterAI(monsterModel)
    if not monsterModel or not monsterModel.Parent then return end
    -- Assign monster type by attribute or fallback to Hallway
    local mTypeName = monsterModel:GetAttribute("MonsterType") or "Hallway"
    local mType = MONSTER_TYPES[mTypeName] or MONSTER_TYPES.Hallway
    MonsterType[monsterModel] = mType
    print("[MonsterAI] Setting up AI for monster: " .. monsterModel.Name .. " (type: " .. mType.name .. ")")
    setIdle(monsterModel)
    if not monsterModel.PrimaryPart then
        monsterModel.PrimaryPart = monsterModel:FindFirstChild("HumanoidRootPart") or monsterModel:FindFirstChild("Torso") or monsterModel:FindFirstChild("UpperTorso")
    end
    -- Generate patrol points automatically based on type
    local patrolPoints = {}
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and mType.patrolFilter(part) then
            table.insert(patrolPoints, part)
        end
    end
    -- Shuffle patrol points for variety
    for i = #patrolPoints, 2, -1 do
        local j = math.random(i)
        patrolPoints[i], patrolPoints[j] = patrolPoints[j], patrolPoints[i]
    end
    MonsterPatrolPoints[monsterModel] = patrolPoints
    MonsterPatrolIndex[monsterModel] = 1
    MonsterState[monsterModel] = "idle"
    MonsterTarget[monsterModel] = nil
    MonsterLastSeen[monsterModel] = 0

    local cleaned = false
    local function cleanup()
        if cleaned then
            return
        end
        cleaned = true
        cleanupMonster(monsterModel)
    end

    monsterModel.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            cleanup()
        end
    end)
    monsterModel.Destroying:Connect(cleanup)

    coroutine.wrap(function()
        while monsterModel.Parent do
            local now = os.clock()
            local seenPlayer = nil
            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                if char and isPlayerInVision(monsterModel, char) then
                    -- For vent monsters, only attack if player is alone
                    if mType.attackOnlyIfAlone then
                        local others = 0
                        for _, p2 in ipairs(Players:GetPlayers()) do
                            if p2 ~= player and p2.Character and (p2.Character.PrimaryPart.Position - char.PrimaryPart.Position).Magnitude < 8 then
                                others = others + 1
                            end
                        end
                        if others == 0 then
                            seenPlayer = char
                            break
                        end
                    else
                        seenPlayer = char
                        break
                    end
                end
            end

            if seenPlayer then
                MonsterTarget[monsterModel] = seenPlayer
                MonsterLastSeen[monsterModel] = now
                if MonsterState[monsterModel] ~= "chase" then
                    MonsterState[monsterModel] = "chase"
                    print("[MonsterAI] " .. monsterModel.Name .. " state: CHASING " .. (seenPlayer.Name or "player"))
                end
                updateVisionConeColor(monsterModel, true)
                chaseAndAttack(monsterModel, seenPlayer)
            else
                local last = MonsterLastSeen[monsterModel] or 0
                if MonsterState[monsterModel] == "chase" and now - last <= CHASE_PERSIST then
                    local target = MonsterTarget[monsterModel]
                    if target and target.Parent then
                        chaseAndAttack(monsterModel, target)
                    else
                        MonsterState[monsterModel] = "patrol"
                        MonsterNoticeState[monsterModel] = nil
                        print("[MonsterAI] " .. monsterModel.Name .. " state: PATROLLING")
                        patrol(monsterModel)
                    end
                    updateVisionConeColor(monsterModel, true)
                else
                    if MonsterState[monsterModel] ~= "patrol" then
                        MonsterState[monsterModel] = "patrol"
                        MonsterNoticeState[monsterModel] = nil
                        print("[MonsterAI] " .. monsterModel.Name .. " state: PATROLLING")
                        patrol(monsterModel)
                    else
                        setIdleIfNotMoving(monsterModel)
                    end
                    updateVisionConeColor(monsterModel, false)
                end
            end
            RunService.Heartbeat:Wait()
        end
    end)()
end

-- === VISION CONE ===
local function setVisionCone(monster, enabled)
    local head = monster and monster:FindFirstChild("Head")
    if not head then return end
    local existing = head:FindFirstChild("VisionCone")
    if enabled then
        if not existing then
            local cone = Instance.new("ConeHandleAdornment")
            cone.Name = "VisionCone"
            cone.Adornee = head
            cone.AlwaysOnTop = true
            cone.ZIndex = 10
            cone.Color3 = Color3.fromRGB(0, 255, 255)
            cone.Transparency = 0.5
            cone.Height = VISION_DISTANCE
            cone.Radius = math.tan(VISION_ANGLE/2) * VISION_DISTANCE
            cone.CFrame = CFrame.new(0, 0, -VISION_DISTANCE) * CFrame.Angles(0, math.rad(180), 0)
            cone.Parent = head
        end
    else
        if existing then existing:Destroy() end
    end
end

-- === INITIALIZE AI FOR EXISTING MONSTERS ===

for _, monster in ipairs(getAllMonsterRigs()) do
    if monster:GetAttribute("MonsterAI") then
        setupMonsterAI(monster)
        MonsterAIControllers[monster.Name] = monster
    end
end

-- Detect automatically new monsters added to Workspace
Workspace.ChildAdded:Connect(function(child)
    if child:IsA("Model") and child:FindFirstChild("Humanoid") and child:FindFirstChild("Head") then
        -- Only initialize AI if it has the attribute MonsterAI = true
        if child:GetAttribute("MonsterAI") and not MonsterAIControllers[child.Name] then
            print("[MonsterAI] Detected new map-generated monster in Workspace: " .. child.Name)
            setupMonsterAI(child)
            MonsterAIControllers[child.Name] = child
        end
    end
end)

-- === DEBUG EVENT ===
local debugEvent = ReplicatedStorage:FindFirstChild("MonsterDebugEvent")
if debugEvent then
    debugEvent.OnServerEvent:Connect(function(player, enabled)
        for _, model in ipairs(Workspace:GetChildren()) do
            if model:IsA("Model") and model:FindFirstChild("Humanoid") and model:FindFirstChild("Head") then
                setVisionCone(model, enabled)
            end
        end
    end)
end


return MonsterAIControllers
