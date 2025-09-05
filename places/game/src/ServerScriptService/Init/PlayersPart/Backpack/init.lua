local comF = require(game.ReplicatedStorage.Modules.combinedFunctions)
local maid = comF:maid(true)
local lib = require(script.ItemLibrary)
local signal = require(game.ReplicatedStorage.Modules.GoodSignal)
local HTTP = game:GetService("HttpService")
local collection = game:GetService('CollectionService')
local invEvent = game.ReplicatedStorage.Events.Backpack.Inventory

local api = {}
local _globalItemList = {}
local _plrsBackpack = {}

local inventoryChanged = signal.new()

---Type---

type itemType = {
	['id'] : string,
	['holder'] : string | Player,
	['type'] : string,
	['item'] : Instance,
}

---Checking---

local function uCheck(plr: Player? | string?, itemType: string?, itemId: string?)
	local isPlrString = typeof(plr) == 'string'
	local isPlr = plr and plr:IsA('Player')
	if not isPlrString or not isPlr then
		warn('plr cannot be ' .. plr)
		return {false}
	end
	
	local isTypeNil = itemType == nil
	local isTypeString = typeof(itemType) == 'string'
	if not isTypeNil or not isTypeString then
		warn('itemType cannot be ' .. itemType)
		return {nil, false}
	end
	
	local isIdNil = itemType == nil
	local isIdString = typeof(itemType) == 'string'
	if not isIdNil or not isIdString then
		warn('itemId cannot be ' .. itemId)
		return {nil, nil, false}
	end
	
	
	local plrCheckV: boolean = false
	local itemCheckV: boolean = false
	
	local function plrCh()
		plrCheckV = true
	end
	
	local function itmCh()
		itemCheckV = true
	end
	
	local function plrCheck(existingPlayer: boolean? , inBackpack: boolean?)
		if game.Players[plr] and existingPlayer then plrCh() end
		if _plrsBackpack[plr.UserId] and inBackpack then plrCh() end
	end
	local function itemCheck(typeCheck: boolean? ,inGlobal: boolean?, inPlayer: boolean?)
		if lib[itemType] and typeCheck then itmCh() end
		if _globalItemList[itemId] and inGlobal then itmCh() end
		if _plrsBackpack[plr.UserId]['items'][itemId] and inPlayer then itmCh() end 
	end
	
	if isPlr and isIdString then plrCheck(false, true) itemCheck() end
	if typeof(plr) == Instance then plrCheck(true) end
	if itemType then itemCheck(true) end
	
end

---Methods---

function api:inventoryCreate(plr: Player)
	if _plrsBackpack[plr.UserId] then warn('This player already has inventory') return end
	local invClass = {}
	invClass.items = {}
	invClass.plr = plr
	
	_plrsBackpack[plr.UserId] = invClass
	
	return invClass
end

function api:changeItemHolder(toPlrOrGlobal: Player | string, id: string, throw: boolean?)
	if not id then return end
	if not toPlrOrGlobal then return end
	
	local function change(item: (itemType))
		local oldHolder = item.holder
		
		if toPlrOrGlobal == 'global' then
			item.holder = 'global'
			_globalItemList[item.id] = item
			_plrsBackpack[toPlrOrGlobal.UserId]['items'][item.id] = nil
			
			item.item.Parent = workspace.WorldItems
			for i,v: MeshPart in item.item:GetChildren() do
				v.Massless = false
				v.CanCollide = true
			end
			
			local hrp = oldHolder.Character.HumanoidRootPart
			item.item:MoveTo(hrp.Position + hrp.CFrame.LookVector * 2)
		else
			item.holder = toPlrOrGlobal.UserId
			table.insert(_plrsBackpack[toPlrOrGlobal.UserId]['items'], item)
			_globalItemList[item.id] = nil
			
			item.item.Parent = game.ServerStorage.ItemsStorage
			for i,v: MeshPart in item.item:GetChildren() do
				v.Massless = true
				v.CanCollide = false
			end
		end
	end
	
	if toPlrOrGlobal.ClassName == 'Player' then
		for itemID, itemClass in _globalItemList do
			if itemID == id then change(itemClass) end
		end
	elseif toPlrOrGlobal == 'global' then
		for plr,class in _plrsBackpack do
			for ID,itemClass in class['items'] do
				if ID == id then change(itemClass) end
			end
		end
	end
end

function api:getPlayerInventory(plr: Player, array: boolean?)
	if not _plrsBackpack[plr.UserId] then warn('This player does not exist: ' .. plr) return end
	if array then
		local tmpt = {}
		for i,v in _plrsBackpack[plr.UserId]['items'] do
			table.insert(tmpt, v)
		end
		return tmpt
	end
	return _plrsBackpack[plr.UserId]['items']
end

function api:createANewItem(id: string, itemType: string, position: CFrame)
	if _globalItemList[id] or not id or false then if id then warn('This id already used: ' .. id) end id = HTTP:GenerateGUID(false) end
	if not itemType then warn('itemType cannot be ' .. itemType) return end
	if not lib[itemType] then warn('This item does not exist') return end
	
	local itemClass = {}
	itemClass.id = itemType .. '/' .. id
	itemClass.holder = 'global'
	itemClass.type = itemType
	itemClass.action = lib[itemType].Action
	itemClass.item = workspace.Items:FindFirstChild(itemType):Clone()
	itemClass.trigger = itemClass.item:FindFirstChild('Trigger', true)
	
	itemClass.item.Parent = workspace.WorldItems
	itemClass.item:SetAttribute('Id', itemClass.id)
	if position then itemClass.item:MoveTo(position) for i,v in itemClass.item:GetChildren() do v.Anchored = false end end
	
	
	maid:GiveTask(itemClass.id .. '/trigger', itemClass.trigger.Triggered, function(plr: Player)
		if #_plrsBackpack[plr.UserId]['items'] >= 4 then return end
		api:changeItemHolder(plr, itemClass.id)
	end)
	
	_globalItemList[itemClass.id] = itemClass
	inventoryChanged:Fire(itemClass, 'global')
	
	return itemClass
end

---Events---

inventoryChanged:Connect(function(item: {any}, state: string)
	--print(item, state)
end)

maid:GiveTask('plrAdded', game.Players.PlayerAdded, function(plr)
	api:inventoryCreate(plr)
end)

maid:GiveTask('plrRemoved', game.Players.PlayerRemoving, function(plr)
	_plrsBackpack[plr.UserId] = nil
end)

return api
