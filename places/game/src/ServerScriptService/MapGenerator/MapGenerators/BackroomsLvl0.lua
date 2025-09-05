-- ModuleScript: BackroomsLvl0
-- VERSION: Seeded chunks + exit door gated by objectives
--[[
  Purpose
  -------
  - Build chunk geometry (floor, roof, merged walls).
  - Use a deterministic RNG per chunk based on a floor seed + (x,y,z).
  - Try placing an exit door by replacing/offsetting a wall, but ONLY when
    all objectives are completed (if ObjectiveManager is available).

  Signature
  ---------
    BackroomsLvl0.GenerateChunk(chunkX, chunkY, chunkZ, config, mapContainer, seed?)

  Notes
  -----
  - `seed` comes from StreamingManager; if nil, we fall back to an internal hash.
  - Door "TargetLevel" can be customized at the door model via Attribute if your
    LevelFeatureFactory sets it, otherwise ExitDoorInteraction has a default.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--==============================================================
--=                        MODULE REFS                         =
--==============================================================
local LevelFeatureFactoryModule = ServerScriptService:FindFirstChild("LevelFeatureFactory", true)
local exitDoorInteractionScript = ReplicatedStorage:FindFirstChild("ExitDoorInteraction")

if not LevelFeatureFactoryModule then warn("BackroomsLvl0: LevelFeatureFactory not found.") end
if not exitDoorInteractionScript then warn("BackroomsLvl0: ExitDoorInteraction not found in ReplicatedStorage.") end

local LevelFeatureFactory = LevelFeatureFactoryModule and require(LevelFeatureFactoryModule)

-- Optional: Utils facade to read ObjectiveManager (gate the exit)
local Utils do
	local Modules = ReplicatedStorage:FindFirstChild("Modules")
	local cf = Modules and Modules:FindFirstChild("combinedFunctions")
	if cf then
		local ok, res = pcall(function()
			if cf:IsA("ModuleScript") then return require(cf) end
			local init = cf:FindFirstChild("Init") or cf:FindFirstChild("init")
			return init and require(init) or nil
		end)
		if ok then Utils = res end
	end
end

local ObjectiveManager = Utils and Utils.objectives and Utils:objectives() or nil

local BackroomsLvl0 = {}

--==============================================================
--=                   BUILDING HELPER FUNCTIONS                =
--==============================================================
local function key(x, z) return x .. "," .. z end

local function createWallPart(parent, size, cframe, face, textureId, cs, h)
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent

	if not textureId or textureId == "" then
		return part
	end

	local texture = Instance.new("Texture")
	texture.Face = face
	texture.Texture = "rbxassetid://" .. tostring(textureId)
	texture.StudsPerTileU = cs
	texture.StudsPerTileV = h
	texture.Parent = part

	-- mirror on opposite face (so both sides look good)
	local opposites = {
		[Enum.NormalId.Front] = Enum.NormalId.Back,
		[Enum.NormalId.Back]  = Enum.NormalId.Front,
		[Enum.NormalId.Left]  = Enum.NormalId.Right,
		[Enum.NormalId.Right] = Enum.NormalId.Left,
	}
	if opposites[face] then
		local texture2 = Instance.new("Texture")
		texture2.Face = opposites[face]
		texture2.Texture = texture.Texture
		texture2.StudsPerTileU = texture.StudsPerTileU
		texture2.StudsPerTileV = texture.StudsPerTileV
		texture2.Parent = part
	end

	return part
end

local function createDecaledPart(parent, size, cframe, face, decalId)
	local part = Instance.new("Part")
	part.Transparency = 1
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Parent = parent
	if decalId and decalId ~= "" then
		local decal = Instance.new("Decal")
		decal.Face = face
		decal.Texture = "rbxassetid://" .. tostring(decalId)
		decal.Parent = part
	end
	return part
end

-- merge contiguous wall segments along X or Z axis and return created Parts
local function mergeWalls(wallSegments, parent, h, cs, thickness, textureId, isZAxis)
	local createdWalls = {}
	local processed = {}

	for i, startSegment in ipairs(wallSegments) do
		if not processed[i] then
			processed[i] = true
			local mergeCount = 1
			local currentPos = startSegment

			for j = i + 1, #wallSegments do
				local nextSegment = wallSegments[j]
				local expectedNextPos
				if isZAxis then
					expectedNextPos = { x = currentPos.x, z = currentPos.z + 1 }
				else
					expectedNextPos = { x = currentPos.x + 1, z = currentPos.z }
				end
				if nextSegment.x == expectedNextPos.x and nextSegment.z == expectedNextPos.z then
					mergeCount += 1
					currentPos = nextSegment
					for k, seg in ipairs(wallSegments) do
						if seg.x == nextSegment.x and seg.z == nextSegment.z then
							processed[k] = true
							break
						end
					end
				end
			end

			local size, cframe, face
			if isZAxis then
				size = Vector3.new(thickness, h, cs * mergeCount)
				local centerOffset = Vector3.new(0, h / 2, (startSegment.z - 1 + mergeCount / 2) * cs)
				cframe = CFrame.new(startSegment.origin + centerOffset)
				face = Enum.NormalId.Right
			else
				size = Vector3.new(cs * mergeCount, h, thickness)
				local centerOffset = Vector3.new((startSegment.x - 1 + mergeCount / 2) * cs, h / 2, 0)
				cframe = CFrame.new(startSegment.origin + centerOffset)
				face = Enum.NormalId.Front
			end

			local wallPart = createWallPart(parent, size, cframe, face, textureId, cs, h)
			table.insert(createdWalls, wallPart)
		end
	end
	return createdWalls
end

--==============================================================
--=                        DOOR PLACEMENT                       =
--==============================================================

-- Decide if we are allowed to place an exit now (objectives gate)
local function canPlaceExit()
	if ObjectiveManager and ObjectiveManager.allDone then
		local ok, done = pcall(function() return ObjectiveManager:allDone() end)
		return ok and done == true
	end
	-- If no ObjectiveManager is present, allow placement
	return true
end

-- Pick a wall and place the exit door (if allowed)
local function tryPlaceDoor(walls, chunkRng, config, mapContainer)
	if not (LevelFeatureFactory and exitDoorInteractionScript) then return end
	if #walls == 0 then return end
	if not canPlaceExit() then return end

	-- optional: probability (if you want sparsity even after objectives)
	local PLACE_PROB = 1.0
	if chunkRng:NextNumber() > PLACE_PROB then return end

	-- 1) choose a wall
	local wallToReplace = walls[chunkRng:NextInteger(1, #walls)]
	local doorWidth = 8
	local wallSize = wallToReplace.Size
	if math.max(wallSize.X, wallSize.Z) < doorWidth + 2 then
		return
	end

	-- 2) compute door CF near the wall
	local wallCFrame = wallToReplace.CFrame
	local DOOR_OFFSET = 0
	local offsetDist
	local doorCFrame

	if wallSize.X < wallSize.Z then
		-- wall aligned along Z → move along +X and rotate door to face wall
		offsetDist = wallSize.X / 2 - DOOR_OFFSET
		doorCFrame = wallCFrame * CFrame.new(offsetDist, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	else
		-- wall aligned along X → move along +Z (default orientation)
		offsetDist = wallSize.Z / 2 - DOOR_OFFSET
		doorCFrame = wallCFrame * CFrame.new(0, 0, offsetDist)
	end

	-- 3) spawn the door model
	local h = config.construction.WALL_HEIGHT
	doorCFrame = doorCFrame * CFrame.new(0, -h/12, 0) -- small vertical tweak
	local doorModel = LevelFeatureFactory.createExitDoor_ToLevel1(config.construction)
	doorModel:SetAttribute("IsExitDoor", true)
	doorModel:SetPrimaryPartCFrame(doorCFrame)
	doorModel.Parent = mapContainer

	-- 4) attach interaction script
	local scriptClone = exitDoorInteractionScript:Clone()
	scriptClone.Parent = doorModel
end

--==============================================================
--=                    CHUNK GENERATION (MAIN)                  =
--==============================================================
local bit32 = bit32 -- luau global
local function mixSeed(base: number, x: number, y: number, z: number)
	-- deterministic 32-bit mix; stays within Random.new limits
	local h = base or 0
	h = bit32.bxor(h, x * 73856093)
	h = bit32.bxor(h, y * 19349663)
	h = bit32.bxor(h, z * 83492791)
	-- ensure positive int
	h = (h % 2147483647)
	if h == 0 then h = 1 end
	return h
end

function BackroomsLvl0.GenerateChunk(chunkX, chunkY, chunkZ, config, mapContainer, seed: number?) -- <- seed is optional
	-- 1) Grid + RNG setup (seeded)
	local conConfig = config.construction
	local genConfig = config.generation

	local CHUNK_SIZE = genConfig.CHUNK_SIZE or 16
	local cs, h = conConfig.CELL_SIZE, conConfig.WALL_HEIGHT
	local ids = conConfig.decals

	local chunkModel = Instance.new("Model")
	chunkModel.Name = key(chunkX, chunkZ) -- keep your original name format
	chunkModel.Parent = mapContainer

	-- Seeded RNGs (stable across players)
	local baseSeed = tonumber(seed) or 0
	local chunkSeed   = mixSeed(baseSeed, chunkX, chunkY, chunkZ)
	local borderSeed  = mixSeed(baseSeed, chunkX + 123, chunkY, chunkZ + 456)

	local chunkRng  = Random.new(chunkSeed)
	local borderRng = Random.new(borderSeed)

	-- Initialize grid
	local grid = {}
	for x = 1, CHUNK_SIZE do
		grid[x] = {}
		for z = 1, CHUNK_SIZE do
			grid[x][z] = { connections = {} }
		end
	end

	-- Randomly open borders to connect with neighbor chunks
	for i = 1, CHUNK_SIZE do
		if borderRng:NextNumber() < 0.2 then grid[i][1].connections[key(i, 0)] = true end
		if borderRng:NextNumber() < 0.2 then grid[i][CHUNK_SIZE].connections[key(i, CHUNK_SIZE + 1)] = true end
		if borderRng:NextNumber() < 0.2 then grid[1][i].connections[key(0, i)] = true end
		if borderRng:NextNumber() < 0.2 then grid[CHUNK_SIZE][i].connections[key(CHUNK_SIZE + 1, i)] = true end
	end

	-- DFS carve
	local stack = { { x = chunkRng:NextInteger(1, CHUNK_SIZE), z = chunkRng:NextInteger(1, CHUNK_SIZE) } }
	local visited = { [key(stack[1].x, stack[1].z)] = true }

	while #stack > 0 do
		local current = stack[#stack]
		local x, z = current.x, current.z

		local neighbors = {}
		for _, dir in ipairs({ {0,1}, {0,-1}, {1,0}, {-1,0} }) do
			local nx, nz = x + dir[1], z + dir[2]
			if nx>=1 and nx<=CHUNK_SIZE and nz>=1 and nz<=CHUNK_SIZE and not visited[key(nx, nz)] then
				table.insert(neighbors, { x = nx, z = nz })
			end
		end

		if #neighbors > 0 then
			local pick = neighbors[chunkRng:NextInteger(1, #neighbors)]
			grid[x][z].connections[key(pick.x, pick.z)] = true
			grid[pick.x][pick.z].connections[key(x, z)] = true
			visited[key(pick.x, pick.z)] = true
			table.insert(stack, pick)
		else
			table.remove(stack)
		end
	end

	-- Optional room
	if chunkRng:NextNumber() < 0.25 then
		local roomSize = 2
		local rx = chunkRng:NextInteger(1, CHUNK_SIZE - roomSize)
		local rz = chunkRng:NextInteger(1, CHUNK_SIZE - roomSize)
		for x = rx, rx + roomSize - 1 do
			for z = rz, rz + roomSize - 1 do
				if x + 1 < rx + roomSize then
					grid[x][z].connections[key(x + 1, z)] = true
					grid[x + 1][z].connections[key(x, z)] = true
				end
				if z + 1 < rz + roomSize then
					grid[x][z].connections[key(x, z + 1)] = true
					grid[x][z + 1].connections[key(x, z)] = true
				end
			end
		end
	end

	-- 2) Geometry bookkeeping
	local wallsToMergeX = {}
	local wallsToMergeZ = {}
	local chunkOrigin = Vector3.new(chunkX * CHUNK_SIZE * cs, chunkY * h, chunkZ * CHUNK_SIZE * cs)

	for x = 1, CHUNK_SIZE do
		for z = 1, CHUNK_SIZE do
			local cellOrigin = chunkOrigin + Vector3.new((x - 1) * cs, 0, (z - 1) * cs)

			createDecaledPart(chunkModel, Vector3.new(cs, 1, cs), CFrame.new(cellOrigin + Vector3.new(cs/2, 0, cs/2)), Enum.NormalId.Top, ids.floor)
			createDecaledPart(chunkModel, Vector3.new(cs, 1, cs), CFrame.new(cellOrigin + Vector3.new(cs/2, h, cs/2)), Enum.NormalId.Bottom, ids.roof)

			if not grid[x][z].connections[key(x - 1, z)] then
				table.insert(wallsToMergeZ, { x = x, z = z, origin = cellOrigin })
			end
			if not grid[x][z].connections[key(x, z - 1)] then
				table.insert(wallsToMergeX, { x = x, z = z, origin = cellOrigin })
			end
		end
	end

	-- 3) Build merged walls
	table.sort(wallsToMergeX, function(a, b) return a.z < b.z or (a.z == b.z and a.x < b.x) end)
	table.sort(wallsToMergeZ, function(a, b) return a.x < b.x or (a.x == b.x and a.z < b.z) end)
	local WALL_THICKNESS = 1

	local createdWallsX = mergeWalls(wallsToMergeX, chunkModel, h, cs, WALL_THICKNESS, ids.wall, false)
	local createdWallsZ = mergeWalls(wallsToMergeZ, chunkModel, h, cs, WALL_THICKNESS, ids.wall, true)

	-- 4) Try placing exit door (gated by objectives)
	local allCreatedWalls = {}
	for _, w in ipairs(createdWallsX) do table.insert(allCreatedWalls, w) end
	for _, w in ipairs(createdWallsZ) do table.insert(allCreatedWalls, w) end

	tryPlaceDoor(allCreatedWalls, chunkRng, config, chunkModel)

	return chunkModel
end

return BackroomsLvl0
