-- Tween.lua
--[[
  Tween Helper
  ------------
  Purpose:
    Small wrapper around TweenService to:
      - await completion via :await()
      - cancel groups/singles by id
      - tween arrays of instances in parallel
      - avoid memory leaks (destroy events when done)

  API (same as yours + a bit more):
    local tw  = Tween.linear(inst|{inst,...}, props, duration, id?, delay?, reverse?, repeatCount?)
    local tw2 = Tween.exponential(...)
    tw:await() --> "Finished" | "Stopped"
    tw:cancelTween()
    Tween.cancelById(id)
    Tween.isActive(id) -> boolean
    Tween.cancelAll()
]]

local TweenService = game:GetService("TweenService")
local HTTP = game:GetService("HttpService")

local Tween = { List = {} }

type Instances = { Instance }
type TweenClass = {
	Id: string,
	tween: Tween?,
	_completeEvent: BindableEvent?,
	forcedCancel: boolean,
	tweenEndedEvent: (self: TweenClass) -> RBXScriptSignal,
	cancelTween: (self: TweenClass) -> (),
	await: (self: TweenClass) -> ("Finished" | "Stopped")
}

local function _finishAndCleanup(id: string, cls: TweenClass, result: "Finished"|"Stopped")
	Tween.List[id] = nil
	if cls._completeEvent then
		cls._completeEvent:Fire(result)
		-- Defer destroy so waiters can return first
		task.defer(function()
			if cls._completeEvent then
				cls._completeEvent:Destroy()
				cls._completeEvent = nil
			end
		end)
	end
end

local function _connectCompleted(id: string, tw: Tween, cls: TweenClass)
	Tween.List[id] = cls
	tw.Completed:ConnectOnce(function(state: Enum.PlaybackState)
		local result: "Finished"|"Stopped" =
			cls.forcedCancel and "Stopped"
			or (state == Enum.PlaybackState.Completed and "Finished" or "Stopped")
		_finishAndCleanup(id, cls, result)
	end)
end

local function _makeSingle(instance: Instance, prop: {}, playTime: number, id: string?, delay: number?, style: Enum.EasingStyle, reverse: boolean?, repeatCount: number?): TweenClass
	local cls: TweenClass = {
		Id = id or HTTP:GenerateGUID(false),
		_completeEvent = Instance.new("BindableEvent"),
		forcedCancel = false,
		tween = nil,
	} :: any

	-- Cancel existing with same id
	if Tween.List[cls.Id] and Tween.List[cls.Id].cancelTween then
		Tween.List[cls.Id]:cancelTween()
	end

	local info = TweenInfo.new(
		playTime,
		style,
		Enum.EasingDirection.InOut,
		repeatCount or 0,
		reverse or false,
		delay or 0
	)
	local tw = TweenService:Create(instance, info, prop)
	cls.tween = tw

	function cls:tweenEndedEvent()
		return assert(self._completeEvent, "event destroyed").Event
	end
	function cls:cancelTween()
		self.forcedCancel = true
		if self.tween then self.tween:Cancel() end
	end
	function cls:await()
		return self:tweenEndedEvent():Wait()
	end

	tw:Play()
	_connectCompleted(cls.Id, tw, cls)
	return cls
end

local function _makeMany(instances: Instances, prop: {}, playTime: number, id: string?, delay: number?, style: Enum.EasingStyle, reverse: boolean?, repeatCount: number?): TweenClass
	local groupId = id or HTTP:GenerateGUID(false)
	if Tween.List[groupId] and Tween.List[groupId].cancelTween then
		Tween.List[groupId]:cancelTween()
	end

	local total = #instances
	local ev = Instance.new("BindableEvent")
	local done = 0

	local group: TweenClass = {
		Id = groupId,
		_completeEvent = ev,
		forcedCancel = false,
		tween = nil,
		cancelTween = function(self: TweenClass)
			self.forcedCancel = true
			for _, inst in ipairs(instances) do
				local key = tostring(inst)..":"..groupId
				local sub = Tween.List[key]
				if sub and sub.cancelTween then sub:cancelTween() end
			end
		end,
		tweenEndedEvent = function(self: TweenClass) return ev.Event end,
		await = function(self: TweenClass) return ev.Event:Wait() end,
	} :: any

	-- Empty list: finish immediately
	if total == 0 then
		Tween.List[groupId] = group
		task.defer(function()
			_finishAndCleanup(groupId, group, "Finished")
		end)
		return group
	end

	for _, inst in ipairs(instances) do
		local key = tostring(inst)..":"..groupId
		local sub = _makeSingle(inst, prop, playTime, key, delay, style, reverse, repeatCount)
		sub._completeEvent.Event:Connect(function()
			done += 1
			if done >= total then
				_finishAndCleanup(groupId, group, group.forcedCancel and "Stopped" or "Finished")
			end
		end)
	end

	Tween.List[groupId] = group
	return group
end

local function setTween(instances: Instance | Instances, prop: {}, playTime: number, id: string?, delay: number?, style: Enum.EasingStyle, reverse: boolean?, repeatCount: number?)
	if typeof(instances) == "table" then
		return _makeMany(instances :: Instances, prop, playTime, id, delay, style, reverse, repeatCount)
	else
		return _makeSingle(instances :: Instance, prop, playTime, id, delay, style, reverse, repeatCount)
	end
end

function Tween.linear(instances: Instance | Instances, prop: {}, playTime: number, id: string?, delay: number?, reverse: boolean?, repeatCount: number?)
	return setTween(instances, prop, playTime, id, delay, Enum.EasingStyle.Linear, reverse, repeatCount)
end

function Tween.exponential(instances: Instance | Instances, prop: {}, playTime: number, id: string?, delay: number?, reverse: boolean?, repeatCount: number?)
	return setTween(instances, prop, playTime, id, delay, Enum.EasingStyle.Exponential, reverse, repeatCount)
end

function Tween.cancelById(id: string)
	local t = Tween.List[id]
	if t and t.cancelTween then t:cancelTween() end
end

function Tween.isActive(id: string): boolean
	return Tween.List[id] ~= nil
end

function Tween.cancelAll()
	for id, t in pairs(Tween.List) do
		if t and t.cancelTween then t:cancelTween() end
		Tween.List[id] = nil
	end
end

return Tween
