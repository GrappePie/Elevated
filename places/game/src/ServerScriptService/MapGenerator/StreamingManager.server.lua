-- Script: StreamingManager
-- VERSIÓN FINAL: Renderizado configurable y control de ejes

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameStateManager = require(script.Parent:WaitForChild("GameStateManager"))
local MapConfig = require(ReplicatedStorage:WaitForChild("MapConfig"))
local MapGeneratorFolder = script.Parent:WaitForChild("MapGenerators")

-- Ya no necesitamos las distancias fijas aquí
local UNLOAD_BUFFER = 1

local loadedChunks = {}
local currentMapInstance = nil

local streamingCompatibleMaps = {	
	["Backrooms (level 0)"] = true,
	["Backrooms (level 1)"] = true	
}

local function resetStreamingState() if next(loadedChunks) then print("StreamingManager: Detectado un nuevo mapa o cambio. Limpiando estado y chunks anteriores...") for _, p in pairs(loadedChunks) do for _, m in pairs(p) do if m then m:Destroy() end end end loadedChunks = {} end end
game.Players.PlayerRemoving:Connect(function(player) local pk = "player_"..player.UserId if loadedChunks[pk] then for _,c in pairs(loadedChunks[pk]) do if c then c:Destroy() end end loadedChunks[pk]=nil end end)


while task.wait(0.5) do
	local mapContainer = Workspace:FindFirstChild("GeneratedMap")

	if mapContainer ~= currentMapInstance then
		resetStreamingState()
		currentMapInstance = mapContainer
	end

	if not currentMapInstance or not streamingCompatibleMaps[GameStateManager.ActiveMapType] then
		continue
	end

	local config = MapConfig[GameStateManager.ActiveMapType]
	if not config or not config.generation.generatorScript then continue end

	-- [[ CAMBIO CLAVE: Leemos la distancia desde el MapConfig ]]
	-- Si no está definida, usamos valores por defecto (2 y 1).
	local renderDistHor = config.generation.renderDistanceHor or 2
	local renderDistVer = config.generation.renderDistanceVer or 1

	local GeneratorModule = require(MapGeneratorFolder:WaitForChild(config.generation.generatorScript))

	local CHUNK_SIZE = config.generation.CHUNK_SIZE or 16
	local CELL_SIZE = config.construction.CELL_SIZE
	local WALL_HEIGHT = config.construction.WALL_HEIGHT

	for _, player in ipairs(Players:GetPlayers()) do
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then continue end

		local playerKey = "player_"..player.UserId
		if not loadedChunks[playerKey] then loadedChunks[playerKey] = {} end

		local playerPos = player.Character.HumanoidRootPart.Position
		local playerChunkX = math.floor(playerPos.X/(CHUNK_SIZE * CELL_SIZE) + 0.5)
		local playerChunkZ = math.floor(playerPos.Z/(CHUNK_SIZE * CELL_SIZE) + 0.5)

		local playerChunkY
		if config.generation.isVerticallyInfinite then
			playerChunkY = math.floor(playerPos.Y/WALL_HEIGHT + 0.5)
		else
			playerChunkY = 0
		end

		local startY, endY
		if config.generation.isVerticallyInfinite then
			startY = playerChunkY - renderDistVer -- Se usa la variable local
			endY = playerChunkY + renderDistVer
		else
			startY = 0
			endY = 0
		end

		for y = startY, endY do
			for x = playerChunkX - renderDistHor, playerChunkX + renderDistHor do -- Se usa la variable local
				for z = playerChunkZ - renderDistHor, playerChunkZ + renderDistHor do -- Se usa la variable local
					local isFinite = config.generation.finiteWidth and config.generation.finiteDepth
					if isFinite then
						if x < 0 or x >= config.generation.finiteWidth or z < 0 or z >= config.generation.finiteDepth then
							continue
						end
					end

					local chunkKey = table.concat({x,y,z},",")
					if not loadedChunks[playerKey][chunkKey] then
						loadedChunks[playerKey][chunkKey] = GeneratorModule.GenerateChunk(x, y, z, config, currentMapInstance)
					end
				end
			end
		end

		-- Lógica de descarga de chunks
		local chunksToRemove = {}
		local unloadDistHor = renderDistHor + UNLOAD_BUFFER -- Se usa la variable local
		local unloadDistVer = renderDistVer + UNLOAD_BUFFER
		for chunkKey, chunkModel in pairs(loadedChunks[playerKey]) do
			local parts = string.split(chunkKey, ",")
			local cX, cY, cZ = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
			local distX = math.abs(playerChunkX - cX)
			local distY = math.abs(playerChunkY - cY)
			local distZ = math.abs(playerChunkZ - cZ)

			if distX > unloadDistHor or distY > unloadDistVer or distZ > unloadDistHor then
				if chunkModel then chunkModel:Destroy() end
				table.insert(chunksToRemove, chunkKey)
			end
		end
		for _,key in ipairs(chunksToRemove) do loadedChunks[playerKey][key] = nil end
	end
end