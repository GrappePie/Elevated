local event = game.ReplicatedStorage.Events.Info
local currentCamera = workspace.CurrentCamera
local hrt: BasePart = script.Parent:WaitForChild('HumanoidRootPart')
local data = game.ReplicatedStorage.Events.Data.DataFunction
local maid = require(game.ReplicatedStorage.Modules.combinedFunctions):maid():GetSharedMaid('localMaid')

local fnTab = {
	['ChangeCamera'] = function(parent: BasePart, cType)
		currentCamera.CameraType = Enum.CameraType[cType]
		if parent.ClassName == 'Humanoid' then return end
		currentCamera.CFrame = CFrame.lookAt(parent.CFrame.Position, hrt.CFrame.Position)
	end,
	
}

maid:GiveTask('fnTab', event.OnClientEvent, function(signal: string, instance: Instance)
	local res = {}
	for part in string.gmatch(signal, "[^" .. '/' .. "]+") do
		table.insert(res, part)
	end
	local fn = fnTab[res[1]]
	
	if fn then fn(instance, res[2]) end
end)