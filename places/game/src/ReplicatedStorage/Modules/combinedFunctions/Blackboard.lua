--[[
  Blackboard
  ----------
  Purpose:
    Shared memory for AI agents or floor-level state (targets, lastSeenPos, noise, danger).
  API:
    local bb = Blackboard.new()
    bb:set("key", value)
    local v = bb:get("key", default)
    bb:onChanged("key", fn)  -- optional: subscribe to changes
]]
local Blackboard = {}
Blackboard.__index = Blackboard

function Blackboard.new()
	local self = setmetatable({}, Blackboard)
	self._data = {}
	self._signals = {} -- key -> {callbacks}
	return self
end

function Blackboard:set(key: string, value: any)
	self._data[key] = value
	local subs = self._signals[key]
	if subs then
		for _,cb in ipairs(subs) do
			task.spawn(cb, value)
		end
	end
end

function Blackboard:get(key: string, default: any)
	local v = self._data[key]
	return v == nil and default or v
end

function Blackboard:onChanged(key: string, fn: (any) -> ())
	self._signals[key] = self._signals[key] or {}
	table.insert(self._signals[key], fn)
end

return Blackboard
