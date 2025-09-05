--[[
  ObjectPool
  ----------
  Purpose:
    Reuse Instances (enemies, traps, props, projectiles) instead of creating/destroying.
  API:
    local pool = ObjectPool.new(template: Instance, prewarm: number?)
    local obj = pool:acquire(parent?)  -- returns Instance
    pool:release(obj)                  -- returns to pool (cleans up basic state)
    pool:drain()                       -- destroy all pooled objects
  Notes:
    - Combine with Maid to detach connections on release.
]]
local ObjectPool = {}
ObjectPool.__index = ObjectPool

function ObjectPool.new(template: Instance, prewarm: number?)
	local self = setmetatable({}, ObjectPool)
	self.template = template
	self.free = {}
	self.busy = {}
	if prewarm and prewarm > 0 then
		for _=1, prewarm do
			local clone = template:Clone()
			clone.Parent = nil
			table.insert(self.free, clone)
		end
	end
	return self
end

function ObjectPool:acquire(parent: Instance?)
	local obj = table.remove(self.free) or self.template:Clone()
	obj.Parent = parent or workspace
	self.busy[obj] = true
	return obj
end

function ObjectPool:release(obj: Instance)
	if not self.busy[obj] then return end
	self.busy[obj] = nil
	-- Basic reset (extend as needed for your game)
	if obj:IsA("BasePart") then
		obj.Anchored = false; obj.CanCollide = true; obj.Transparency = 0
	end
	obj.Parent = nil
	table.insert(self.free, obj)
end

function ObjectPool:drain()
	for _,o in ipairs(self.free) do o:Destroy() end
	for o in pairs(self.busy) do o:Destroy() end
	table.clear(self.free); table.clear(self.busy)
end

return ObjectPool
