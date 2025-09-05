local TweenService = game:GetService('TweenService')
local HTTP = game:GetService("HttpService")

local Tween = { List = {} }

type Instances = {Instance}
type TweenClass = {
	Id: string,
	tween?: Tween,
	_completeEvent: BindableEvent,
	forcedCancel: boolean,
	tweenEndedEvent: (self: TweenClass) -> RBXScriptSignal,
	cancelTween: (self: TweenClass) -> (),
	await: (self: TweenClass) -> ("Finished" | "Stopped")
}

local function _connectCompleted(id: string, tw: Tween, cls: TweenClass)
	Tween.List[id] = cls
	tw.Completed:ConnectOnce(function()
		Tween.List[id] = nil
		cls._completeEvent:Fire(cls.forcedCancel ~= true and 'Finished' or 'Stopped')
	end)
end

local function _makeSingle(instance: Instance, prop: {}, playTime: number, id: string?, delay: number?, style: Enum.EasingStyle, reverse: boolean?, repeatCount: number?): TweenClass
	local cls: TweenClass = {
		Id = id or HTTP:GenerateGUID(false),
		_completeEvent = Instance.new('BindableEvent'),
		forcedCancel = false
	}
	if Tween.List[cls.Id] then Tween.List[cls.Id]:cancelTween() end
	local info = TweenInfo.new(playTime, style, Enum.EasingDirection.InOut, repeatCount or 0, reverse or false, delay or 0)
	local tw = TweenService:Create(instance, info, prop)
	cls.tween = tw

	function cls:tweenEndedEvent() return self._completeEvent.Event end
	function cls:cancelTween() self.forcedCancel = true; if self.tween then self.tween:Cancel() end end
	function cls:await() return self._completeEvent.Event:Wait() end

	tw:Play()
	_connectCompleted(cls.Id, tw, cls)
	return cls
end

local function _makeMany(instances: Instances, prop: {}, playTime: number, id: string?, delay: number?, style: Enum.EasingStyle, reverse: boolean?, repeatCount: number?): TweenClass
	local groupId = id or HTTP:GenerateGUID(false)
	if Tween.List[groupId] then Tween.List[groupId]:cancelTween() end
	local done = 0
	local total = #instances
	local ev = Instance.new('BindableEvent')
	local group = {
		Id = groupId,
		_completeEvent = ev,
		forcedCancel = false,
		cancelTween = function(self)
			self.forcedCancel = true
			for _,inst in instances do
				local key = tostring(inst) .. ":" .. groupId
				local sub = Tween.List[key]
				if sub then sub:cancelTween() end
			end
		end,
		tweenEndedEvent = function(self) return ev.Event end,
		await = function(self) return ev.Event:Wait() end
	}

	for _,inst in instances do
		local key = tostring(inst) .. ":" .. groupId
		local sub = _makeSingle(inst, prop, playTime, key, delay, style, reverse, repeatCount)
		sub._completeEvent.Event:Connect(function()
			done += 1
			if done >= total then
				Tween.List[groupId] = nil
				ev:Fire(group.forcedCancel ~= true and 'Finished' or 'Stopped')
			end
		end)
	end
	Tween.List[groupId] = group :: any
	return group :: any
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

return Tween
