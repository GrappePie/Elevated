-- Sprint.lua (Client)
-- Requires:
--   - script.Parent.Binds  → your input binding helper
--   - ReplicatedStorage.Modules.combinedFunctions  → provides :maid() and :animation()
--   - A server RemoteEvent named "PlayerSprintEvent" (see PlayerSprint.server.lua)
-- Keys:
--   - LeftShift → Sprint
--   - C         → Crouch / Slide (dash if moving)
--   - LeftAlt   → Walk (slow)

-- Sprint.lua (Client) — Sprint + Slide-through-small-gaps
-- Keys:
--   LeftShift → Sprint
--   C         → Crouch / Slide (dash if moving)
--   LeftAlt   → Walk (slow)
--
-- Requires:
--   - script.Parent.Binds  (your input binding helper)
--   - ReplicatedStorage.Modules.combinedFunctions  (:maid(), :animation())
--   - RemoteEvent "PlayerSprintEvent" created by the server

local bind = require(script.Parent.Binds)
local cF = require(game.ReplicatedStorage.Modules.combinedFunctions)

local maid = cF:maid():GetSharedMaid("CharMaid")
local anim = cF:animation()

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local char: Model = script.Parent.Parent
local hrp: BasePart = char:WaitForChild("HumanoidRootPart")
local humanoid: Humanoid = char:WaitForChild("Humanoid")
local animator: Animator = humanoid:WaitForChild("Animator")
local camera = workspace.CurrentCamera

local SprintEvent = ReplicatedStorage:FindFirstChild("PlayerSprintEvent") or ReplicatedStorage:WaitForChild("PlayerSprintEvent", 5)

-- ===== Tuning =====
local SLOW_SPEED   = 5
local BASIC_SPEED  = 16
local RUN_SPEED    = 24
local SLIDE_SPEED  = 30
local RUN_FOV      = 90
local BASIC_FOV    = 70

-- How small the sliding hitbox is (studs). Try 0.6–1.0 depending on your gaps.
local SLIDE_HITBOX_HEIGHT = 0.80
local SLIDE_HITBOX_WIDTH  = 2.0   -- keep a bit wide so you don’t snag
local SLIDE_HITBOX_DEPTH  = 2.0

local FIRE_COOLDOWN = 0.12
local lastSprintFire = 0

-- Animations (replace IDs with yours)
local SLIDE_ID = 107092698812752
local CROUCH_ID = 133193347125493
local MOVE_CROUCH_ID = 106445161170991

local ANIM_FOLDER = Instance.new("Folder")
ANIM_FOLDER.Name = "Animations"
ANIM_FOLDER.Parent = char

local slideAnim     = anim:createAnim(nil, SLIDE_ID,       ANIM_FOLDER, animator, true); slideAnim:Play(); slideAnim:Stop()
local crouchAnim    = anim:createAnim(nil, CROUCH_ID,      ANIM_FOLDER, animator, true); crouchAnim:Play(); crouchAnim:Stop()
local crouchMovAnim = anim:createAnim(nil, MOVE_CROUCH_ID, ANIM_FOLDER, animator, true); crouchMovAnim:Play(); crouchMovAnim:Stop()

-- ===== State =====
local defaultHipHeight = humanoid.HipHeight
local defaultHrpSize   = hrp.Size
local crouch = false
local crouchMoving = false
local wantsStand = false
local slideCollider: BasePart? = nil
local savedCollide: {[BasePart]: boolean} = {}

-- ===== Helpers =====
local function now() return os.clock() end

local function sendServerSpeed(spd: number)
	if not SprintEvent then return end
	local t = now()
	if (t - lastSprintFire) >= FIRE_COOLDOWN then
		lastSprintFire = t
		SprintEvent:FireServer(spd)
	end
end

local function tweenProp(obj, ti: TweenInfo, goal)
	local ok, tw = pcall(function()
		local t = TweenService:Create(obj, ti, goal)
		t:Play()
		return t
	end)
	return ok and tw or nil
end

local function smoothSpeed(targetSpeed: number, duration: number?, noNotify: boolean?)
	duration = duration or 0.2
	if not tweenProp(humanoid, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {WalkSpeed = targetSpeed}) then
		humanoid.WalkSpeed = targetSpeed
	end
	if not noNotify then sendServerSpeed(targetSpeed) end
end

local function smoothSpeedAndFOV(targetSpeed: number, targetFOV: number, duration: number?, noNotify: boolean?)
	duration = duration or 0.35
	smoothSpeed(targetSpeed, duration, true)
	if camera then
		if not tweenProp(camera, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {FieldOfView = targetFOV}) then
			camera.FieldOfView = targetFOV
		end
	end
	if not noNotify then sendServerSpeed(targetSpeed) end
end

local function canStand(): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	-- probe up a bit more than the default height
	local up = workspace:Raycast(hrp.Position, Vector3.new(0, defaultHrpSize.Y + 0.75, 0), params)
	return up == nil
end

local function dashImpulse(power: number)
	local dir = humanoid.MoveDirection
	if dir.Magnitude > 0.1 then
		dir = Vector3.new(dir.X, 0, dir.Z).Unit
		hrp.AssemblyLinearVelocity = dir * power + Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
	end
end

-- === Slide collider swap ===
local function setAllBodyCollide(enabled: boolean)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d ~= slideCollider then
			if savedCollide[d] == nil then savedCollide[d] = d.CanCollide end
			d.CanCollide = enabled and (savedCollide[d] or false) or false
		end
	end
	-- HRP must not collide while sliding
	if not enabled then hrp.CanCollide = false else hrp.CanCollide = (savedCollide[hrp] == nil) and true or savedCollide[hrp] end
end

local function createSlideCollider()
	if slideCollider and slideCollider.Parent then return end
	local p = Instance.new("Part")
	p.Name = "SlideCollider"
	p.Size = Vector3.new(SLIDE_HITBOX_WIDTH, SLIDE_HITBOX_HEIGHT, SLIDE_HITBOX_DEPTH)
	p.Massless = true
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = true
	p.Transparency = 1
	p.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0, 1, 1)
	p.Parent = char

	-- Keep bottom roughly on the ground; offset center downward from HRP
	local yOffset = (SLIDE_HITBOX_HEIGHT - defaultHrpSize.Y) * 0.5
	p.CFrame = hrp.CFrame * CFrame.new(0, yOffset, 0)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = p
	weld.Part1 = hrp
	weld.Parent = p

	slideCollider = p
end

local function removeSlideCollider()
	if slideCollider then
		slideCollider:Destroy()
		slideCollider = nil
	end
end

local function enterCrouch()
	crouch = true
	-- Real shrink: swap to the slide collider and disable collisions elsewhere
	createSlideCollider()
	setAllBodyCollide(false)

	-- Lower hip height so we visually fit; keep a tiny buffer
	humanoid.HipHeight = math.max(0.5, defaultHipHeight * 0.55)
end

local function exitCrouch()
	crouch = false
	removeSlideCollider()
	setAllBodyCollide(true)
	humanoid.HipHeight = defaultHipHeight
end

local function stopCrouchTracks()
	pcall(function() crouchAnim:Stop() end)
	pcall(function() crouchMovAnim:Stop() end)
	pcall(function() slideAnim:Stop() end)
end

-- Server speed echo → match smoothly
if SprintEvent then
	SprintEvent.OnClientEvent:Connect(function(appliedSpeed)
		if typeof(appliedSpeed) == "number" then
			local fov = (appliedSpeed > BASIC_SPEED) and RUN_FOV or BASIC_FOV
			smoothSpeedAndFOV(appliedSpeed, fov, 0.18, true)
		end
	end)
end

-- If we want to stand up but still no space, keep waiting
RunService.Heartbeat:Connect(function()
	if wantsStand and canStand() then
		wantsStand = false
		exitCrouch()
		stopCrouchTracks()
		smoothSpeedAndFOV(BASIC_SPEED, BASIC_FOV, 0.18)
	elseif slideCollider then
		-- Keep the collider aligned vertically while moving on slopes
		local yOffset = (SLIDE_HITBOX_HEIGHT - defaultHrpSize.Y) * 0.5
		slideCollider.CFrame = hrp.CFrame * CFrame.new(0, yOffset, 0)
	end
end)

-- ===== Key Handlers =====
local fn = {}

fn["LeftShift"] = function(down: boolean)
	smoothSpeedAndFOV(down and RUN_SPEED or BASIC_SPEED, down and RUN_FOV or BASIC_FOV, 0.35)
end

fn["C"] = function(down: boolean)
	if down then
		enterCrouch()

		if hrp.AssemblyLinearVelocity.Magnitude < 1 then
			-- Idle crouch
			pcall(function() crouchAnim:looping(true); crouchAnim:Play(0.2) end)
			smoothSpeed(SLOW_SPEED, 0.18)
			return
		end

		-- Slide/Dash
		pcall(function() slideAnim:looping(true); slideAnim:Play(0.14) end)
		smoothSpeed(SLIDE_SPEED, 0.14)
		dashImpulse(60)
		return
	end

	-- Key released: try to stand (only if there is headroom)
	stopCrouchTracks()
	if canStand() then
		wantsStand = false
		exitCrouch()
		smoothSpeedAndFOV(BASIC_SPEED, BASIC_FOV, 0.18)
	else
		wantsStand = true
		pcall(function() crouchAnim:looping(true); crouchAnim:Play(0.1) end)
		smoothSpeed(SLOW_SPEED, 0.1, true)
	end
end

fn["MovingCrouch"] = function(down: boolean)
	if not crouch then return end
	if not down then
		crouchMoving = false
		pcall(function() crouchMovAnim:looping(false); crouchMovAnim:Stop(0.1) end)
		return
	end

	if crouchMoving then return end
	task.wait()
	if humanoid.MoveDirection.Magnitude <= 0 then return end

	smoothSpeed(SLOW_SPEED, 0.2)
	pcall(function() crouchMovAnim:looping(true); crouchMovAnim:Play() end)
	crouchMoving = true
end

fn["LeftAlt"] = function(down: boolean)
	smoothSpeed(down and SLOW_SPEED or BASIC_SPEED, 0.2)
end

-- ===== Input Bindings =====
maid:GiveTask("bindSprintModule", bind:bindEvent(), function(key: string, state: boolean)
	local handler = fn[key]
	if not handler then
		local isMove = (key == "W" or key == "A" or key == "S" or key == "D")
		if isMove and crouch and fn["MovingCrouch"] then handler = fn["MovingCrouch"] end
	end
	if handler then
		local ok, err = pcall(handler, state)
		if not ok then warn("[SprintClient] Handler error for", key, err) end
	end
end)

return {}
