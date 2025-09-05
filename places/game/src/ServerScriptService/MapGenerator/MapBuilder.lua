-- ModuleScript: MapBuilder
-- FINAL VERSION (patched)
--[[
  MapBuilder
  ----------
  Purpose:
    - Orchestrates map creation for both Infinite and Finite profiles.
    - Cleans previous map/AI, wires per-floor seed, and (optionally) registers floor objectives.
    - Delegates:
        * Infinite: StreamingManager handles chunk generation.
        * Finite:   MapGenerator.generateLayout(...) builds a full layout.

  Key changes:
    ✔ Accepts an optional `seed` for reproducible floors.
    ✔ Uses a shared RNG (Random.new(seed)) and passes it to MapGenerator if supported.
    ✔ Removes duplicated monster spawn block (kept a single, seeded implementation).
    ✔ Optionally seeds/registers objectives via Utils:objectives() if available.

  API:
    local startPos = MapBuilder.Generate("Backrooms (level 0)", 12345)
]]

local MapBuilder = {}

-- Services / deps
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateManager = require(script.Parent:WaitForChild("GameStateManager"))
local MapConfig = require(ReplicatedStorage:WaitForChild("MapConfig"))
local MapGenerator = require(script.Parent:WaitForChild("MapGenerator"))
local Helpers = require(script.Parent:WaitForChild("MapBuilderHelpers"))

-- Optional: pull Utils facade if present (works with ModuleScript or Folder+Init)
local Utils do
	local Modules = ReplicatedStorage:FindFirstChild("Modules")
	local cf = Modules and Modules:FindFirstChild("combinedFunctions")
	if cf then
		local ok, res = pcall(function()
			if cf:IsA("ModuleScript") then
				return require(cf)
			else
				local init = cf:FindFirstChild("Init") or cf:FindFirstChild("init")
				return init and require(init) or nil
			end
		end)
		if ok then Utils = res end
	end
end

-- Neighbor helpers for door compatibility on finite maps
local NEIGH = {
	N = { r = -1, c =  0 },
	S = { r =  1, c =  0 },
	E = { r =  0, c =  1 },
	W = { r =  0, c = -1 },
}

-- Utility: safe pick with RNG (falls back to math.random)
local function randIndex(rng: Random?, n: number): number
	if rng then return rng:NextInteger(1, n) end
	return math.random(1, n)
end

-- Track generated monsters for cleanup between map rebuilds
local monsterMaid

function MapBuilder.Generate(themeName: string, seed: number?)
        -- Record active map profile
        GameStateManager.SetActiveMapType(themeName)

        -- Destroy any previously spawned monster
        if monsterMaid then
                monsterMaid:Destroy()
                monsterMaid = nil
        end

        -- Remove AI spawned by previous map (fallback)
        for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA("Model") and obj:GetAttribute("MonsterAI") then
                        obj:Destroy()
                end
        end

	-- Remove previous map container
	local oldMap = Workspace:FindFirstChild("GeneratedMap")
	if oldMap then oldMap:Destroy() end

	-- New container
	local mapContainer = Instance.new("Model")
	mapContainer.Name = "GeneratedMap"
	mapContainer.Parent = Workspace

	-- Resolve theme profile
	local config = MapConfig[themeName]
	if not config then
		warn("Theme profile not found: ", themeName)
		return nil
	end

	-- Per-floor seed (priority: param > config.generation.seed > os.time())
	local floorSeed = seed
		or (config.generation and config.generation.seed)
		or os.time()
	mapContainer:SetAttribute("Seed", floorSeed)

	-- Store seed in GameState (if supported)
	if typeof(GameStateManager.SetFloorSeed) == "function" then
		pcall(GameStateManager.SetFloorSeed, floorSeed)
	end

        local rng = Random.new(floorSeed)

        local function spawnMonster(mapLayout, config)
                local monsterTemplates = ReplicatedStorage:FindFirstChild("MonsterTemplates")
                if not monsterTemplates then
                        warn("[MonsterAI] MonsterTemplates folder not found in ReplicatedStorage.")
                        return
                end

                -- collect valid pieces (exclude Rooms and the first piece)
                local validPieces = {}
                for _, piece in ipairs(mapLayout) do
                        if piece.type ~= "Room" then
                                table.insert(validPieces, piece)
                        end
                end
                if #mapLayout > 0 then
                        local firstPiece = mapLayout[1]
                        for i = #validPieces, 1, -1 do
                                if validPieces[i] == firstPiece then
                                        table.remove(validPieces, i)
                                end
                        end
                end

                if #validPieces == 0 then
                        warn("[MonsterAI] No valid piece found to spawn monster (not Room, not initial).")
                        return
                end

                local chosenPiece = validPieces[randIndex(rng, #validPieces)]
                local sizeInCells = Vector2.new(3, 3)

                -- Find floor Y (if the piece model has a part named "Floor"/"Suelo")
                local baseY = 0
                if chosenPiece.model and chosenPiece.model:IsA("Model") then
                        for _, part in ipairs(chosenPiece.model:GetDescendants()) do
                                if part:IsA("BasePart") then
                                        local lname = part.Name:lower()
                                        if lname:find("floor") or lname:find("suelo") then
                                                baseY = part.Position.Y + (part.Size.Y / 2)
                                                break
                                        end
                                end
                        end
                end
                if baseY == 0 then
                        baseY = config.construction.ALTURA_PISO or 1
                end

                local spawnPos = Vector3.new(
                        ((chosenPiece.pos.c - 1) * sizeInCells.X + (sizeInCells.X / 2)) * config.construction.CELL_SIZE,
                        baseY + 3,
                        ((chosenPiece.pos.r - 1) * sizeInCells.Y + (sizeInCells.Y / 2)) * config.construction.CELL_SIZE
                )
                local monsterTemplate = monsterTemplates:FindFirstChild("HallwayMonster")
                        or monsterTemplates:FindFirstChildOfClass("Model")
                if not monsterTemplate then
                        warn("[MonsterAI] No template under ReplicatedStorage/MonsterTemplates.")
                        return
                end

                local monster = monsterTemplate:Clone()
                monster.Name = ("Monster_%d"):format(rng:NextInteger(1000, 9999))
                if not monster:GetAttribute("MonsterType") then
                        monster:SetAttribute("MonsterType", "Hallway")
                end
                monster:SetAttribute("MonsterAI", true)

                local root = monster:FindFirstChild("HumanoidRootPart")
                        or monster.PrimaryPart
                        or monster:FindFirstChildWhichIsA("BasePart")
                if not root then
                        warn("[MonsterAI] No HumanoidRootPart/PrimaryPart found in monster template.")
                        monster:Destroy()
                        return
                end

                monster.Parent = Workspace
                monster:SetPrimaryPartCFrame(CFrame.new(spawnPos + Vector3.new(0, 5, 0)))
                print(("[MonsterAI] Spawned %s @ %s"):format(monster.Name, tostring(spawnPos)))

                if Utils and Utils.maid then
                        monsterMaid = Utils:maid(true)
                        monsterMaid:GiveInstance(monster)
                end
        end

        -- Optionally (data-driven) register objectives for this floor via Utils facade
        do
                local objectivesDef = config.generation and config.generation.objectives
                if Utils and Utils.objectives and objectivesDef then
                        local ObjectiveManager = Utils:objectives()
			if ObjectiveManager then
				if ObjectiveManager.reset then
					pcall(function() ObjectiveManager:reset() end)
				end
				for _, def in ipairs(objectivesDef) do
					-- def: {name=string, required=number}
					pcall(function()
						ObjectiveManager:add({ name = def.name, required = def.required })
					end)
				end
			end
		end
	end

	local startPosition: Vector3?

	-- === Infinite generation path ===
	if config.generation.type == "Infinite" then
		print(("Infinite map detected ('%s'). StreamingManager will handle generation."):format(themeName))

		startPosition = Vector3.new(
			(config.generation.CHUNK_SIZE * config.construction.CELL_SIZE) / 2,
			config.construction.WALL_HEIGHT / 2,
			(config.generation.CHUNK_SIZE * config.construction.CELL_SIZE) / 2
		)

		-- Note: seed is exposed via mapContainer attribute and (optionally) GameStateManager;
		-- your StreamingManager should read config.generation.seed or GameState to seed chunks.

		return startPosition
	end

	-- === Finite generation path ===
	print("Generating finite map of type:", themeName)

	if config.generation.type == "Noise" then
		-- Simple/legacy noise branch (kept as-is)
		local CHUNK_SIZE = 16
		local CELL_SIZE = config.construction.CELL_SIZE
		startPosition = Vector3.new((CHUNK_SIZE / 2) * CELL_SIZE, 20, (CHUNK_SIZE / 2) * CELL_SIZE)
	else
		-- Preferred finite layout path
		-- Try to pass rng (new signature). If MapGenerator doesn't accept it, retry without it.
		local mapLayout, grid, pieceIdMap

		local ok = pcall(function()
			mapLayout, grid, pieceIdMap =
				MapGenerator.generateLayout({ rows = 20, cols = 20, maxPieces = 40 }, config, rng)
		end)
		if (not ok) or (type(mapLayout) ~= "table") then
			-- Fallback to old signature
			mapLayout, grid, pieceIdMap =
				MapGenerator.generateLayout({ rows = 20, cols = 20, maxPieces = 40 }, config)
		end

		if not mapLayout or #mapLayout == 0 then
			warn("The generator could not create any parts.")
			return nil
		end

		-- Build all pieces
		for _, recipe in ipairs(mapLayout) do
			local sizeInCells = Vector2.new(3, 3)
			local worldPos = Vector3.new(
				((recipe.pos.c - 1) * sizeInCells.X + (sizeInCells.X / 2)) * config.construction.CELL_SIZE,
				0,
				((recipe.pos.r - 1) * sizeInCells.Y + (sizeInCells.Y / 2)) * config.construction.CELL_SIZE
			)

			-- Doors with neighbor info (true if exterior)
			local doorsWithNeighborInfo = {}
			for dir, hasDoor in pairs(recipe.doors) do
				if hasDoor then
					local neighborPos = { r = recipe.pos.r + NEIGH[dir].r, c = recipe.pos.c + NEIGH[dir].c }
					if grid[neighborPos.r]
						and grid[neighborPos.r][neighborPos.c]
						and grid[neighborPos.r][neighborPos.c].isOccupied
					then
						local neighborPiece = pieceIdMap[grid[neighborPos.r][neighborPos.c].pieceId]
						if neighborPiece then doorsWithNeighborInfo[dir] = neighborPiece.type end
					else
						doorsWithNeighborInfo[dir] = true
					end
				end
			end

			local factoryRecipe = {
				cframe = CFrame.new(worldPos),
				type = recipe.type,
				doors = doorsWithNeighborInfo,
				pos = recipe.pos,
				id = recipe.id,
				template = recipe.template,
				sizeInCells = sizeInCells,
				fullGrid = grid,
				allPiecesMap = pieceIdMap,
			}
			local pieceModel = Helpers.createPiece(mapContainer, factoryRecipe, config.construction)
			Helpers.createCeilingLight(pieceModel, factoryRecipe.cframe, config.construction)

			-- Persist a back-reference so we can find floors when spawning AI
			recipe.model = pieceModel
		end

                -- Seeded monster spawn (single pass). Choose any non-Room piece except the very first.
                spawnMonster(mapLayout, config)

		-- Player start position = center of first piece
		if #mapLayout > 0 then
			local firstPiece = mapLayout[1]
			local sizeInCells = Vector2.new(3, 3)
			startPosition = Vector3.new(
				((firstPiece.pos.c - 1) * sizeInCells.X + (sizeInCells.X / 2)) * config.construction.CELL_SIZE,
				10,
				((firstPiece.pos.r - 1) * sizeInCells.Y + (sizeInCells.Y / 2)) * config.construction.CELL_SIZE
			)
		end
	end

	print("Map generated with the profile:", themeName)
	return startPosition
end

return MapBuilder
