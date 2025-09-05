--[[

	
	


]]
---Made by @m1rrun---
---Special thanks: @VioletElementalist---
	

local timer = require(script.Timer)
local maid = require(script.Maid)
local tween = require(script.Tween)
local anim = require(script.Animation)

local api = {}

function api:timer(new: boolean?)
	return new == true and timer.new() or timer
end

function api:maid(new: boolean?, IsShared: boolean?, MaidName: string?)
	return new == true and maid.new(IsShared, MaidName) or maid
end

function api:tween()
	return tween
end

function api:animation()
	return anim
end

return api
