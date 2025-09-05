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

-- Core
local timer          = require(script.Timer)
local maid           = require(script.Maid)
local tween          = require(script.Tween)
local anim           = require(script.Animation)

-- Flow / control
local debounce       = require(script.Debounce)
local ratelimiterMod = require(script.RateLimiter)
local randomweighted = require(script.RandomWeighted)
local timeline       = require(script.Timeline)
local seededrng      = require(script.SeededRng)

-- AI / gameplay
local blackboardMod  = require(script.Blackboard)
local fsmMod         = require(script.FSM)
local perception     = require(script.Perception)
local directorMod    = require(script.Director)
local objectpoolMod  = require(script.ObjectPool)
local objectiveMgr   = require(script.ObjectiveManager)


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
