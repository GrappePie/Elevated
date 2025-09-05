--[[
  Timeline (Tween Orchestrator)
  -----------------------------
  Purpose:
    Build readable sequences of animations/tweens with series/parallel steps,
    and await their completion. Wraps your existing Tween helper.

  API:
    local Timeline = require(script.Parent.Timeline)

    local tl = Timeline.new()
      :to(target, props, duration)          -- enqueue a tween step
      :wait(seconds)                        -- enqueue a delay
      :parallel(function(sub)               -- run multiple tweens in parallel
          sub:to(partA, {Transparency=1}, 0.5)
          sub:to(partB, {Size=Vector3.new(4,4,4)}, 0.5)
        end)
    tl:play()   -- fire and forget (runs in a separate task)
    tl:await()  -- run synchronously and wait until all steps finish

  Notes:
    - Uses your Tween.linear(...) which returns an object with :await().
    - You can swap Tween.linear for other easing styles inside the code if needed.
]]

local Tween = require(script.Parent.Tween)

local Timeline = {}
Timeline.__index = Timeline

type Step = { kind: "to"|"wait"|"parallel", run: (tl:any)->() }

function Timeline.new()
	return setmetatable({ _steps = {} }, Timeline)
end

-- Enqueue a tween step (uses Tween.linear by default).
function Timeline:to(target: Instance|{Instance}, props: {}, duration: number)
	table.insert(self._steps, {
		kind = "to",
		run = function()
			local tw = Tween.linear(target, props, duration)
			tw:await()
		end
	})
	return self
end

-- Enqueue a wait (delay) step.
function Timeline:wait(sec: number)
	table.insert(self._steps, {
		kind = "wait",
		run = function() task.wait(sec) end
	})
	return self
end

-- Enqueue parallel tweens via builder callback.
-- `builder(sub)` receives a mini-API with `sub:to(...)` to add parallel tweens.
function Timeline:parallel(builder: (tl: any) -> ())
	table.insert(self._steps, {
		kind = "parallel",
		run = function()
			local subs = {}
			local sub = {
				to = function(_, inst: Instance|{Instance}, props: {}, dur: number)
					table.insert(subs, Tween.linear(inst, props, dur))
					return sub
				end
			}
			builder(sub)
			for _, tw in subs do
				tw:await()
			end
		end
	})
	return self
end

-- Play asynchronously (spawns a task).
function Timeline:play()
	task.spawn(function()
		for _, s in self._steps do
			s.run(self)
		end
	end)
	return self
end

-- Run synchronously and block until all steps complete.
function Timeline:await()
	for _, s in self._steps do
		s.run(self)
	end
end

return Timeline
