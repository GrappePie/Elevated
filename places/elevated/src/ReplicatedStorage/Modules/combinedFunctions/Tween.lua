local Twee = game:GetService('TweenService')
local Run = game["Run Service"]
local HTTP = game:GetService("HttpService")

local Tween = {
	List = {}
}

type advanced = {
	['Instances']: Instance | {Instances},
	
}

---LocalFn---

local function setTween(instance, prop, playTime, Id, delayedStart, style: Enum.EasingStyle, reverse: boolean?, repeatCount: number?)
	local TweenClass = {}
	TweenClass.Id = Id or HTTP:GenerateGUID(false)
	TweenClass.forcedCancel = false
	TweenClass._completeEvent = Instance.new('BindableEvent')
	
	if Tween.List[TweenClass.Id] then Tween.List[TweenClass.Id]:cancelTween() end
	
	if not reverse then reverse = false end
	if not delayedStart then delayedStart = 0 end
	if not repeatCount then repeatCount = 0 end

	local pattern = TweenInfo.new(playTime, style, Enum.EasingDirection.InOut, repeatCount, reverse, delayedStart)
	local tween = Twee:Create(instance, pattern, prop)
	
	tween:Play()

	function TweenClass:tweenEndedEvent()
		return TweenClass._completeEvent.Event
	end

	function TweenClass:cancelTween()
		TweenClass.forcedCancel = true
		return tween:Cancel()
	end
	
	Tween.List[TweenClass.Id] = TweenClass
	
	tween.Completed:Once(function()
		Tween.List[TweenClass.Id] = nil
		TweenClass._completeEvent:Fire(TweenClass.forcedCancel ~= true and 'Finished' or 'Stopped')
	end)

	return TweenClass
end

---Methods---

function Tween.linear(instances: Instance | Instances, prop: {any}, playTime: number, Id: string?, delayedStart: number?, reverse: boolean?, repeatCount: number?)
	return setTween(instances, prop, playTime, Id, delayedStart, Enum.EasingStyle.Linear, reverse, repeatCount)
end

function Tween.exponential(instance: Instance , prop: {any}, playTime: number, Id: string?, delayedStart: number?, reverse: boolean?, repeatCount: number?)
	return setTween(instance, prop, playTime, Id, delayedStart, Enum.EasingStyle.Exponential, reverse, repeatCount)
end

function Tween:adv(): advanced
	
end


return Tween