local maid = require(game.ReplicatedStorage.Modules.combinedFunctions):maid(true)
local TextChatService = game:GetService("TextChatService")
local backpack = require(script.Parent.PlayersPart.Backpack)


local Players = game:GetService("Players")

local api = {}
local allowedPlrs = {
	1649598894,
	1021056267,
	3454147180,
}

---Sort---

local temptab = {}
for i,v in allowedPlrs do
	temptab[v] = v
end
allowedPlrs = nil
allowedPlrs = temptab
temptab = nil

---Commands---

local tinFood: TextChatCommand = TextChatService:WaitForChild("tinFood")	


---Events---

maid:GiveTask('command', tinFood.Triggered, function(plr:Player, message:string | number)
	if not allowedPlrs[plr.UserId] then return end
	local plr = Players[plr.Name]
	
	local res = {}
	for part in string.gmatch(message, "[^" .. '/' .. " " .. "]+") do
		table.insert(res, part)
	end
	
	if not res[2] then res[2] = 1 end
	
	if tonumber(res[2]) <= 4 - #backpack:getPlayerInventory(plr, true) then
		for i = 1, res[2] do
			local item = backpack:createANewItem(nil, res[1])
			item:changeHolder()
		end
		return
	end
	for i = 1, res[2] do
		backpack:createANewItem(nil, res[1], plr.Character.HumanoidRootPart.Position + plr.Character.HumanoidRootPart.CFrame.LookVector * 5)
	end
	
end)

return api
