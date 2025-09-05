local tpService = game["Teleport Service"]
local maid = require(game.ReplicatedStorage.Modules.combinedFunctions):maid(true)

local api = {}

local ATTEMPT_LIMIT = 4
local RETRY_DELAY = 1
local FLOOD_DELAY = 15

local TEMPLATE_ID = 119449351936820

---Methods---

function api:tpToReserve(plrs:Players)
	local reserved = tpService:ReserveServer(TEMPLATE_ID)
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		placeId = reserved
	})
	
	local attemptIndex = 0
	local success, result 
	
	print(options,reserved)
	
	repeat
		success, result = pcall(function()
			return tpService:TeleportAsync(TEMPLATE_ID, plrs, options)
		end)
		attemptIndex += 1
		if not success then
			task.wait(RETRY_DELAY)
		end
	until success or attemptIndex == ATTEMPT_LIMIT

	if not success then
		warn(result) 
	end
end

---Events---

maid:GiveTask('tpFail', tpService.TeleportInitFailed, function(player: Player, teleportResult, errorMessage, targetPlaceId, teleportOptions)
	player:Kick('Unable to teleport to: ' .. targetPlaceId .. ', ' .. tostring(teleportResult) .. ', ' .. errorMessage)
end)

return api
