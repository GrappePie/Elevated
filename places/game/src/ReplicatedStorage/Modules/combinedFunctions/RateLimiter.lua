--[[
  RateLimiter (Token Bucket)
  --------------------------
  Purpose:
    Controls how often an operation is allowed to run. Great for protecting
    RemoteEvents/Functions or heavy loops from abuse/spam.

  Concept:
    - Bucket refills at `rate` tokens per second.
    - Bucket capacity is `burst` (max tokens).
    - Each `allow(cost)` consumes tokens (default 1) if available.

  API:
    local RateLimiter = require(script.Parent.RateLimiter)
    local lim = RateLimiter.new(rate: number, burst: number?)
      - rate: tokens per second
      - burst: max tokens in the bucket (defaults to rate)

    lim:allow(cost: number?): boolean
      - Returns true and consumes `cost` tokens if available.

  Example:
    local lim = RateLimiter.new(5, 10) -- 5 tokens/s, burst 10
    if lim:allow() then
      print("Allowed this tick")
    end
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type Lim = {
	rate: number,
	burst: number,
	tokens: number,
	_t: number?,
	allow: (self: Lim, cost: number?) -> boolean
}

function RateLimiter.new(rate: number, burst: number?): Lim
	local self: Lim = setmetatable({}, RateLimiter)
	self.rate = rate
	self.burst = burst or rate
	self.tokens = self.burst
	return self
end

function RateLimiter:allow(cost: number?): boolean
	cost = cost or 1
	local now = os.clock()
	local last = self._t or now

	-- Refill tokens based on elapsed time
	self.tokens = math.min(self.burst, self.tokens + (now - last) * self.rate)
	self._t = now

	if self.tokens >= cost then
		self.tokens -= cost
		return true
	end
	return false
end

return RateLimiter
