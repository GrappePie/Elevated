--[[


	AnimSet:
	0 sec - event - Name: times | Value: loopStart , loopEnd, endAnim

]]


local HTTP = game:GetService('HttpService')

local maid = require(script.Parent.Maid).new()

local AnimationCache = Instance.new("Folder")
AnimationCache.Name = "AnimationCache"
AnimationCache.Parent = game.ReplicatedStorage

local api = {}
local animList = {}

function api:createAnim(id: string?, animationId: number, parent: Instance?, animator: Animator, loopingAnim: boolean?)
	local animClass = {}
	animClass.id = id or HTTP:GenerateGUID(false)
	animClass.isLooping = loopingAnim or false

	local anim = AnimationCache:FindFirstChild(string.find(animationId, 'rbxassetid://') and animationId or 'rbxassetid://'..animationId)

	if not anim then
		anim = Instance.new('Animation')
		anim.AnimationId = string.find(animationId, 'rbxassetid://') and animationId or 'rbxassetid://'..animationId
		anim.Name = anim.AnimationId
		anim.Parent = AnimationCache
	end
	
	
	function animClass:animationEndedEvent()
		return animClass.loadedAnim.Ended
	end

	function animClass:animationLoopEvent(state: boolean)
		return animClass.loadedAnim:GetMarkerReachedSignal('loop')
	end

	function animClass:animationEndMarkerEvent()
		return animClass.loadedAnim:GetMarkerReachedSignal('end')
	end

	function animClass:deleteAnim()
		anim:Destroy()
		animList[animClass.id] = nil
	end

	function animClass:Play(fade: number?)
		animClass:Stop()
		animClass.loadedAnim = animator:LoadAnimation(anim)
		animClass.loadedAnim:Play(fade or 0)

		---------------------

		maid:EndTaskByTaskId(animClass.id .. 'times')
		maid:EndTaskByTaskId(animClass.id .. 'loop')

		maid:GiveTask(animClass.id .. 'times', animClass.loadedAnim:GetMarkerReachedSignal('times'), function(data: string)
			local res = {}
			for part in string.gmatch(data, "[^" .. '/' .. "]+") do
				table.insert(res, part)
			end
			
			animClass.loopStart = res[1]
			animClass.loopEnd = res[2]
			animClass.animEnd = res[3]
			maid:EndTaskByTaskId(animClass.id .. 'times')
		end)

		maid:GiveTask(animClass.id .. 'loop', animClass.loadedAnim:GetMarkerReachedSignal('loop'), function(loopState)
			if animClass.isLooping then
				if loopState == 'false' then animClass.loadedAnim.TimePosition = animClass.loopStart end
			end
		end)
	end

	function animClass:Stop(fade: number?)
		for i,v in animator:GetPlayingAnimationTracks() do
			if v.Name == animClass.id then
				v:Stop(fade or 0)
			end
		end
	end

	function animClass.IsPlaying()
		return animClass.loadedAnim.IsPlaying
	end

	function animClass:looping(state: boolean?)
		animClass.isLooping = state
	end
	
	function animClass:getAnimId()
		return animClass.id
	end

	animList[animClass.id] = animClass

	return animClass
end

function api:getAnimationById(id: string)
	return animList[id]
end

return api