-- ModuleScript: BackroomsLvl0
-- VERSIÓN CON REEMPLAZO DE PAREDES: Primero crea las paredes, luego las reemplaza con puertas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--================================================================
--=                     REFERENCIAS A MÓDULOS                    =
--================================================================
local LevelFeatureFactoryModule = ServerScriptService:FindFirstChild("LevelFeatureFactory", true)
local exitDoorInteractionScript = ReplicatedStorage:FindFirstChild("ExitDoorInteraction")

if not LevelFeatureFactoryModule then warn("BackroomsLvl0: No se pudo encontrar 'LevelFeatureFactory'.") end
if not exitDoorInteractionScript then warn("BackroomsLvl0: No se pudo encontrar 'ExitDoorInteraction'.") end

local LevelFeatureFactory = LevelFeatureFactoryModule and require(LevelFeatureFactoryModule)
local BackroomsLvl0 = {}

--================================================================
--=                  FUNCIONES AUXILIARES DE CONSTRUCCIÓN        =
--================================================================
local function key(x, z) return x .. "," .. z end
local function createWallPart(parent, size, cframe, face, textureId, cs, h)
	local part = Instance.new("Part", parent); part.Size, part.CFrame, part.Anchored = size, cframe, true; part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth; if not textureId or textureId == "" then return part end; local texture = Instance.new("Texture", part); texture.Face = face; texture.Texture = "rbxassetid://"..tostring(textureId); texture.StudsPerTileU = cs; texture.StudsPerTileV = h; local opposites = {[Enum.NormalId.Front]=Enum.NormalId.Back, [Enum.NormalId.Back]=Enum.NormalId.Front, [Enum.NormalId.Left]=Enum.NormalId.Right, [Enum.NormalId.Right]=Enum.NormalId.Left}; if opposites[face] then local texture2 = Instance.new("Texture", part); texture2.Face = opposites[face]; texture2.Texture = texture.Texture; texture2.StudsPerTileU = texture.StudsPerTileU; texture2.StudsPerTileV = texture.StudsPerTileV; end; return part
end
local function createDecaledPart(parent, size, cframe, face, decalId)
	local part = Instance.new("Part", parent); part.Transparency = 1; part.Size, part.CFrame, part.Anchored = size, cframe, true; if decalId and decalId ~= "" then local decal = Instance.new("Decal", part); decal.Face, decal.Texture = face, "rbxassetid://"..tostring(decalId); end; return part
end

--================================================================
--=                  LÓGICA DE CONSTRUCCIÓN                      =
--================================================================

-- Esta función ahora solo fusiona paredes y devuelve una lista de las partes creadas.
local function mergeWalls(wallSegments, parent, h, cs, thickness, textureId, isZAxis)
	local createdWalls = {}
	local processed = {}

	for i, startSegment in ipairs(wallSegments) do
		if not processed[i] then
			processed[i] = true
			local mergeCount = 1; local currentPos = startSegment; for j = i + 1, #wallSegments do local nextSegment = wallSegments[j]; local expectedNextPos; if isZAxis then expectedNextPos = {x = currentPos.x, z = currentPos.z + 1} else expectedNextPos = {x = currentPos.x + 1, z = currentPos.z} end; if nextSegment.x == expectedNextPos.x and nextSegment.z == expectedNextPos.z then mergeCount = mergeCount + 1; currentPos = nextSegment; for k, seg in ipairs(wallSegments) do if seg.x == nextSegment.x and seg.z == nextSegment.z then processed[k] = true; break end end end end

			local size, cframe, face
			if isZAxis then
				size = Vector3.new(thickness, h, cs * mergeCount)
				local centerOffset = Vector3.new(0, h/2, (startSegment.z - 1 + mergeCount / 2) * cs)
				cframe = CFrame.new(startSegment.origin + centerOffset)
				face = Enum.NormalId.Right
			else
				size = Vector3.new(cs * mergeCount, h, thickness)
				local centerOffset = Vector3.new((startSegment.x - 1 + mergeCount / 2) * cs, h/2, 0)
				cframe = CFrame.new(startSegment.origin + centerOffset)
				face = Enum.NormalId.Front
			end
			local wallPart = createWallPart(parent, size, cframe, face, textureId, cs, h)
			table.insert(createdWalls, wallPart)
		end
	end
	return createdWalls
end

-- [[ NUEVA FUNCIÓN PARA COLOCAR LA PUERTA ]]
-- Elige una pared de la lista y pone una puerta.
local function tryPlaceDoor(walls, chunkRng, config, mapContainer)
	local CHANCE_DE_SALIDA = 1 -- Probabilidad del 100% (la bajaremos después)
	if #walls == 0 or not (LevelFeatureFactory and exitDoorInteractionScript) then
		return
	end

	if chunkRng:NextNumber() < CHANCE_DE_SALIDA then
		-- 1. Elegir una pared al azar para reemplazarla
		local wallToReplace = walls[chunkRng:NextInteger(1, #walls)]

		-- 2. Comprobar si la pared es suficientemente grande
		local doorWidth = 8 -- Ancho de la puerta definido en LevelFeatureFactory
		local wallSize = wallToReplace.Size
		if math.max(wallSize.X, wallSize.Z) < doorWidth + 2 then
			return -- La pared es muy pequeña, no hacemos nada.
		end

		print("¡Reemplazando una pared con una puerta de salida!")

		-- 3. Guardar la posición y orientación de la pared
		local wallCFrame = wallToReplace.CFrame
		local wallSize = wallToReplace.Size
		-- 4. Calcular offset para colocar la puerta junto a la pared sin destruirla
		local DOOR_OFFSET = 0 -- Mitad del grosor de la puerta para que quede pegada
		local offsetDist, doorCFrame
		if wallSize.X < wallSize.Z then
			-- pared alineada en Z, mover en X y rotar la puerta para mirar hacia la pared
			offsetDist = wallSize.X/2 - DOOR_OFFSET
			doorCFrame = wallCFrame * CFrame.new(offsetDist, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
		else
			-- pared alineada en X, mover en Z (orientación por defecto)
			offsetDist = wallSize.Z/2 - DOOR_OFFSET
			doorCFrame = wallCFrame * CFrame.new(0, 0, offsetDist)
		end
		-- 5. Crear y posicionar el modelo de la puerta
		local h = config.construction.WALL_HEIGHT
		doorCFrame = doorCFrame * CFrame.new(0, -h/12, 0) -- Bajar la puerta (ajuste fino)
		local puertaModel = LevelFeatureFactory.createExitDoor_ToLevel1(config.construction)
		puertaModel:SetPrimaryPartCFrame(doorCFrame)
		puertaModel.Parent = mapContainer
		-- 6. Añadir el script de interacción
		local scriptClon = exitDoorInteractionScript:Clone()
		scriptClon.Parent = puertaModel
	end
end

--================================================================
--=                  FUNCIÓN PRINCIPAL DE GENERACIÓN             =
--================================================================
function BackroomsLvl0.GenerateChunk(chunkX, chunkY, chunkZ, config, mapContainer)
	-- 1. Configuración y generación de la cuadrícula (sin cambios)
	local conConfig = config.construction; local genConfig = config.generation; local CHUNK_SIZE = genConfig.CHUNK_SIZE or 16; local cs, h = conConfig.CELL_SIZE, conConfig.WALL_HEIGHT; local ids = conConfig.decals; local chunkModel = Instance.new("Model", mapContainer); chunkModel.Name = key(chunkX, chunkY, chunkZ);
	local internalSeed = chunkX * 7 + chunkZ * 23; local chunkRng = Random.new(internalSeed);
	local grid = {}; for x = 1, CHUNK_SIZE do grid[x] = {} for z = 1, CHUNK_SIZE do grid[x][z] = { connections = {} } end end
	local borderSeed = chunkX * 13 + chunkZ * 31; local borderRng = Random.new(borderSeed); for i=1,CHUNK_SIZE do if borderRng:NextNumber()<0.2 then grid[i][1].connections[key(i,0)]=true end; if borderRng:NextNumber()<0.2 then grid[i][CHUNK_SIZE].connections[key(i,CHUNK_SIZE+1)]=true end; if borderRng:NextNumber()<0.2 then grid[1][i].connections[key(0,i)]=true end; if borderRng:NextNumber()<0.2 then grid[CHUNK_SIZE][i].connections[key(CHUNK_SIZE+1,i)]=true end end
	local stack={{x=chunkRng:NextInteger(1,CHUNK_SIZE),z=chunkRng:NextInteger(1,CHUNK_SIZE)}}; local visited={[key(stack[1].x,stack[1].z)]=true}; while #stack>0 do local current=stack[#stack]; local x,z=current.x,current.z; local neighbors={}; for _,dir in ipairs({{0,1},{0,-1},{1,0},{-1,0}}) do local nx,nz=x+dir[1],z+dir[2]; if nx>=1 and nx<=CHUNK_SIZE and nz>=1 and nz<=CHUNK_SIZE and not visited[key(nx,nz)] then table.insert(neighbors,{x=nx,z=nz}) end end; if #neighbors>0 then local pick=neighbors[chunkRng:NextInteger(1,#neighbors)]; grid[x][z].connections[key(pick.x,pick.z)]=true; grid[pick.x][pick.z].connections[key(x,z)]=true; visited[key(pick.x,pick.z)]=true; table.insert(stack,pick) else table.remove(stack) end end
	if chunkRng:NextNumber()<0.25 then local roomSize=2; local rx=chunkRng:NextInteger(1,CHUNK_SIZE-roomSize); local rz=chunkRng:NextInteger(1,CHUNK_SIZE-roomSize); for x=rx,rx+roomSize-1 do for z=rz,rz+roomSize-1 do if x+1<rx+roomSize then grid[x][z].connections[key(x+1,z)]=true; grid[x+1][z].connections[key(x,z)]=true end; if z+1<rz+roomSize then grid[x][z].connections[key(x,z+1)]=true; grid[x][z+1].connections[key(x,z)]=true end end end end

	-- 2. Registro de la geometría a construir (sin cambios)
	local wallsToMergeX = {}; local wallsToMergeZ = {}; local chunkOrigin = Vector3.new(chunkX * CHUNK_SIZE * cs, chunkY * h, chunkZ * CHUNK_SIZE * cs)
	for x = 1, CHUNK_SIZE do for z = 1, CHUNK_SIZE do
			local cellOrigin = chunkOrigin + Vector3.new((x-1)*cs, 0, (z-1)*cs)
			createDecaledPart(chunkModel,Vector3.new(cs,1,cs),CFrame.new(cellOrigin+Vector3.new(cs/2,0,cs/2)),Enum.NormalId.Top,ids.floor)
			createDecaledPart(chunkModel,Vector3.new(cs,1,cs),CFrame.new(cellOrigin+Vector3.new(cs/2,h,cs/2)),Enum.NormalId.Bottom,ids.roof)
			if not grid[x][z].connections[key(x-1,z)] then table.insert(wallsToMergeZ,{x=x,z=z,origin=cellOrigin}) end
			if not grid[x][z].connections[key(x,z-1)] then table.insert(wallsToMergeX,{x=x,z=z,origin=cellOrigin}) end
		end end

	-- 3. Construcción de paredes
	table.sort(wallsToMergeX, function(a, b) return a.z < b.z or (a.z == b.z and a.x < b.x) end)
	table.sort(wallsToMergeZ, function(a, b) return a.x < b.x or (a.x == b.x and a.z < b.z) end)
	local WALL_THICKNESS = 1

	local createdWallsX = mergeWalls(wallsToMergeX, chunkModel, h, cs, WALL_THICKNESS, ids.wall, false)
	local createdWallsZ = mergeWalls(wallsToMergeZ, chunkModel, h, cs, WALL_THICKNESS, ids.wall, true)

	-- 4. Colocación de la puerta (Nuevo paso final)
	local allCreatedWalls = {}
	for _, wall in ipairs(createdWallsX) do table.insert(allCreatedWalls, wall) end
	for _, wall in ipairs(createdWallsZ) do table.insert(allCreatedWalls, wall) end

	tryPlaceDoor(allCreatedWalls, chunkRng, config, chunkModel)

	return chunkModel
end

return BackroomsLvl0
