--[[
  FSM (Finite State Machine)
  --------------------------
  Purpose:
    Simple, readable AI with states (Idle, Patrol, Chase, Attack, Flee).
  API:
    local fsm = FSM.new("Idle")
    fsm:add("Idle",    {enter=fn, update=fn, exit=fn})
    fsm:add("Chase",   {...})
    fsm:change("Chase", {target=player})
    fsm:update(dt)
  Notes:
    - Use together with Blackboard + Perception for robust behavior.
]]
local FSM = {}
FSM.__index = FSM

function FSM.new(initial: string)
	local self = setmetatable({}, FSM)
	self._states = {}
	self._current = nil
	self._currentName = nil
	self:change(initial)
	return self
end

function FSM:add(name: string, def: {enter:(any)->()? , update:(number, any)->()? , exit:(any)->()?})
	self._states[name] = def
	return self
end

function FSM:change(name: string, ctx: any?)
	if self._current and self._current.exit then self._current.exit(ctx) end
	self._current = self._states[name]
	self._currentName = name
	if self._current and self._current.enter then self._current.enter(ctx) end
end

function FSM:update(dt: number, ctx: any?)
	if self._current and self._current.update then
		self._current.update(dt, ctx)
	end
end

function FSM:name() return self._currentName end

return FSM
