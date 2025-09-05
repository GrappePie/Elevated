-- Timer.lua
--[[
  Frame-based Timer
  -----------------
  Purpose:
    Count up to a given duration using RunService.Heartbeat.
    Calls an optional per-frame callback and fires `finished` with:
      "Finished" | "Stopped"

  API:
    local t = Timer.new()
    t:start(2.5, function(self)  end)
    t:awaitFinished()  --> "Finished" | "Stopped"
    t:pause(); t:resume()
    t:getElapsed()     --> seconds
    t:getProgress()    --> 0..1
    t:getTimeLeft(raw?)--> number (rounded by default; pass true for float)
    t:isRunning()
    t:stop(true?)      --> true => "Finished", false/nil => "Stopped"
]]

local RunService = game:GetService("RunService")

local Timer = {}
Timer.__index = Timer

function Timer.new()
	local self = setmetatable({}, Timer)
	self._finishedEvent = Instance.new("BindableEvent")
	self.finished = self._finishedEvent.Event

	self._running = false
	self._paused = false
	self._duration = 0
	self._elapsed = 0
	self._conn = nil
	self.fn = nil
	return self
end

function Timer:_disconnect()
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

function Timer:start(duration: number, fnInTime: ((self:any)->())?)
	-- stop previous
	self:stop()

	self._duration = math.max(0, duration or 0)
	self._elapsed = 0
	self.fn = fnInTime
	self._running = true
	self._paused = false

	if self._duration <= 0 then
		self:stop(true) -- immediately finished
		return
	end

	self._conn = RunService.Heartbeat:Connect(function(dt)
		if not self._running or self._paused then return end

		self._elapsed += dt
		if self.fn then
			-- pass self so callers can read getProgress/getTimeLeft, etc.
			self.fn(self)
		end
		if self._elapsed >= self._duration then
			self:stop(true)
		end
	end)
end

function Timer:pause()
	if self._running and not self._paused then
		self._paused = true
	end
end

function Timer:resume()
	if self._running and self._paused then
		self._paused = false
	end
end

function Timer:getFinishedEventSignal()
	return self._finishedEvent.Event
end

function Timer:getElapsed(): number
	return self._elapsed or 0
end

function Timer:getProgress(): number
	if self._duration <= 0 then return 0 end
	return math.clamp((self._elapsed or 0) / self._duration, 0, 1)
end

function Timer:getTimeLeft(raw: boolean?)
	if not self._running and self._elapsed == 0 then
		return raw and 0 or 0
	end
	local left = math.max(0, (self._duration or 0) - (self._elapsed or 0))
	return raw and left or math.round(left)
end

function Timer:isRunning(): boolean
	return self._running
end

function Timer:awaitFinished()
	return self._finishedEvent.Event:Wait()
end

function Timer:stop(finished: boolean?)
	if self._running then
		self._running = false
		self:_disconnect()
		-- keep _elapsed/_duration for inspection after stop; nil if prefieres limpiar:
		-- self._duration, self._elapsed = 0, 0
		local result = (finished == true) and "Finished" or "Stopped"
		self._finishedEvent:Fire(result)
	end
end

return Timer
