local HTTP = game:GetService("HttpService")
local Collection = game.CollectionService
local mFolder = game.ReplicatedStorage.Modules
local combine = require(mFolder.combinedFunctions)
local timer = combine:timer(true)
local maid = combine:maid(true)
local tween = combine:tween()
local tpModule = require(script.tpModule)
local toPlrEvent = game.ReplicatedStorage.Events.Info

local api = {}

---localFn---

local function search(name: string, path: Instance?)
	if not path then path = workspace:GetDescendants() else path = path:GetDescendants() end
	for i,v in path do
		if v.Name == name then
			return v
		end
	end
	warn('Cannot find ' .. name)
end

---Methods---

function api:assingLift(folder: Folder)
	local liftClass = {}
	liftClass.Id = HTTP:GenerateGUID(false)
	liftClass.folder = folder
	liftClass.joinButton = search('ProximityPrompt', folder)
	liftClass.spawn = search('Spawn', folder)
	liftClass.backSpawn = search('Back', folder)
	liftClass.plrsLabel = search('nrPlrs', folder)
	liftClass.liftTimerLabel = search('liftTimer', folder)
	liftClass.customCamera = search('CustomCamera', folder)
	liftClass.maxPersons = search('maxPersons', folder).Value
	liftClass.plrs = {}
	liftClass.started = false
	liftClass.timer = timer.new()
	
	liftClass.leftDoor = search('leftDoor', folder)
	liftClass.rightDoor = search('rightDoor', folder)
	liftClass.outLeftDoor = search('outLeftDoor', folder)
	liftClass.outRightDoor = search('outRightDoor', folder)
	
	liftClass.leftClose = search('leftDoorClose', folder)
	liftClass.rightClose = search('rightDoorClose', folder)
	liftClass.oLeftClose = search('outLeftDoorPos', folder)
	liftClass.oRightClos = search('outRightDoorPos', folder)
	
	maid:GiveTask(nil, liftClass.joinButton.Triggered, function(plr:Player)
		local function status()
			liftClass.plrsLabel.Text = #liftClass.plrs .. '/' .. liftClass.maxPersons
			if #liftClass.plrs > 0 and not liftClass.started then
				liftClass.started = true
				local tTime = 30
				if #liftClass.plrs == liftClass.maxPersons then tTime = 5 end
				liftClass.timer:start(tTime, function(self)
					local label: TextLabel = liftClass.liftTimerLabel
					label.Text = self:getTimeLeft()
				end)
				return
			elseif #liftClass.plrs == liftClass.maxPersons and liftClass.started then
				if liftClass.timer:getTimeLeft() > 5 then
					liftClass.timer:start(5, function(self)
						local label: TextLabel = liftClass.liftTimerLabel
						label.Text = self:getTimeLeft()
					end)
				end
				return
			elseif #liftClass.plrs == 0 and liftClass.started then
				liftClass.timer:stop()
				liftClass.started = false
				return
			end
		end
		
		for i,v in liftClass.plrs do
			if plr.UserId == v.UserId then
				plr.Character.HumanoidRootPart.CFrame = liftClass.backSpawn.CFrame
				toPlrEvent:FireClient(plr, 'ChangeCamera/Custom', plr.Character.Humanoid)
				liftClass.plrs[i] = nil
				status()
				return
			end 
		end
		
		if #liftClass.plrs == liftClass.maxPersons then return end
		table.insert(liftClass.plrs, plr)
		plr.Character.HumanoidRootPart.CFrame = liftClass.spawn.CFrame
		toPlrEvent:FireClient(plr, 'ChangeCamera/Scriptable', liftClass.customCamera)
		status()
	end)
	
	maid:GiveTask(nil, liftClass.timer:getFinishedEventSignal(), function(state: string)
		if state == 'Finished' then
			liftClass.started = false
			local old = liftClass.leftDoor.Position
			local ord = liftClass.rightDoor.Position
			local oord = liftClass.outRightDoor.Position
			local oold = liftClass.outLeftDoor.Position
			tween.linear(liftClass.leftDoor, {Position = liftClass.leftClose.Position}, 1.4)
			tween.linear(liftClass.rightDoor, {Position = liftClass.rightClose.Position}, 1.4)
			tween.linear(liftClass.outLeftDoor, {Position = liftClass.oLeftClose.Position}, 1.4)
			tween.linear(liftClass.outRightDoor, {Position = liftClass.oRightClos.Position}, 1.4)
			liftClass.liftTimerLabel.Text = ''
			liftClass.plrsLabel.Text = ''
			liftClass.joinButton.Enabled = false
			task.delay(1.5, function()
				tpModule:tpToReserve(liftClass.plrs)
			end)
			task.delay(4.5,function()
				tween.linear(liftClass.leftDoor, {Position = old}, 1.4)
				tween.linear(liftClass.rightDoor, {Position = ord}, 1.4)
				tween.linear(liftClass.outLeftDoor, {Position = oold}, 1.4)
				tween.linear(liftClass.outRightDoor, {Position = oord}, 1.4)
				task.delay(1.5, function()
					liftClass.plrsLabel.Text = '0/' .. liftClass.maxPersons
					liftClass.joinButton.Enabled = true
					table.clear(liftClass.plrs)
				end)
			end)
			return
		end
		liftClass.liftTimerLabel.Text = ''
	end)
	
	maid:GiveTask('playerRemoved' .. liftClass.Id, game.Players.PlayerRemoving,function(lPlr)
		for i,v in liftClass.plrs do
			if lPlr.UserId == v.UserId then
				liftClass.plrs[i] = nil
			end
		end
	end)
	
	return liftClass
end

local lifts = Collection:GetTagged('Lift')
for i,v in lifts do api:assingLift(v) end


return api
