--[[
  Perception
  ----------
  Purpose:
    Line-of-sight and hearing checks for AI (vision cone, distance, occlusion).
  API:
    Perception.canSee(eyePos, targetPos, params, maxDist, cosFovHalf) -> boolean
    Perception.heard(noisePos, listenerPos, falloffDist) -> number (0..1)
  Notes:
    - `params` is a RaycastParams with collision/filter set by caller.
    - Use with Blackboard: set lastSeenPos / lastHeardPos when detected.
]]
local Perception = {}

function Perception.canSee(eyePos: Vector3, targetPos: Vector3, params: RaycastParams, maxDist: number, cosFovHalf: number)
	local toTarget = targetPos - eyePos
	if toTarget.Magnitude > maxDist then return false end
	local dir = toTarget.Unit
	-- Assuming forward = -Z in world; adapt to your agent’s forward vector as needed.
	-- Better: pass 'forward' explicitly if you have the agent’s facing.
	local forward = Vector3.new(0,0,-1)
	if forward:Dot(dir) < cosFovHalf then return false end
	local result = workspace:Raycast(eyePos, dir * maxDist, params)
	if not result then return true end
	-- Visible if first hit is very close to target position
	return (result.Position - targetPos).Magnitude < 2.0
end

function Perception.heard(noisePos: Vector3, listenerPos: Vector3, falloffDist: number)
	local d = (noisePos - listenerPos).Magnitude
	if d >= falloffDist then return 0 end
	return 1 - (d / falloffDist)
end

return Perception
