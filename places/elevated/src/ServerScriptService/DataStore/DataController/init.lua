local ProfileStore = require(script.ProfileStore)
local RunService = game:GetService("RunService")
local deepSearch = require(script.deepSearch)

local DataLoaded = script.Parent.DataLoaded
local DataLoadedRemote = game.ReplicatedStorage.Events.Data.DataLoadedEvent

local getDataFunction = game.ReplicatedStorage.Events.Data.DataFunction

local dataControll = {}

local PROFILE_TEMPLATE = { 
	MaxFloor = 0,
	Money = 0,
	Achievements = {
		
	},
}


local Players = game:GetService("Players")

local PlayerStore = ProfileStore.New("PlayerStore", PROFILE_TEMPLATE)
if RunService:IsStudio() == true then
	PlayerStore = PlayerStore.Mock
	warn('Saves Work in Studio Mode')
end
local Profiles = {}



local function PlayerAdded(player)

	-- Start a profile session for this player's data:

	local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile ~= nil then

		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing variables from PROFILE_TEMPLATE (optional)

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			player:Kick(`Profile session end - Please rejoin`)
		end)

		if player.Parent == Players then
			Profiles[player] = profile
			DataLoaded:Fire(player)
			if DataLoadedRemote ~= nil then
				DataLoadedRemote:FireClient(player)
			end
			--print(`Profile loaded for {player.DisplayName}!`)
			
		else
			profile:EndSession()
		end

	else
		player:Kick(`Profile load fail - Please rejoin`)
	end

end

for _, player in Players:GetPlayers() do
	task.spawn(PlayerAdded, player)
end

---dataWork---

function dataControll.GetData(Player: Player, Path: string)
	if Profiles[Player] ~= nil then
		if Path ~= nil then
			return deepSearch.deepSearch(Profiles[Player].Data, Path)
		else
			return Profiles[Player].Data
		end
	end

	return "Profile Not Loaded"
end

function dataControll.SetData(Player: Player, Path: string, Value: any)
	if Profiles[Player] ~= nil then
		deepSearch.deepWrite(Profiles[Player].Data, Path, Value)
	end
end

function dataControll.WipeData(Player: Player)
	if Profiles[Player] ~= nil then
		Profiles[Player].Data = PROFILE_TEMPLATE
		Profiles[Player]:EndSession()
	end
end

---Events---

getDataFunction.OnServerInvoke = function(plr: Player, path: any)
	return dataControll.GetData(plr, path)
end

Players.PlayerAdded:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	local profile = Profiles[player]
	if profile ~= nil then
		profile:EndSession()
	end
end)

---Loaded---

_G.dataControllerLoaded = true


return dataControll