--[[
  Debounce
  --------
  Purpose:
    Prevents a function from being called repeatedly within a short time window.
    Useful for click handlers, ability buttons, remote invocations, etc.

  API:
    Debounce.call(key: string, wait: number, fn: () -> ()): boolean
      - key: unique identifier for the action (e.g., "OpenDoor:userId123")
      - wait: cooldown window in seconds
      - fn:   function to execute once

    Returns `true` if the call was accepted (will run), `false` if it was ignored.

  Example:
    local Debounce = require(script.Parent.Debounce)
    Debounce.call("OpenDoor", 0.25, function()
      print("Runs at most once every 0.25s per key")
    end)
]]

local Debounce = {}
local active: {[string]: boolean} = {}

function Debounce.call(key: string, wait: number, fn: () -> ()): boolean
	if active[key] then
		return false
	end
	active[key] = true

	-- Defer execution so call-site returns quickly
	task.defer(function()
		local ok, err = pcall(fn)
		if not ok then
			warn("[Debounce] Error:", err)
		end
		task.delay(wait, function()
			active[key] = nil
		end)
	end)

	return true
end

return Debounce
