-- ModuleScript: MapBuilder
-- FINAL VERSION: Automatically detects infinite maps and preserves finite generators.

local MapBuilder = {}

local Workspace = game:GetService("Workspace")
local GameStateManager = require(script.Parent:WaitForChild("GameStateManager"))
local MapConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("MapConfig"))
local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("combinedFunctions"):WaitForChild("Maid"))

local activeMaid

-- References for your other (finite map) generators
local MapGenerator = require(script.Parent:WaitForChild("MapGenerator"))
local Helpers = require(script.Parent:WaitForChild("MapBuilderHelpers"))
local NEIGH = {N = {r = -1, c =  0}, S = {r =  1, c =  0}, E = {r =  0, c =  1}, W = {r =  0, c = -1}}

function MapBuilder.Generate(themeName)
	GameStateManager.SetActiveMapType(themeName)

	if activeMaid then
		activeMaid:Destroy()
	end
	local maid = Maid.new()
	activeMaid = maid

	local function track(instance)
		local bind = Instance.new("BindableEvent")
		local task = maid:GiveTask(nil, bind.Event, function() end)
		function task:EndTask()
			if instance.Destroy then
				instance:Destroy()
			end
			bind:Destroy()
		end
	end

	local mapContainer = Instance.new("Model", Workspace)
	mapContainer.Name = "GeneratedMap"
	track(mapContainer)

	local startPosition
	local config = MapConfig[themeName]

	if not config then
		warn("Theme profile not found: ", themeName)
		return nil
	end

	-- Check if the generation type is "Infinite"
	if config.generation.type == "Infinite" then
		print("Infinite map type detected ('" .. themeName .. "'). The StreamingManager will handle generation.")

		startPosition = Vector3.new(
			(config.generation.CHUNK_SIZE * config.construction.CELL_SIZE) / 2,
			config.construction.WALL_HEIGHT / 2,
			(config.generation.CHUNK_SIZE * config.construction.CELL_SIZE) / 2
		)
	else
		-- Your logic for FINITE maps (templates, noise, etc.)
		print("Generating finite map of type:", themeName)

		if config.generation.type == "Noise" then
			local CHUNK_SIZE = 16
			local CELL_SIZE = config.construction.CELL_SIZE
			startPosition = Vector3.new((CHUNK_SIZE / 2) * CELL_SIZE, 20, (CHUNK_SIZE / 2) * CELL_SIZE)
		else
			local mapLayout, grid, pieceIdMap = MapGenerator.generateLayout({rows=20,cols=20,maxPieces=40}, config)
			if #mapLayout == 0 then
				warn("The generator could not create any parts.")
				return nil
			end
			for _, recipe in ipairs(mapLayout) do
				local sizeInCells = Vector2.new(3, 3)
				local worldPos = Vector3.new(
					((recipe.pos.c - 1) * sizeInCells.X + (sizeInCells.X / 2)) * config.construction.CELL_SIZE,
					0,
					((recipe.pos.r - 1) * sizeInCells.Y + (sizeInCells.Y / 2)) * config.construction.CELL_SIZE
				)
				local doorsWithNeighborInfo = {}
				for dir, hasDoor in pairs(recipe.doors) do
					if hasDoor then
						local neighborPos = {r = recipe.pos.r + NEIGH[dir].r, c = recipe.pos.c + NEIGH[dir].c}
						if grid[neighborPos.r] and grid[neighborPos.r][neighborPos.c] and grid[neighborPos.r][neighborPos.c].isOccupied then
							local neighborPiece = pieceIdMap[grid[neighborPos.r][neighborPos.c].pieceId]
							if neighborPiece then doorsWithNeighborInfo[dir] = neighborPiece.type end
						else
							doorsWithNeighborInfo[dir] = true
						end
					end
				end
				local factoryRecipe = {cframe = CFrame.new(worldPos), type = recipe.type, doors = doorsWithNeighborInfo, pos = recipe.pos, id = recipe.id, template = recipe.template, sizeInCells = sizeInCells, fullGrid = grid, allPiecesMap = pieceIdMap}
				local pieceModel = Helpers.createPiece(mapContainer, factoryRecipe, config.construction)
				Helpers.createCeilingLight(pieceModel, factoryRecipe.cframe, config.construction)
			end

			-- === MONSTER SPAWN LOGIC (now inside the block where mapLayout exists) ===
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local monsterTemplates = ReplicatedStorage:FindFirstChild("MonsterTemplates")
			if monsterTemplates and mapLayout and #mapLayout > 0 then
				-- Filters out non-Room and non-initial pieces
				local validPieces = {}
				for i, piece in ipairs(mapLayout) do
					if piece.type ~= "Room" then
						table.insert(validPieces, piece)
					end
				end
				-- Remove the starting piece if it is in the list
				if #mapLayout > 0 then
					local firstPiece = mapLayout[1]
					for i = #validPieces, 1, -1 do
						if validPieces[i] == firstPiece then
							table.remove(validPieces, i)
						end
					end
				end
				if #validPieces > 0 then
					local chosenPiece = validPieces[math.random(1, #validPieces)]
					local sizeInCells = Vector2.new(3, 3)
					-- Calculate the XZ position the same, but the Y takes from the piece's floor
					local baseY = 0
					-- Look for the piece's floor (Part named "Floor" or similar)
					if chosenPiece.model and chosenPiece.model:IsA("Model") then
						for _, part in ipairs(chosenPiece.model:GetDescendants()) do
							if part:IsA("BasePart") and (part.Name:lower():find("floor") or part.Name:lower():find("suelo")) then
								baseY = part.Position.Y + (part.Size.Y / 2)
								break
							end
						end
					end
					-- If not found, use a default value
					if baseY == 0 then
						baseY = config.construction.ALTURA_PISO or 1
					end
					-- Adjust the height so that the monster is not inside the floor
					local monsterHeightOffset = 3
					local spawnPos = Vector3.new(
						((chosenPiece.pos.c - 1) * sizeInCells.X + (sizeInCells.X / 2)) * config.construction.CELL_SIZE,
						baseY + monsterHeightOffset,
						((chosenPiece.pos.r - 1) * sizeInCells.Y + (sizeInCells.Y / 2)) * config.construction.CELL_SIZE
					)
					local monsterTemplate = monsterTemplates:FindFirstChild("HallwayMonster") or monsterTemplates:FindFirstChildOfClass("Model")
					if monsterTemplate then
						local monster = monsterTemplate:Clone()
						monster.Name = "Monster_" .. math.random(1000,9999)
						if not monster:GetAttribute("MonsterType") then
							monster:SetAttribute("MonsterType", "Hallway")
						end
						-- Mark this monster as spawned by the map
						monster:SetAttribute("MonsterAI", true)
						local root = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart or monster:FindFirstChildWhichIsA("BasePart")
						if root then
						monster.Parent = Workspace
						monster:SetPrimaryPartCFrame(CFrame.new(spawnPos + Vector3.new(0, 5, 0)))
						track(monster)
						else
						warn("[MonsterAI] No HumanoidRootPart or PrimaryPart found in monster template.")
						end
						print("[MonsterAI] Spawned monster: " .. monster.Name .. " at " .. tostring(spawnPos))
					else
						warn("[MonsterAI] No monster template found in ReplicatedStorage/MonsterTemplates.")
					end
				else
					warn("[MonsterAI] No valid piece found to spawn monster (not Room, not initial).")
				end
			elseif not monsterTemplates then
				warn("[MonsterAI] MonsterTemplates folder not found in ReplicatedStorage.")
			end

			if #mapLayout > 0 then
				local firstPiece = mapLayout[1]
				local sizeInCells = Vector2.new(3, 3)
				startPosition = Vector3.new(((firstPiece.pos.c - 1) * sizeInCells.X + (sizeInCells.X / 2)) * config.construction.CELL_SIZE, 10, ((firstPiece.pos.r - 1) * sizeInCells.Y + (sizeInCells.Y / 2)) * config.construction.CELL_SIZE)
			end
		end
	end

	print("Map generated with the profile:", themeName)


	-- === MONSTER SPAWN LOGIC ===
	-- Runs after all parts and lights have been created
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local monsterTemplates = ReplicatedStorage:FindFirstChild("MonsterTemplates")
	if monsterTemplates and mapLayout and #mapLayout > 0 then
		-- Filters out non-Room and non-initial pieces
		local validPieces = {}
		for i, piece in ipairs(mapLayout) do
			if piece.type ~= "Room" then
				table.insert(validPieces, piece)
			end
		end
		-- Remove the starting piece if it is in the list
		if #mapLayout > 0 then
			local firstPiece = mapLayout[1]
			for i = #validPieces, 1, -1 do
				if validPieces[i] == firstPiece then
					table.remove(validPieces, i)
				end
			end
		end
		if #validPieces > 0 then
			local chosenPiece = validPieces[math.random(1, #validPieces)]
			local sizeInCells = Vector2.new(3, 3)
			local spawnPos = Vector3.new(
				((chosenPiece.pos.c - 1) * sizeInCells.X + (sizeInCells.X / 2)) * config.construction.CELL_SIZE,
				10,
				((chosenPiece.pos.r - 1) * sizeInCells.Y + (sizeInCells.Y / 2)) * config.construction.CELL_SIZE
			)
			local monsterTemplate = monsterTemplates:FindFirstChild("HallwayMonster") or monsterTemplates:FindFirstChildOfClass("Model")
			if monsterTemplate then
				local monster = monsterTemplate:Clone()
				monster.Name = "Monster_" .. math.random(1000,9999)
				if not monster:GetAttribute("MonsterType") then
					monster:SetAttribute("MonsterType", "Hallway")
				end
				local root = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart or monster:FindFirstChildWhichIsA("BasePart")
				if root then
					monster.Parent = Workspace
					monster:SetPrimaryPartCFrame(CFrame.new(spawnPos + Vector3.new(0, 5, 0)))
					track(monster)
				else
					warn("[MonsterAI] No HumanoidRootPart or PrimaryPart found in monster template.")
				end
				print("[MonsterAI] Spawned monster: " .. monster.Name .. " at " .. tostring(spawnPos))
			else
				warn("[MonsterAI] No monster template found in ReplicatedStorage/MonsterTemplates.")
			end
		else
			warn("[MonsterAI] No valid piece found to spawn monster (not Room, not initial).")
		end
	elseif not monsterTemplates then
		warn("[MonsterAI] MonsterTemplates folder not found in ReplicatedStorage.")
	end

	return startPosition
end

return MapBuilder
