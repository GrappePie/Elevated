--[[
  Director (Pacing Controller)
  ----------------------------
  Purpose:
    Adjusts difficulty and spawn pressure based on player stress (health, recent hits,
    time-in-combat, deaths, objective progress). Controls when to spawn monsters/traps.

  API:
    local director = Director.new(config, rng)
    director:update(dt, world)  -- world exposes metrics (players, objectives, time, etc.)
    director:requestSpawn(slotId, spawnFn) -- schedule spawn (respecting pressure)
  Notes:
    - Uses a simple "pressure" score. You can expand to curves or states (BuildUp, Peak, Relax).
]]
local Director = {}
Director.__index = Director

function Director.new(config: {minGap:number, maxPressure:number, decay:number}, rng)
	local self = setmetatable({}, Director)
	self.cfg = config or {minGap=4, maxPressure=100, decay=8}
	self.rng = rng
	self.pressure = 0
	self.cooldown = 0
	self._queue = {}
	return self
end

function Director:_calcStress(world)
	-- Example stress: average of (1 - hp%) + recent hits + time in combat + near-fail
	local s = 0
	for _,p in ipairs(world.players) do
		local hp = math.clamp(p.hp / math.max(1, p.maxHp), 0, 1)
		s += (1 - hp) + (p.recentHits or 0) * 0.3
	end
	s /= math.max(1, #world.players)
	if world.timeSinceLastObjective > 30 then s += 0.2 end
	return math.clamp(s, 0, 1)
end

function Director:update(dt: number, world)
	self.cooldown = math.max(0, self.cooldown - dt)
	local stress = self:_calcStress(world)
	-- Move pressure toward stress*maxPressure
	local target = stress * self.cfg.maxPressure
	local delta = (target - self.pressure) * (dt / self.cfg.decay)
	self.pressure += delta

	-- Process queued spawns if below threshold and not on cooldown
	if self.cooldown <= 0 and self.pressure < (self.cfg.maxPressure * 0.65) then
		local job = table.remove(self._queue, 1)
		if job then
			job()
			self.cooldown = self.cfg.minGap + (self.rng and self.rng:nextNumber(0,1) or math.random()) * 2
			self.pressure += 10 -- cost of spawning
		end
	end
end

function Director:requestSpawn(slotId: string, spawnFn: () -> ())
	-- You can coalesce by slotId if needed to avoid duplicates
	table.insert(self._queue, spawnFn)
end

return Director
