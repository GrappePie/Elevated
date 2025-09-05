local bind = require(script.Parent.Binds)
local cF = require(game.ReplicatedStorage.Modules.combinedFunctions)

-- Shared helpers from your combinedFunctions
local maid = cF:maid():GetSharedMaid("CharMaid")
local anim = cF:animation()

-- Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Character refs (this script sits inside a folder that is parented to the Character)
local char: Model = script.Parent.Parent
local hrp: BasePart = char:WaitForChild("HumanoidRootPart")
local head: BasePart = char:WaitForChild("Head")
local humanoid: Humanoid = char:WaitForChild("Humanoid")
local animator: Animator = humanoid:WaitForChild("Animator")
local camera = workspace.CurrentCamera

-- RemoteEvent (server creates it)
local SprintEvent = ReplicatedStorage:FindFirstChild("PlayerSprintEvent") or ReplicatedStorage:WaitForChild("PlayerSprintEvent", 5)
if not SprintEvent then
	warn("[SprintClient] PlayerSprintEvent RemoteEvent missing; server should create it.")
end

-- Public API table (if you want to expose functions later)
local api = {}

-- Tunables
local SLOW_SPEED = 5
local BASIC_SPEED = 16
local RUN_SPEED = 45
local SLIDE_SPEED = 30

local BASIC_FOV = 70
local RUN_FOV = 90

-- Client → Server fire throttle (keep under server cooldown)
local FIRE_COOLDOWN = 0.12
local lastSprintFire = 0

-- Animation setup
local ANIM_FOLDER = Instance.new("Folder")
ANIM_FOLDER.Name = "Animations"
ANIM_FOLDER.Parent = char

-- Your numerical IDs (we also keep string forms to identify tracks reliably)
local SLIDE_ID_NUM = 107092698812752
local CROUCH_ID_NUM = 133193347125493
local MOVE_CROUCH_ID_NUM = 106445161170991

local ID_SLIDE = ("rbxassetid://%s"):format(SLIDE_ID_NUM)
local ID_CROUCH = ("rbxassetid://%s"):format(CROUCH_ID_NUM)
local ID_MOVE_CROUCH = ("rbxassetid://%s"):format(MOVE_CROUCH_ID_NUM)

local slideAnim = anim:createAnim(nil, SLIDE_ID_NUM, ANIM_FOLDER, animator, true);  slideAnim:Play(); slideAnim:Stop()
local crouchAnim = anim:createAnim(nil, CROUCH_ID_NUM, ANIM_FOLDER, animator, true); crouchAnim:Play(); crouchAnim:Stop()
local crouchMovAnim = anim:createAnim(nil, MOVE_CROUCH_ID_NUM, ANIM_FOLDER, animator, true); crouchMovAnim:Play(); crouchMovAnim:Stop()

-- State
local crouch = false
local crouchMoving = false

-- ===== Helpers =====

local function sendServerSpeed(targetSpeed: number)
	if not SprintEvent then return end
	local now = tick()
	if now - lastSprintFire < FIRE_COOLDOWN then return end
	lastSprintFire = now
	pcall(function()
		SprintEvent:FireServer(targetSpeed)
	end)
end

local function tweenProp(obj, ti: TweenInfo, goal)
	local ok, res = pcall(function()
		local tw = TweenService:Create(obj, ti, goal)
		tw:Play()
		return tw
	end)
	return ok and res or nil
end

local function smoothSpeed(targetSpeed: number, duration: number?, noNotify: boolean?)
	duration = duration or 0.2
	if not humanoid then return end
	if not tweenProp(humanoid, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {WalkSpeed = targetSpeed}) then
		humanoid.WalkSpeed = targetSpeed
	end
	if not noNotify then
		sendServerSpeed(targetSpeed)
	end
end

local function smoothSpeedAndFOV(targetSpeed: number, targetFOV: number, duration: number?, noNotify: boolean?)
	duration = duration or 0.35
	-- Avoid double notify: update speed silently, then optionally send once here
	smoothSpeed(targetSpeed, duration, true)

	if camera then
		if not tweenProp(camera, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {FieldOfView = targetFOV}) then
			camera.FieldOfView = targetFOV
		end
	end

	if not noNotify then
		sendServerSpeed(targetSpeed)
	end
end

-- Fail-safe: stop any crouch-related tracks (handles wrapper loops + raw tracks)
local function stopCrouchTracks()
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			local id = track.Animation and track.Animation.AnimationId
			if id == ID_SLIDE or id == ID_CROUCH or id == ID_MOVE_CROUCH then
				pcall(function() track:Stop(0) end)
			end
		end
	end
	pcall(function() if slideAnim then slideAnim:looping(false); slideAnim:Stop(0) end end)
	pcall(function() if crouchAnim then crouchAnim:looping(false); crouchAnim:Stop(0) end end)
	pcall(function() if crouchMovAnim then crouchMovAnim:looping(false); crouchMovAnim:Stop(0) end end)
	crouchMoving = false
end

-- Server echo of applied (clamped) speed → smoothly conform on client without re-notifying
if SprintEvent then
	SprintEvent.OnClientEvent:Connect(function(appliedSpeed)
		if type(appliedSpeed) == "number" then
			local targetFOV = (appliedSpeed > BASIC_SPEED) and RUN_FOV or BASIC_FOV
			smoothSpeedAndFOV(appliedSpeed, targetFOV, 0.18, true)
		end
	end)
end

-- ===== Key Handlers =====
local fnTab = {}

fnTab["LeftShift"] = function(state: boolean)
	smoothSpeedAndFOV(state and RUN_SPEED or BASIC_SPEED, state and RUN_FOV or BASIC_FOV, 0.35)
end

fnTab["C"] = function(state: boolean)
	if state then
		-- Start crouch or slide
		if hrp.AssemblyLinearVelocity.Magnitude < 1 then
			crouchAnim:looping(true)
			crouchAnim:Play(0.2)
			crouch = true
			smoothSpeed(SLOW_SPEED, 0.18)
			return
		end
		-- Sliding while moving
		slideAnim:looping(true)
		slideAnim:Play(0.14)
		smoothSpeed(SLIDE_SPEED, 0.14)
		return
	end

	-- === RELEASE C ===
	-- 1) Mark as NOT crouching first so no new MovingCrouch can start this frame
	crouch = false

	-- 2) Explicitly tell MovingCrouch to stop (handles flags & speed)
	pcall(function()
		if fnTab and fnTab["MovingCrouch"] then fnTab["MovingCrouch"](false) end
	end)

	-- 3) Hard-stop any crouch/slide tracks that might still be latched
	stopCrouchTracks()

	-- 4) Restore default move & FOV
	smoothSpeedAndFOV(BASIC_SPEED, BASIC_FOV, 0.18)
end

fnTab["MovingCrouch"] = function(state: boolean)
	-- If not crouching, never (re)start the moving-crouch anim
	if not crouch then
		if crouchMoving then
			pcall(function() crouchMovAnim:looping(false); crouchMovAnim:Stop(0) end)
			crouchMoving = false
		end
		return
	end

	-- Stop request or no longer moving
	if not state then
		pcall(function() crouchMovAnim:looping(false); crouchMovAnim:Stop(0) end)
		crouchMoving = false
		smoothSpeed(BASIC_SPEED, 0.2)
		return
	end

	-- Already active? Nothing to do
	if crouchMoving then return end

	-- On input begin, MoveDirection may not be updated yet. Wait one frame then check.
	task.wait()
	if humanoid.MoveDirection and humanoid.MoveDirection.Magnitude <= 0 then
		-- still not moving; bail out
		return
	end

	smoothSpeed(SLOW_SPEED, 0.2)
	pcall(function() crouchMovAnim:looping(true); crouchMovAnim:Play() end)
	crouchMoving = true
end

fnTab["LeftAlt"] = function(state: boolean)
	smoothSpeed(state and SLOW_SPEED or BASIC_SPEED, 0.2)
end

-- ===== Input binding (via your Binds module) =====
maid:GiveTask("bindSprintModule", bind:bindEvent(), function(key: string, state: boolean)
	-- Choose handler; movement keys while crouching route to MovingCrouch
	local handler = fnTab[key]
	if not handler then
		local isMoveKey = (key == "W" or key == "A" or key == "S" or key == "D")
		if isMoveKey and crouch and fnTab["MovingCrouch"] then
			handler = fnTab["MovingCrouch"]
		end
	end

	if handler then
		local ok, err = pcall(handler, state)
		if not ok then
			warn("[SprintClient] Handler error for", key, err)
		end
	end
end)

return api