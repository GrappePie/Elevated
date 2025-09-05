--[[
  RandomWeighted
  --------------
  Purpose:
    Picks a key from a table with numeric weights (sum doesn't need to be 1).
    Useful for loot tables, rarity selection, random variants, etc.

  API:
    RandomWeighted.pick(weights: {[any]: number}, rng: Random?): any
      - weights: map of choice -> weight (must be > 0)
      - rng: optional Random to control determinism

  Example:
    local RandomWeighted = require(script.Parent.RandomWeighted)
    local rarity = RandomWeighted.pick({
      Common = 60, Rare = 30, Epic = 9, Mythic = 1
    })
]]

local RandomWeighted = {}

function RandomWeighted.pick(weights: {[any]: number}, rng: Random?): any
	rng = rng or Random.new()
	local total = 0
	for _, w in weights do
		total += w
	end

	local r = rng:NextNumber(0, total)
	for key, w in weights do
		if r < w then
			return key
		end
		r -= w
	end
end

return RandomWeighted
