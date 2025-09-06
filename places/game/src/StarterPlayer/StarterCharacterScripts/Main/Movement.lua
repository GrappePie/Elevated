local bind = require(script.Parent.Binds)
local cF = require(game.ReplicatedStorage.Modules.combinedFunctions)
local maid = cF:maid():GetSharedMaid('CharMaid')
local anim = cF:animation()

local run = game:GetService('RunService')

local char: Model = script.Parent.Parent
local hrp: BasePart = char:WaitForChild('HumanoidRootPart')
local head = char:WaitForChild('Head')
local humanoid: Humanoid = char:WaitForChild('Humanoid')
local animator: Animator = humanoid:WaitForChild('Animator')
local camera = workspace.CurrentCamera

local api = {}


---Anims---

local ANIM_FOLDER = Instance.new('Folder')
ANIM_FOLDER.Name = 'Animations'
ANIM_FOLDER.Parent = char

local slideAnim = anim:createAnim(nil, 107092698812752, ANIM_FOLDER, animator, true)
slideAnim:Play()
slideAnim:Stop()
local crouchAnim = anim:createAnim(nil, 133193347125493, ANIM_FOLDER, animator, true)
crouchAnim:Play()
crouchAnim:Stop()
local crouchMovAnim = anim:createAnim(nil, 106445161170991, ANIM_FOLDER, animator, true)
crouchMovAnim:Play()
crouchMovAnim:Stop()

---Init---

local currentMove = false

local SLOW_SPEED = 5
local BASIC_SPEED = 16
local RUN_SPEED = 45

local BASIC_FOV = 70
local RUN_FOV = 90

local crouch = false
local crouchMoving = false
local lastCrouchKey = nil

---Methods---

local function check(type)
	
end

function api:run(state, key)
	if currentMove ~= 'Run' then return end
	humanoid.WalkSpeed = state and RUN_SPEED or BASIC_SPEED
	camera.FieldOfView = state and RUN_FOV or BASIC_FOV
end

function api:crouch(state, key)
	if currentMove ~= 'Crouch' then return end
	if state then 
		if hrp.AssemblyLinearVelocity.Magnitude < 1 then 
			crouchAnim:looping(true)
			crouchAnim:Play(0.5) 
			crouch = true
			return end
		slideAnim:looping(true)
		slideAnim:Play() 
		return
	end
	if hrp.AssemblyLinearVelocity.Magnitude < 1 then 
		crouchAnim:looping(false)
		crouchAnim:Stop()
		crouch = false
		return end
	slideAnim:looping(false)
	slideAnim:Stop()
end

function api:crouchMove(state, key)
	if currentMove ~= 'CrouchMove' then return end
	if key ~= lastCrouchKey and crouchMoving then return end
	humanoid.WalkSpeed = state and SLOW_SPEED or BASIC_SPEED
	if state then
		crouchMovAnim:looping(true)
		crouchMovAnim:Play()
		crouchMoving = true
		return
	end
	crouchMovAnim:looping(false)
	crouchMovAnim:Stop()
	crouchMoving = false
	lastCrouchKey = false
end

function api:walk(state, key)
	if currentMove ~= 'Walk' then return end
	humanoid.WalkSpeed = state and SLOW_SPEED or BASIC_SPEED
end

---Events---


maid:GiveTask('bindSprintModule', bind:bindEvent(), function(key, state)
	
	local fnTab = {
		['LeftShift'] = function(state, key)
			api:run(state, key)
		end,
		['C'] = function(state, key)
			api:crouch(state, key)
		end,
		['MovingCrouch'] = function(state, key)
			api:crouchMove(state, key)
		end,
		['LeftAlt'] = function(state, key)
			api:walk(state, key)
		end,
	}
	
	local tabIndex = fnTab[key] and fnTab[key] or (
			key == 'W' and crouch or 
			key == 'A' and crouch or 
			key == 'S' and crouch or 
			key == 'D' and crouch
	) and fnTab['MovingCrouch']
	lastCrouchKey = lastCrouchKey == nil and key
	
	if tabIndex then tabIndex(state, key) end
end)

return api
