--[[
  Utils Facade Module
  -------------------
  Exposes all helpers under ReplicatedStorage.Modules.combinedFunctions:
  - Core: Timer, Maid, Tween, Animation
  - Control/Flow: Debounce, RateLimiter, Timeline, RandomWeighted, SeededRng
  - AI/Gameplay: Blackboard, FSM, Perception, Director, ObjectPool, ObjectiveManager
  - Extras: GoodSignal, FastVector, MonsterDebugEvent (if you use them)

  Quick usage:
    local Utils = require(ReplicatedStorage.Modules.combinedFunctions.Init)

    Utils:debounce().call("OpenDoor", 0.25, function() print("runs at most every 0.25s") end)

    local lim = Utils:ratelimiter(5, 10)
    if lim:allow() then print("allowed") end

    local rarity = Utils:random().pick({Common=60, Rare=30, Epic=9, Mythic=1})

    Utils:timeline(true)
      :to(part, {Transparency = 1}, 0.5)
      :wait(0.2)
      :to(part, {Transparency = 0}, 0.5)
      :play()
]]

---Made by @m1rrun---
---Special thanks: @VioletElementalist---

local F = script.Parent  -- <-- if modules are siblings of this file. If they are children, use `local F = script`.

-- Core
local timer          = require(F:WaitForChild("Timer"))
local maid           = require(F:WaitForChild("Maid"))
local tween          = require(F:WaitForChild("Tween"))
local anim           = require(F:WaitForChild("Animation"))

-- Flow / control
local debounce       = require(F:WaitForChild("Debounce"))
local ratelimiterMod = require(F:WaitForChild("RateLimiter"))
local randomweighted = require(F:WaitForChild("RandomWeighted"))
local timeline       = require(F:WaitForChild("Timeline"))
local seededrng      = require(F:WaitForChild("SeededRng"))

-- AI / gameplay
local blackboardMod  = require(F:WaitForChild("Blackboard"))
local fsmMod         = require(F:WaitForChild("FSM"))
local perception     = require(F:WaitForChild("Perception"))
local directorMod    = require(F:WaitForChild("Director"))
local objectpoolMod  = require(F:WaitForChild("ObjectPool"))
local objectiveMgr   = require(F:WaitForChild("ObjectiveManager"))


local api = {}

-- Core
function api:timer(new: boolean?)                         return new and timer.new() or timer end
function api:maid(new: boolean?, isShared:boolean?, name:string?) return new and maid.new(isShared, name) or maid end
function api:tween()                                      return tween end
function api:animation()                                  return anim end

-- Flow / control
function api:debounce()                                   return debounce end
function api:ratelimiter(rate: number, burst: number?)    return ratelimiterMod.new(rate, burst) end
function api:random()                                     return randomweighted end
function api:timeline(new: boolean?)                      return new and timeline.new() or timeline end
function api:rng(seed: any)                               return seededrng.new(seed) end

-- AI / gameplay
function api:blackboard()                                 return blackboardMod.new() end
function api:fsm(initial: string)                         return fsmMod.new(initial) end
function api:perception()                                 return perception end
function api:director(cfg, rng)                           return directorMod.new(cfg, rng) end
function api:pool(template: Instance, prewarm: number?)   return objectpoolMod.new(template, prewarm) end
function api:objectives()                                 return objectiveMgr end  -- if ObjectiveManager is a singleton

return api
