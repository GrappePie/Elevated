-- ModuleScript: BackroomsLvl1

local BackroomsLvl1 = {}

-- Helper: crea placa de suelo o techo
local function createPlate(parent, pos, size, thickness, material, color)
   local plate = Instance.new("Part", parent)
   plate.Anchored = true
   plate.Size = Vector3.new(size.X, thickness, size.Z)
   plate.CFrame = CFrame.new(pos + Vector3.new(size.X/2, thickness/2, size.Z/2))
   plate.Material = material
   if color then plate.BrickColor = BrickColor.new(color) end
   return plate
end

local function createParkingLine(parent, startPos, endPos, segmentLen, gapLen)
   -- Continuous parking line
   local dirVec = endPos - startPos
   local totalLen = dirVec.Magnitude
   if totalLen <= 0 then return end
   local dir = dirVec.Unit
   -- Determine orientation for size (ancho aumentado a 1 stud)
   local sizeX = math.abs(dir.Z) > 0.5 and 1.0 or totalLen
   local sizeZ = math.abs(dir.X) > 0.5 and 1.0 or totalLen
   -- Create line slightly above floor
   local line = Instance.new("Part", parent)
   line.Anchored = true
   -- Ajustar altura a 0.1 y elevar casi a nivel del piso
   local height = 0.1
   line.Size = Vector3.new(sizeX, height, sizeZ)
   -- Levantar línea: suelo=1, mitad altura línea
   local liftY = 1 + height / 2
   local center = (startPos + endPos) / 2 + Vector3.new(0, liftY, 0)
   line.CFrame = CFrame.new(center)
   line.Material = Enum.Material.SmoothPlastic
   line.BrickColor = BrickColor.new("Institutional white")
   line.Reflectance = 0
   return line
end

-- Helper: crea columna rectangular
local function createColumn(parent, pos, halfWidth, height)
   local col = Instance.new("Part", parent)
   -- Construir como bloque rectangular
   col.Size = Vector3.new(halfWidth*2, height, halfWidth*2)
   col.CFrame = CFrame.new(pos + Vector3.new(0, height/2, 0))
   col.Anchored = true
   col.Material = Enum.Material.Concrete
   col.BrickColor = BrickColor.new("Dark stone grey")
   return col
end

-- Helper: crea luminaria colgante
local function createLightFixture(parent, pos)
   local light = Instance.new("Part", parent)
   light.Size = Vector3.new(1, 0.2, 1)
   light.CFrame = CFrame.new(pos)
   light.Anchored = true
   light.Material = Enum.Material.Plastic
   light.BrickColor = BrickColor.new("Institutional white")
   local f = Instance.new("PointLight", light)
   f.Range = 15; f.Brightness = 2
   return light
end
local function key(...) return table.concat({...}, ",") end
local function createPillar(parent,size,cframe) local p=Instance.new("Part",parent); p.Size,p.CFrame,p.Anchored,p.Material=size,cframe,true,Enum.Material.Concrete; return p end
local function createDecaledPart(parent,size,cframe,face,decalId) local p=Instance.new("Part",parent); p.Size,p.CFrame,p.Anchored=size,cframe,true; if decalId and decalId~="" then local d=Instance.new("Decal",p); d.Face,d.Texture=face,"rbxassetid://"..decalId end; return p end
local function createWall(parent,size,cframe,decalId) local w=Instance.new("Part",parent); w.Size,w.CFrame,w.Anchored=size,cframe,true; if decalId and decalId~="" then for _,f in ipairs({Enum.NormalId.Front,Enum.NormalId.Back,Enum.NormalId.Left,Enum.NormalId.Right}) do local d=Instance.new("Decal",w); d.Face,d.Texture=f,"rbxassetid://"..decalId end end; return w end
-- Función para crear caja de suministros (madera con forma de caja)
local function createSupplyCrate(parent, pos, size)
   local crate = Instance.new("Part", parent)
   crate.Size = Vector3.new(size, size, size)
   crate.CFrame = CFrame.new(pos + Vector3.new(size/2, size/2, size/2))
   crate.Anchored = true
   crate.Material = Enum.Material.WoodPlanks
   return crate
end

-- Función para crear charco de agua con material Water
local function createWaterPuddle(parent, pos, size)
   local p = Instance.new("Part", parent)
   p.Size = Vector3.new(size, 0.2, size)        -- mayor grosor para reflejar mejor
   p.CFrame = CFrame.new(pos + Vector3.new(size/2, 0.05, size/2))
   p.Anchored = true
   p.Material = Enum.Material.SmoothPlastic         -- para mejor reflejo del agua
   p.Color = Color3.new(0.1, 0.15, 0.2)
   p.Transparency = 0.2
   p.Reflectance = 0.3
   return p
end

local function createCeilingPipe(parent, pos, length)
   local pipe = Instance.new("Part", parent)
   pipe.Shape = Enum.PartType.Cylinder
   pipe.Size = Vector3.new(0.2, length, 0.2)
   pipe.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
   pipe.Anchored = true
   pipe.Material = Enum.Material.Metal
   pipe.BrickColor = BrickColor.new("Dark stone grey")
   return pipe
end

-- Función para crear baldosa de suelo (Slate)
local function createFloorTile(parent, pos, size)
   local tile = Instance.new("Part", parent)
   tile.Size = Vector3.new(size, 0.2, size)
   tile.CFrame = CFrame.new(pos + Vector3.new(size/2, 0.1, size/2))
   tile.Anchored = true
   tile.Material = Enum.Material.Slate
   tile.BrickColor = BrickColor.new("Dark stone grey")
   return tile
end

local function createCeilingPanel(parent, pos, size, height)
   local panel = Instance.new("Part", parent)
   panel.Size = Vector3.new(size, 0.2, size)
   panel.CFrame = CFrame.new(pos + Vector3.new(size/2, height + 0.1, size/2))
   panel.Anchored = true
   panel.Material = Enum.Material.SmoothPlastic
   panel.BrickColor = BrickColor.new("Institutional white")
   return panel
end

local function createParkingSlotDetector(parent, pos, size)
   local detector = Instance.new("Part", parent)
   detector.Size = size
   detector.CFrame = CFrame.new(pos)
   detector.Anchored = true
   detector.CanCollide = false
   detector.Transparency = 1 -- Invisible detector
   detector.Name = "ParkingSlotDetector"
   -- Eventos vacíos; lógica de detección en Touch o TouchEnded si se requiere
   detector.Touched:Connect(function(otherPart) end)
   detector.TouchEnded:Connect(function(otherPart) end)
   return detector
end

-- Helper: calcula offsets equidistantes para una cuadrícula NxN
local function getEquallySpacedOffsets(count, totalLength, itemSize)
   local spacingCount = count + 1
   local freeSpace = totalLength - (count * itemSize)
   local spacing = freeSpace / spacingCount
   local offsets = {}
   for i = 1, count do
      local offset = spacing * i + itemSize * (i - 0.5)
      table.insert(offsets, offset)
   end
   return offsets
end


function BackroomsLvl1.GenerateChunk(chunkX, chunkY, chunkZ, config, mapContainer)
   local conConfig, genConfig = config.construction, config.generation
   local CHUNK_SIZE, cs, h = genConfig.CHUNK_SIZE, conConfig.CELL_SIZE, conConfig.WALL_HEIGHT
   -- Función para redondear al grid global
   local function roundToGrid(val, spacing)
      return math.floor(val / spacing + 0.5) * spacing
   end
   -- Determinar si este chunk es área de estacionamiento
   local zoneRng = Random.new(chunkX*97 + chunkY*61 + chunkZ*41)
   local isParkingZone = (zoneRng:NextNumber() < 0.3)
   local zoneHeight = isParkingZone and (h * 1.8) or h
   local ids = conConfig.decals
   local chunkModel = Instance.new("Model",mapContainer); chunkModel.Name=key(chunkX,chunkY,chunkZ)

   -- Creación de parking realista
   local origin = Vector3.new(chunkX*CHUNK_SIZE*cs, chunkY*h, chunkZ*CHUNK_SIZE*cs)
   local totalSize = Vector3.new(CHUNK_SIZE*cs, 0, CHUNK_SIZE*cs)
   -- Suelo completo
   createPlate(chunkModel, origin, totalSize, 1, Enum.Material.Concrete, "Medium stone grey")
   -- Parking entre pilares: 3 cajones por celda
   local PILLAR_GRID_SPACING = 100
   local slotsPerCell = 3
   local slotWidth = PILLAR_GRID_SPACING / slotsPerCell
   local slotDepth = totalSize.Z * 0.2
   local depthOffset = (totalSize.Z - slotDepth) / 2
   local frontZ = origin.Z + depthOffset
   local backZ  = origin.Z + depthOffset + slotDepth
   -- Recopilar posiciones X y Z de pilares dentro del chunk
   local pillarXs = {}
   for xP = roundToGrid(origin.X, PILLAR_GRID_SPACING), origin.X + CHUNK_SIZE * cs, PILLAR_GRID_SPACING do
       table.insert(pillarXs, xP)
   end
   local pillarZs = {}
   for zP = roundToGrid(origin.Z, PILLAR_GRID_SPACING), origin.Z + CHUNK_SIZE * cs, PILLAR_GRID_SPACING do
       table.insert(pillarZs, zP)
   end
   -- Dibujar estacionamientos horizontales (paralelos): 3 cajones entre cada par de pilares, en todas las filas Z
   for zi = 1, #pillarZs do
       local baseZ = pillarZs[zi]
       local frontZrow = baseZ + depthOffset
       local backZrow = baseZ + depthOffset + slotDepth
       for xi = 1, #pillarXs - 1 do
           local gridStartX = pillarXs[xi]
           -- Contorno horizontal
           createParkingLine(chunkModel, Vector3.new(gridStartX, 0, frontZrow), Vector3.new(gridStartX + PILLAR_GRID_SPACING, 0, frontZrow), PILLAR_GRID_SPACING, 0)
           createParkingLine(chunkModel, Vector3.new(gridStartX, 0, backZrow),  Vector3.new(gridStartX + PILLAR_GRID_SPACING, 0, backZrow),  PILLAR_GRID_SPACING, 0)
           createParkingLine(chunkModel, Vector3.new(gridStartX, 0, frontZrow), Vector3.new(gridStartX, 0, backZrow), slotDepth, 0)
           createParkingLine(chunkModel, Vector3.new(gridStartX + PILLAR_GRID_SPACING, 0, frontZrow), Vector3.new(gridStartX + PILLAR_GRID_SPACING, 0, backZrow), slotDepth, 0)
           -- Líneas divisorias y detectores
           for j = 0, slotsPerCell - 1 do
               local slotStartX = gridStartX + j * slotWidth
               -- Crear detector para este cajón (un poco más bajo para no tocar el techo)
               local detectorHeight = zoneHeight - 2 -- Aumentar el espacio con el techo
               local detectorPos = Vector3.new(slotStartX + slotWidth/2, origin.Y + 1 + detectorHeight/2, frontZrow + slotDepth/2)
               local detectorSize = Vector3.new(slotWidth, detectorHeight, slotDepth)
               createParkingSlotDetector(chunkModel, detectorPos, detectorSize)

               -- Crear línea divisoria a la derecha del cajón (si no es el último)
               if j < slotsPerCell - 1 then
                   local x = slotStartX + slotWidth
                   createParkingLine(chunkModel, Vector3.new(x, 0, frontZrow), Vector3.new(x, 0, backZrow), slotDepth, 0)
               end
           end
       end
   end
   -- Pilares alineados a la cuadrícula global
   local PILLAR_GRID_SPACING = 100
   local pillarSize = cs * 0.4
   local pillarHalfWidth = pillarSize / 2
   -- Límites del chunk en coordenadas X/Z
   local minX, minZ = origin.X, origin.Z
   local maxX, maxZ = minX + CHUNK_SIZE * cs, minZ + CHUNK_SIZE * cs
   -- Función para redondear al grid global
   local function roundToGrid(val, spacing)
      return math.floor(val / spacing + 0.5) * spacing
   end
   for x = roundToGrid(minX, PILLAR_GRID_SPACING), maxX, PILLAR_GRID_SPACING do
      for z = roundToGrid(minZ, PILLAR_GRID_SPACING), maxZ, PILLAR_GRID_SPACING do
         createColumn(chunkModel, Vector3.new(x, origin.Y, z), pillarHalfWidth, zoneHeight)
      end
   end
   -- Pared perimetral alrededor del chunk (solo en bordes de la cuadricula finita)
   local wallThickness = cs * 0.2  -- Muros más gruesos para bloquear luz en uniones
   local wallHeightVal = zoneHeight
   local finiteW, finiteD = genConfig.finiteWidth, genConfig.finiteDepth
   -- Frontal (Z min)
   if not (finiteW and finiteD) or chunkZ == 0 then
      createWall(chunkModel,
         Vector3.new(totalSize.X, wallHeightVal, wallThickness),
         CFrame.new(origin + Vector3.new(totalSize.X/2, wallHeightVal/2, 0)),
         ids.wall)
   end
   -- Trasera (Z max)
   if not (finiteW and finiteD) or chunkZ == finiteD - 1 then
      createWall(chunkModel,
         Vector3.new(totalSize.X, wallHeightVal, wallThickness),
         CFrame.new(origin + Vector3.new(totalSize.X/2, wallHeightVal/2, totalSize.Z)),
         ids.wall)
   end
   -- Lateral izquierdo (X min)
   if not (finiteW and finiteD) or chunkX == 0 then
      createWall(chunkModel,
         Vector3.new(wallThickness, wallHeightVal, totalSize.Z),
         CFrame.new(origin + Vector3.new(0, wallHeightVal/2, totalSize.Z/2)),
         ids.wall)
   end
   -- Lateral derecho (X max)
   if not (finiteW and finiteD) or chunkX == finiteW - 1 then
      createWall(chunkModel,
         Vector3.new(wallThickness, wallHeightVal, totalSize.Z),
         CFrame.new(origin + Vector3.new(totalSize.X, wallHeightVal/2, totalSize.Z/2)),
         ids.wall)
   end
   -- Tuberías y luminarias alineadas a la cuadrícula global
   local pipeY = h - 0.5
   -- Tubos distribuidos según PILLAR_GRID_SPACING en Z
   for gz = roundToGrid(minZ, PILLAR_GRID_SPACING), maxZ, PILLAR_GRID_SPACING do
      local zOff = gz - origin.Z
      createPlate(chunkModel,
         origin + Vector3.new(0, pipeY, zOff),
         Vector3.new(totalSize.X, 0, 0.3), 0.3,
         Enum.Material.Metal, "Dark stone grey")
   end
   -- Luminarias en el centro de cada celda de la cuadrícula global
   local halfGrid = PILLAR_GRID_SPACING * 0.5
   for gx = roundToGrid(minX, PILLAR_GRID_SPACING) + halfGrid, maxX + halfGrid, PILLAR_GRID_SPACING do
      for gz = roundToGrid(minZ, PILLAR_GRID_SPACING) + halfGrid, maxZ + halfGrid, PILLAR_GRID_SPACING do
         local xOff = gx - origin.X
         local zOff = gz - origin.Z
         createLightFixture(chunkModel,
            origin + Vector3.new(xOff, pipeY - 0.5, zOff))
      end
   end
   return chunkModel
end

return BackroomsLvl1