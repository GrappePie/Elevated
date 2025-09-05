-- ModuleScript: BackroomsLvl1
-- VERSION: Seeded chunks + optional exit door (gated by objectives)

--[[
  Purpose
  -------
  - Build a parking-garage style chunk (floor, pillars, walls, lights).
  - Deterministic RNG per chunk using a floor seed + (x,y,z).
  - Optionally place an exit door on a perimeter wall *only when objectives are done*.

  Signature
  ---------
    M.GenerateChunk(chunkX, chunkY, chunkZ, config, mapContainer, seed?)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LevelFeatureFactoryModule = ServerScriptService:FindFirstChild("LevelFeatureFactory", true)
local exitDoorInteractionScript = ReplicatedStorage:FindFirstChild("ExitDoorInteraction")
if not LevelFeatureFactoryModule then warn("BackroomsLvl1: LevelFeatureFactory not found.") end
if not exitDoorInteractionScript then warn("BackroomsLvl1: ExitDoorInteraction not found in ReplicatedStorage.") end
local LevelFeatureFactory = LevelFeatureFactoryModule and require(LevelFeatureFactoryModule)

-- Optional Utils facade for Objective gating
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

local M = {} -- <<< alias neutro para evitar “attempt to index nil with 'GenerateChunk'”

-- ----------------- helpers -----------------
local function key(...) return table.concat({...}, ",") end

local function createPlate(parent, pos, size, thickness, material, color)
	local plate = Instance.new("Part")
	plate.Anchored = true
	plate.Size = Vector3.new(size.X, thickness, size.Z)
	plate.CFrame = CFrame.new(pos + Vector3.new(size.X/2, thickness/2, size.Z/2))
	plate.Material = material
	if color then plate.BrickColor = BrickColor.new(color) end
	plate.Parent = parent
	return plate
end

local function createParkingLine(parent, startPos, endPos)
	local dirVec = endPos - startPos
	local totalLen = dirVec.Magnitude
	if totalLen <= 0 then return end
	local dir = dirVec.Unit
	local sizeX = math.abs(dir.Z) > 0.5 and 1.0 or totalLen
	local sizeZ = math.abs(dir.X) > 0.5 and 1.0 or totalLen
	local line = Instance.new("Part")
	line.Anchored = true
	local height = 0.1
	line.Size = Vector3.new(sizeX, height, sizeZ)
	local liftY = 1 + height/2
	local center = (startPos + endPos) / 2 + Vector3.new(0, liftY, 0)
	line.CFrame = CFrame.new(center)
	line.Material = Enum.Material.SmoothPlastic
	line.BrickColor = BrickColor.new("Institutional white")
	line.Reflectance = 0
	line.Parent = parent
	return line
end

local function createColumn(parent, pos, halfWidth, height)
	local col = Instance.new("Part")
	col.Size = Vector3.new(halfWidth*2, height, halfWidth*2)
	col.CFrame = CFrame.new(pos + Vector3.new(0, height/2, 0))
	col.Anchored = true
	col.Material = Enum.Material.Concrete
	col.BrickColor = BrickColor.new("Dark stone grey")
	col.Parent = parent
	return col
end

local function createLightFixture(parent, pos)
	local light = Instance.new("Part")
	light.Size = Vector3.new(1, 0.2, 1)
	light.CFrame = CFrame.new(pos)
	light.Anchored = true
	light.Material = Enum.Material.Plastic
	light.BrickColor = BrickColor.new("Institutional white")
	light.Parent = parent
	local f = Instance.new("PointLight", light)
	f.Range = 15; f.Brightness = 2
	return light
end

local function createDecaledPart(parent,size,cframe,face,decalId)
	local p=Instance.new("Part")
	p.Size,p.CFrame,p.Anchored=size,cframe,true
	p.Parent = parent
	if decalId and decalId~="" then
		local d=Instance.new("Decal",p)
		d.Face,d.Texture=face,"rbxassetid://"..decalId
	end
	return p
end

local function createWall(parent,size,cframe,decalId)
	local w=Instance.new("Part")
	w.Size,w.CFrame,w.Anchored=size,cframe,true
	w.Parent = parent
	if decalId and decalId~="" then
		for _,f in ipairs({Enum.NormalId.Front,Enum.NormalId.Back,Enum.NormalId.Left,Enum.NormalId.Right}) do
			local d=Instance.new("Decal",w)
			d.Face,d.Texture=f,"rbxassetid://"..decalId
		end
	end
	return w
end

local function createSupplyCrate(parent, pos, size)
	local crate = Instance.new("Part")
	crate.Size = Vector3.new(size, size, size)
	crate.CFrame = CFrame.new(pos + Vector3.new(size/2, size/2, size/2))
	crate.Anchored = true
	crate.Material = Enum.Material.WoodPlanks
	crate.Parent = parent
	return crate
end

local function createWaterPuddle(parent, pos, size)
	local p = Instance.new("Part")
	p.Size = Vector3.new(size, 0.2, size)
	p.CFrame = CFrame.new(pos + Vector3.new(size/2, 0.05, size/2))
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.new(0.1, 0.15, 0.2)
	p.Transparency = 0.2
	p.Reflectance = 0.3
	p.Parent = parent
	return p
end

local function createCeilingPanel(parent, pos, size, height)
	local panel = Instance.new("Part")
	panel.Size = Vector3.new(size, 0.2, size)
	panel.CFrame = CFrame.new(pos + Vector3.new(size/2, height + 0.1, size/2))
	panel.Anchored = true
	panel.Material = Enum.Material.SmoothPlastic
	panel.BrickColor = BrickColor.new("Institutional white")
	panel.Parent = parent
	return panel
end

local function createParkingSlotDetector(parent, pos, size)
	local detector = Instance.new("Part")
	detector.Size = size
	detector.CFrame = CFrame.new(pos)
	detector.Anchored = true
	detector.CanCollide = false
	detector.Transparency = 1
	detector.Name = "ParkingSlotDetector"
	detector.Parent = parent
	detector.Touched:Connect(function() end)
	detector.TouchEnded:Connect(function() end)
	return detector
end

-- deterministic 32-bit mix based on base seed and coordinates
local bit32 = bit32
local function mixSeed(base: number, x: number, y: number, z: number)
	local h = base or 0
	h = bit32.bxor(h, x * 73856093)
	h = bit32.bxor(h, y * 19349663)
	h = bit32.bxor(h, z * 83492791)
	h = (h % 2147483647); if h == 0 then h = 1 end
	return h
end

-- objectives gate
local function canPlaceExit()
	if ObjectiveManager and ObjectiveManager.allDone then
		local ok, done = pcall(function() return ObjectiveManager:allDone() end)
		return ok and done == true
	end
	return true
end

-- place an exit door on a perimeter wall if allowed
local function placeExitDoorOnPerimeter(perimeterWalls: {BasePart}, rng: Random, config, mapContainer)
	if not (LevelFeatureFactory and exitDoorInteractionScript) then return end
	if not canPlaceExit() then return end
	if #perimeterWalls == 0 then return end

	local wall = perimeterWalls[rng:NextInteger(1, #perimeterWalls)]
	local wallSize = wall.Size

	-- Compute a CF a bit off the wall, oriented to face the interior
	local DOOR_OFFSET = 0
	local doorCFrame
	if wallSize.X > wallSize.Z then
		doorCFrame = wall.CFrame * CFrame.new(0, 0, wallSize.Z/2 - DOOR_OFFSET)
	else
		doorCFrame = wall.CFrame * CFrame.new(wallSize.X/2 - DOOR_OFFSET, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	end
	doorCFrame = doorCFrame * CFrame.new(0, -(config.construction.WALL_HEIGHT)/12, 0)

	local createFn = LevelFeatureFactory.createExitDoor or LevelFeatureFactory.createExitDoor_ToLevel1
	if not createFn then return end

	local doorModel = createFn(config.construction)
	doorModel:SetAttribute("IsExitDoor", true)
	local nextLevel = (config.generation and config.generation.nextLevel) or "Backrooms (level 2)"
	doorModel:SetAttribute("TargetLevel", nextLevel)

	doorModel:SetPrimaryPartCFrame(doorCFrame)
	doorModel.Parent = mapContainer

	local scriptClone = exitDoorInteractionScript:Clone()
	scriptClone.Parent = doorModel
end

-- ----------------- main -----------------
function M.GenerateChunk(chunkX, chunkY, chunkZ, config, mapContainer, seed: number?)
	local conConfig, genConfig = config.construction, config.generation
	local CHUNK_SIZE, cs, h = genConfig.CHUNK_SIZE, conConfig.CELL_SIZE, conConfig.WALL_HEIGHT

	-- Seeded RNGs
	local baseSeed = tonumber(seed) or 0
	local zoneSeed = mixSeed(baseSeed, chunkX, chunkY, chunkZ)
	local rng = Random.new(zoneSeed)

	-- Area classification (parking or plain) — deterministic 30%
	local isParkingZone = (rng:NextNumber() < 0.3)
	local zoneHeight = isParkingZone and (h * 1.8) or h
	local ids = conConfig.decals

	local chunkModel = Instance.new("Model")
	chunkModel.Name = key(chunkX, chunkY, chunkZ)
	chunkModel.Parent = mapContainer

	local origin = Vector3.new(chunkX*CHUNK_SIZE*cs, chunkY*h, chunkZ*CHUNK_SIZE*cs)
	local totalSize = Vector3.new(CHUNK_SIZE*cs, 0, CHUNK_SIZE*cs)

	-- Floor
	createPlate(chunkModel, origin, totalSize, 1, Enum.Material.Concrete, "Medium stone grey")

	-- Parking lanes between pillars (3 per cell)
	local PILLAR_GRID_SPACING = 100
	local slotsPerCell = 3
	local slotWidth = PILLAR_GRID_SPACING / slotsPerCell
	local slotDepth = totalSize.Z * 0.2
	local depthOffset = (totalSize.Z - slotDepth) / 2

	-- Pillar grid positions (aligned globally)
	local function roundToGrid(val, spacing) return math.floor(val / spacing + 0.5) * spacing end
	local pillarXs = {}
	for xP = roundToGrid(origin.X, PILLAR_GRID_SPACING), origin.X + CHUNK_SIZE * cs, PILLAR_GRID_SPACING do
		table.insert(pillarXs, xP)
	end
	local pillarZs = {}
	for zP = roundToGrid(origin.Z, PILLAR_GRID_SPACING), origin.Z + CHUNK_SIZE * cs, PILLAR_GRID_SPACING do
		table.insert(pillarZs, zP)
	end

	-- Draw parking lines and detectors
	for zi = 1, #pillarZs do
		local frontZrow = pillarZs[zi] + depthOffset
		local backZrow  = pillarZs[zi] + depthOffset + slotDepth
		for xi = 1, #pillarXs - 1 do
			local gridStartX = pillarXs[xi]
			createParkingLine(chunkModel, Vector3.new(gridStartX, 0, frontZrow), Vector3.new(gridStartX + PILLAR_GRID_SPACING, 0, frontZrow))
			createParkingLine(chunkModel, Vector3.new(gridStartX, 0, backZrow),  Vector3.new(gridStartX + PILLAR_GRID_SPACING, 0, backZrow))
			createParkingLine(chunkModel, Vector3.new(gridStartX, 0, frontZrow), Vector3.new(gridStartX, 0, backZrow))
			createParkingLine(chunkModel, Vector3.new(gridStartX + PILLAR_GRID_SPACING, 0, frontZrow), Vector3.new(gridStartX + PILLAR_GRID_SPACING, 0, backZrow))

			for j = 0, slotsPerCell - 1 do
				local slotStartX = gridStartX + j * slotWidth
				local detectorHeight = zoneHeight - 2
				local detectorPos = Vector3.new(slotStartX + slotWidth/2, origin.Y + 1 + detectorHeight/2, frontZrow + slotDepth/2)
				local detectorSize = Vector3.new(slotWidth, detectorHeight, slotDepth)
				createParkingSlotDetector(chunkModel, detectorPos, detectorSize)

				if j < slotsPerCell - 1 then
					local x = slotStartX + slotWidth
					createParkingLine(chunkModel, Vector3.new(x, 0, frontZrow), Vector3.new(x, 0, backZrow))
				end
			end
		end
	end

	-- Pillars (global grid)
	do
		local pillarSize = cs * 0.4
		local pillarHalfWidth = pillarSize / 2
		local minX, minZ = origin.X, origin.Z
		local maxX, maxZ = minX + CHUNK_SIZE * cs, minZ + CHUNK_SIZE * cs
		for x = math.floor(minX/ PILLAR_GRID_SPACING + 0.5)*PILLAR_GRID_SPACING, maxX, PILLAR_GRID_SPACING do
			for z = math.floor(minZ/ PILLAR_GRID_SPACING + 0.5)*PILLAR_GRID_SPACING, maxZ, PILLAR_GRID_SPACING do
				createColumn(chunkModel, Vector3.new(x, origin.Y, z), pillarHalfWidth, zoneHeight)
			end
		end
	end

	-- Perimeter walls (collect for door placement)
	local perimeterWalls = {}
	local wallThickness = cs * 0.2
	local wallHeightVal = zoneHeight
	local finiteW, finiteD = genConfig.finiteWidth, genConfig.finiteDepth

	if not (finiteW and finiteD) or chunkZ == 0 then
		local w = createWall(chunkModel,
			Vector3.new(totalSize.X, wallHeightVal, wallThickness),
			CFrame.new(origin + Vector3.new(totalSize.X/2, wallHeightVal/2, 0)),
			conConfig.decals.wall)
		table.insert(perimeterWalls, w)
	end
	if not (finiteW and finiteD) or chunkZ == finiteD - 1 then
		local w = createWall(chunkModel,
			Vector3.new(totalSize.X, wallHeightVal, wallThickness),
			CFrame.new(origin + Vector3.new(totalSize.X/2, wallHeightVal/2, totalSize.Z)),
			conConfig.decals.wall)
		table.insert(perimeterWalls, w)
	end
	if not (finiteW and finiteD) or chunkX == 0 then
		local w = createWall(chunkModel,
			Vector3.new(wallThickness, wallHeightVal, totalSize.Z),
			CFrame.new(origin + Vector3.new(0, wallHeightVal/2, totalSize.Z/2)),
			conConfig.decals.wall)
		table.insert(perimeterWalls, w)
	end
	if not (finiteW and finiteD) or chunkX == finiteW - 1 then
		local w = createWall(chunkModel,
			Vector3.new(wallThickness, wallHeightVal, totalSize.Z),
			CFrame.new(origin + Vector3.new(totalSize.X, wallHeightVal/2, totalSize.Z/2)),
			conConfig.decals.wall)
		table.insert(perimeterWalls, w)
	end

	-- Ceiling pipes (as slim plates) + lights
	local pipeY = h - 0.5
	for gz = math.floor(origin.Z/ PILLAR_GRID_SPACING + 0.5)*PILLAR_GRID_SPACING, origin.Z + CHUNK_SIZE*cs, PILLAR_GRID_SPACING do
		local zOff = gz - origin.Z
		createPlate(chunkModel,
			origin + Vector3.new(0, pipeY, zOff),
			Vector3.new(totalSize.X, 0, 0.3), 0.3,
			Enum.Material.Metal, "Dark stone grey")
	end
	local halfGrid = PILLAR_GRID_SPACING * 0.5
	for gx = math.floor(origin.X/ PILLAR_GRID_SPACING + 0.5)*PILLAR_GRID_SPACING + halfGrid, origin.X + CHUNK_SIZE*cs + halfGrid, PILLAR_GRID_SPACING do
		for gz = math.floor(origin.Z/ PILLAR_GRID_SPACING + 0.5)*PILLAR_GRID_SPACING + halfGrid, origin.Z + CHUNK_SIZE*cs + halfGrid, PILLAR_GRID_SPACING do
			createLightFixture(chunkModel, origin + Vector3.new(gx - origin.X, pipeY - 0.5, gz - origin.Z))
		end
	end

	-- Optional props
	-- if rng:NextNumber() < 0.15 then createSupplyCrate(chunkModel, origin + Vector3.new(cs*2, 0, cs*2), cs) end
	-- if rng:NextNumber() < 0.10 then createWaterPuddle(chunkModel, origin + Vector3.new(cs*3, 0, cs*3), cs) end

	-- Try placing a gated exit on one of the perimeter walls
	placeExitDoorOnPerimeter(perimeterWalls, rng, config, mapContainer)

	return chunkModel
end

return M
