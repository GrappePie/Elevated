local RunService = game:GetService("RunService")
local Timer = {}
Timer.__index = Timer

function Timer.new()
	local self = setmetatable({}, Timer)

	self._finishedEvent = Instance.new("BindableEvent")
	self.finished = self._finishedEvent.Event
	
	self.awaitFinished = function()
		return self._finishedEvent.Event:Wait()
	end

	self._running = false
	self._startTime = nil
	self._duration = nil
	self._elapsed = nil

	return self
end

function Timer:start(duration, fnInTime)
	self:stop() 
	self._duration = duration
	self._startTime = tick()
	self._elapsed = 0
	self.fn = fnInTime

	self.updater = RunService.Heartbeat:Connect(function(deltaTime)
		if self._elapsed >= self._duration then
			self:stop(true)
			return
		end

		self._elapsed += deltaTime
		if self.fn then self.fn(self) end
	end)

	self._running = true
end

function Timer:getFinishedEventSignal()
	return self._finishedEvent.Event
end

function Timer:getTimeLeft()
	if self:isRunning() then
		local timeLeft = self._duration - self._elapsed
		if timeLeft < 0 then
			timeLeft = 0
		end
		return math.round(timeLeft)
	end
end

function Timer:isRunning()
	return self._running
end

function Timer:stop(state)
	if self:isRunning() then
		self._running = false 

		if self.updater then
			self.updater:Disconnect()
			self.updater = nil 
		end

		self._startTime = nil
		self._duration = nil
		self._elapsed = nil
		self.fn = nil

		self._finishedEvent:Fire(state == true and "Finished" or "Stopped")
	end
end

return Timer