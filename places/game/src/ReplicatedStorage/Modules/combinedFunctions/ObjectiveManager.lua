--[[
  ObjectiveManager
  ----------------
  Purpose:
    Register/manage floor objectives (collect X, fix Y, escort Z…), broadcast updates,
    and open the elevator when all required objectives are complete.

  API:
    local om = ObjectiveManager.new()
    local id = om:add({name="Fix generator", required=1})
    om:progress(id, 1)           -- increments done
    om:onChanged(fn)             -- subscribe to any update
    om:allDone()                 -- boolean

  Notes:
    - Wire om:onChanged to your UI and SFX. Gate elevator on allDone().
]]
local ObjectiveManager = {}
ObjectiveManager.__index = ObjectiveManager

function ObjectiveManager.new()
	local self = setmetatable({}, ObjectiveManager)
	self._list = {}     -- id -> {name, required, done}
	self._order = {}    -- ids in insertion order
	self._subs = {}
	self._uid = 0
	return self
end

function ObjectiveManager:add(def: {name:string, required:number})
	self._uid += 1
	local id = tostring(self._uid)
	self._list[id] = {name = def.name, required = def.required, done = 0}
	table.insert(self._order, id)
	self:_emit()
	return id
end

function ObjectiveManager:progress(id: string, amount: number)
	local o = self._list[id]; if not o then return end
	o.done = math.clamp(o.done + (amount or 1), 0, o.required)
	self:_emit()
end

function ObjectiveManager:onChanged(fn: (table)->())
	table.insert(self._subs, fn)
end

function ObjectiveManager:_emit()
	local snapshot = {}
	for _,id in ipairs(self._order) do
		local o = self._list[id]
		snapshot[#snapshot+1] = {id=id, name=o.name, done=o.done, required=o.required}
	end
	for _,fn in ipairs(self._subs) do task.spawn(fn, snapshot) end
end

function ObjectiveManager:allDone()
	for _,o in pairs(self._list) do
		if o.done < o.required then return false end
	end
	return true
end

return ObjectiveManager
