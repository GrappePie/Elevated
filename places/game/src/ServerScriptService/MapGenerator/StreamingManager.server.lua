-- Script: StreamingManager
-- FINAL VERSION: Config-driven render distances, axis control, and seeded chunk calls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameStateManager = require(script.Parent:WaitForChild("GameStateManager"))
local MapConfig = require(ReplicatedStorage:WaitForChild("MapConfig"))
local MapGeneratorFolder = script.Parent:WaitForChild("MapGenerators")

-- We keep unload a bit larger than load to reduce thrashing.
local UNLOAD_BUFFER = 1

-- Per-player loaded chunk models
local loadedChunks: {[string]: {[string]: Model?}} = {}
local currentMapInstance: Model? = nil

-- Only these map types are streamable
local streamingCompatibleMaps = {
	["Backrooms (level 0)"] = true,
	["Backrooms (level 1)"] = true,
}

-- Cache generator requires by script name
local GeneratorCache: {[string]: any} = {}

local function resetStreamingState()
	if next(loadedChunks) then
		print("StreamingManager: Detected new map or change. Clearing previous state & chunks...")
		for _, perPlayer in pairs(loadedChunks) do
			for _, mdl in pairs(perPlayer) do
				if mdl then mdl:Destroy() end
			end
		end
		loadedChunks = {}
	end
	-- do not clear GeneratorCache; different map types can reuse same module
end

Players.PlayerRemoving:Connect(function(player)
	local pk = "player_" .. player.UserId
	if loadedChunks[pk] then
		for _, c in pairs(loadedChunks[pk]) do
			if c then c:Destroy() end
		end
		loadedChunks[pk] = nil
	end
end)

while task.wait(0.5) do
	local mapContainer = Workspace:FindFirstChild("GeneratedMap")

	if mapContainer ~= currentMapInstance then
		resetStreamingState()
		currentMapInstance = mapContainer
	end

	-- If there is no active map container or the map type is not streamable, skip this tick.
	if not currentMapInstance or not streamingCompatibleMaps[GameStateManager.ActiveMapType] then
		continue
	end

	local config = MapConfig[GameStateManager.ActiveMapType]
	if not config or not config.generation or not config.generation.generatorScript then
		continue
	end

	-- Read render distances from config; provide reasonable defaults.
	local renderDistHor = config.generation.renderDistanceHor or 2
	local renderDistVer = config.generation.renderDistanceVer or 1

	-- Require generator module (cached by name).
	local genName = config.generation.generatorScript
	local GeneratorModule = GeneratorCache[genName]
	if not GeneratorModule then
		GeneratorModule = require(MapGeneratorFolder:WaitForChild(genName))
		GeneratorCache[genName] = GeneratorModule
	end

	local CHUNK_SIZE = config.generation.CHUNK_SIZE or 16
	local CELL_SIZE = config.construction.CELL_SIZE
	local WALL_HEIGHT = config.construction.WALL_HEIGHT

	-- Determine per-floor seed: prefer the attribute set by MapBuilder; fallback to profile/config.
	local seed =
		(currentMapInstance and currentMapInstance:GetAttribute("Seed"))
		or (config.generation and config.generation.seed)
		or 0

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end

		local playerKey = "player_" .. player.UserId
		if not loadedChunks[playerKey] then loadedChunks[playerKey] = {} end

		local playerPos = hrp.Position
		local scale = (CHUNK_SIZE * CELL_SIZE)
		local playerChunkX = math.floor(playerPos.X / scale + 0.5)
		local playerChunkZ = math.floor(playerPos.Z / scale + 0.5)

		local playerChunkY
		if config.generation.isVerticallyInfinite then
			playerChunkY = math.floor(playerPos.Y / WALL_HEIGHT + 0.5)
		else
			playerChunkY = 0
		end

		-- Y-range depends on vertical infinity flag.
		local startY, endY
		if config.generation.isVerticallyInfinite then
			startY = playerChunkY - renderDistVer
			endY   = playerChunkY + renderDistVer
		else
			startY, endY = 0, 0
		end

		for y = startY, endY do
			for x = playerChunkX - renderDistHor, playerChunkX + renderDistHor do
				for z = playerChunkZ - renderDistHor, playerChunkZ + renderDistHor do
					-- Finite XY bounds (if profile defines finite plane)
					local isFinite = config.generation.finiteWidth and config.generation.finiteDepth
					if isFinite then
						if x < 0 or x >= config.generation.finiteWidth or z < 0 or z >= config.generation.finiteDepth then
							continue
						end
					end

					local chunkKey = table.concat({ x, y, z }, ",")
					-- If we already have a model but someone deleted it externally, consider it unloaded.
					if loadedChunks[playerKey][chunkKey] and loadedChunks[playerKey][chunkKey].Parent == nil then
						loadedChunks[playerKey][chunkKey] = nil
					end

					if not loadedChunks[playerKey][chunkKey] then
						-- Pass the seed down to the generator (new signature).
						local ok, mdl = pcall(function()
							return GeneratorModule.GenerateChunk(x, y, z, config, currentMapInstance, seed)
						end)
						if ok then
							loadedChunks[playerKey][chunkKey] = mdl
						else
							warn(("[StreamingManager] GenerateChunk failed at %s (error: %s)"):format(chunkKey, tostring(mdl)))
						end
					end
				end
			end
		end

		-- Unload chunks outside the buffer
		local chunksToRemove = {}
		local unloadDistHor = renderDistHor + UNLOAD_BUFFER
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
		for _, key in ipairs(chunksToRemove) do
			loadedChunks[playerKey][key] = nil
		end
	end
end
