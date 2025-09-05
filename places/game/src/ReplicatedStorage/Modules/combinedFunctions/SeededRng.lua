--[[
  SeededRng
  ---------
  Purpose:
    Deterministic random tied to a seed (per-floor). Same seed => same layout.
  API:
    local rng = SeededRng.new(seedStringOrNumber)
    rng:nextNumber(a, b)  -- inclusive
    rng:nextInteger(a, b) -- inclusive
    rng:shuffle(array)    -- in-place Fisher-Yates
    rng:pickWeighted(map) -- uses weights (Common=60, Rare=30, ...)
]]
local SeededRng = {}
SeededRng.__index = SeededRng

function SeededRng.new(seed: any)
	local self = setmetatable({}, SeededRng)
	self._random = Random.new(typeof(seed) == "number" and seed or tonumber(string.byte(tostring(seed), 1, 4)) or 0)
	return self
end

function SeededRng:nextNumber(a: number?, b: number?)
	a, b = a or 0, b or 1
	return self._random:NextNumber(a, b)
end

function SeededRng:nextInteger(a: number, b: number)
	return self._random:NextInteger(a, b)
end

function SeededRng:shuffle(t: {any})
	for i = #t, 2, -1 do
		local j = self._random:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

function SeededRng:pickWeighted(weights: {[any]: number})
	local total = 0
	for _,w in weights do total += w end
	local r = self._random:NextNumber(0, total)
	for k,w in weights do
		if r < w then return k end
		r -= w
	end
end

return SeededRng
