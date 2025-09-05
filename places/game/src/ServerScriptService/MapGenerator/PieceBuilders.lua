-- ModuleScript: PieceBuilders
-- Contiene toda la lógica para construir la geometría de las piezas (cuartos, pasillos, paredes, etc.).

local PieceBuilders = {}

-----------------------------------------------------------------------------
-- Funciones Auxiliares de Construcción (privadas a este módulo)
-----------------------------------------------------------------------------
local function createPart(size, cframe, parent, color, material)
	local part = Instance.new("Part")
	part.Size, part.CFrame, part.Anchored = size, cframe, true
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Material, part.Color, part.Parent = material or Enum.Material.Concrete, color, parent
	return part
end

local function createTwoToneWall(size, cframe, parent, direction, config)
	local modelWall = Instance.new("Model", parent)
	modelWall.Name = "WallSegment"
	modelWall:SetAttribute("WallDirection", direction)

	local h, hB, hA = size.Y, size.Y * config.RATIO_PINTURA, size.Y * (1 - config.RATIO_PINTURA)
	createPart(Vector3.new(size.X, hB, size.Z), cframe * CFrame.new(0, -hA / 2, 0), modelWall, config.COLOR_PARED_BAJA)
	createPart(Vector3.new(size.X, hA, size.Z), cframe * CFrame.new(0, hB / 2, 0), modelWall, config.COLOR_PARED_ALTA)
end

local function createDoorFrame(cframe, parent, config)
	local th, h, w = 0.5, config.ALTURA_PARED, config.PASILLO_ANCHO
	createPart(Vector3.new(w+th*2, th, config.GROSOR_PARED+th), cframe*CFrame.new(0,h/2,0), parent, config.COLOR_MARCO_PUERTA)
	createPart(Vector3.new(th, h, config.GROSOR_PARED+th), cframe*CFrame.new(-w/2,0,0), parent, config.COLOR_MARCO_PUERTA)
	createPart(Vector3.new(th, h, config.GROSOR_PARED+th), cframe*CFrame.new(w/2,0,0), parent, config.COLOR_MARCO_PUERTA)
end

-- *** NUEVA FUNCIÓN PARA EL ZÓCALO DE LAS PUERTAS ***
local function createFringeForDoor(parent, doorFrameCFrame, config)
	if not config.COLOR_FRANJA_PISO then return end

	-- Parámetros básicos
	local doorWidth     = config.PASILLO_ANCHO
	local wallLength    = config.CELL_SIZE
	local fringeHeight  = config.ALTURA_FRANJA_PISO or 0.1
	local postThickness = doorWidth * 0.15
	local baseDepth     = config.GROSOR_PARED + postThickness
	local penetration   = config.GROSOR_PARED / -2
	local halfDepth     = baseDepth + penetration
	local fringeDepth   = halfDepth * 2

	-- Control de salientes
	local overhang      = config.FRINGE_OVERHANG or 0.5
	local doorInset     = config.FRINGE_DOOR_INSET or 1

	-- Cálculos de ancho y posición
	local sideSegment   = (wallLength - doorWidth) / 2            -- tramo de pared a cada lado
	-- El ancho total de la pieza: desde donde entra en el vano hasta donde sobre el muro + overhang
	local pieceWidth    = sideSegment + overhang + doorInset + postThickness/2

	local yPos = -config.ALTURA_PARED/2
		+ config.ALTURA_PISO/2
		+ fringeHeight/2
	local offsetZ = 0  -- centrado en el plano de la pared

	for _, sign in ipairs({ -1, 1 }) do
		-- Calculamos la posición X del centro de esa pieza combinada:
		--   empieza a doorWidth/2 - doorInset - postThickness/2
		--   y tiene ancho pieceWidth, así que su centro va a:
		--     innerStart + pieceWidth/2
		local innerStart = doorWidth/2 - doorInset - postThickness/2
		local offsetX    = sign * (innerStart + pieceWidth/2)

		local size = Vector3.new(pieceWidth, fringeHeight, fringeDepth)
		local cf   = doorFrameCFrame * CFrame.new(offsetX, yPos, offsetZ)

		createPart(
			size,
			cf,
			parent,
			config.COLOR_FRANJA_PISO,
			config.MATERIAL_PISO
		)
	end
end

-- PASO 1: Dibuja las líneas rectas del zócalo (con superposiciones)
local function createPerimeterFringe_Lines(model, recipe, config)
	if not config.COLOR_FRANJA_PISO then return end

	local template        = recipe.template
	local pieceBaseCFrame = recipe.cframe
	local cellSize        = config.CELL_SIZE

	local ft = config.PASILLO_ANCHO * 0.15    -- grosor de franja
	local fh = config.ALTURA_FRANJA_PISO or 0.1
	local yPos      = (config.ALTURA_PISO/2) + (fh/2)
	local wallOff   = config.GROSOR_PARED/2

	-- 1) Detectar si es un cuarto completo (sin 'x' en el template)
	local isRoom = true
	for r = 1, 3 do
		for c = 1, 3 do
			if template[r][c] == 'x' then
				isRoom = false
				break
			end
		end
		if not isRoom then break end
	end

	-- 2) Ajustar overlap: cero en cuarto, >0 en pasillo
	local overlap = isRoom
		and 0
		or (ft * 2.5)    -- tu valor “perfecto” para pasillos

	local longLenH  = cellSize + overlap  -- longitud horizontal
	local longLenV  = cellSize + overlap  -- longitud vertical

	for r = 1, 3 do
		for c = 1, 3 do
			if template[r][c] == 'o' then
				local cf = pieceBaseCFrame
					* CFrame.new((c-2)*cellSize, 0, (r-2)*cellSize)

				-- Norte
				if (r==1 or template[r-1][c]=='x')
					and not (r==1 and c==2 and recipe.doors.N) then
					createPart(
						Vector3.new(longLenH, fh, ft),
						cf * CFrame.new(0, yPos, -(cellSize/2) + wallOff + ft/2),
						model,
						config.COLOR_FRANJA_PISO
					)
				end

				-- Sur
				if (r==3 or template[r+1][c]=='x')
					and not (r==3 and c==2 and recipe.doors.S) then
					createPart(
						Vector3.new(longLenH, fh, ft),
						cf * CFrame.new(0, yPos,  (cellSize/2) - wallOff - ft/2),
						model,
						config.COLOR_FRANJA_PISO
					)
				end

				-- Oeste
				if (c==1 or template[r][c-1]=='x')
					and not (c==1 and r==2 and recipe.doors.W) then
					createPart(
						Vector3.new(ft, fh, longLenV),
						cf * CFrame.new(-(cellSize/2) + wallOff + ft/2, yPos, 0),
						model,
						config.COLOR_FRANJA_PISO
					)
				end

				-- Este
				if (c==3 or template[r][c+1]=='x')
					and not (c==3 and r==2 and recipe.doors.E) then
					createPart(
						Vector3.new(ft, fh, longLenV),
						cf * CFrame.new( (cellSize/2) - wallOff - ft/2, yPos, 0),
						model,
						config.COLOR_FRANJA_PISO
					)
				end
			end
		end
	end
end

-----------------------------------------------------------------------------
-- Funciones Públicas del Módulo
-----------------------------------------------------------------------------
function PieceBuilders.buildShape(model, recipe, config)
	local template = recipe.template
	local pieceBaseCFrame = recipe.cframe
	local cellSize = config.CELL_SIZE

	-- 1. Crea todo el piso
	for r = 1, 3 do for c = 1, 3 do if template[r][c] == 'o' then
				local cellCFrame = pieceBaseCFrame * CFrame.new((c - 2) * cellSize, 0, (r - 2) * cellSize)
				createPart(Vector3.new(cellSize, config.ALTURA_PISO, cellSize), cellCFrame, model, config.COLOR_PISO_NUEVO, config.MATERIAL_PISO)
			end end end

	-- 2. Crea las paredes
	for r = 1, 3 do
		for c = 1, 3 do if template[r][c] == 'o' then
				local cellCFrame = pieceBaseCFrame * CFrame.new((c - 2) * cellSize, 0, (r - 2) * cellSize)

				-- Norte
				if (r == 1 or template[r-1][c] == 'x') then
					local wallCFrame = cellCFrame * CFrame.new(0, config.ALTURA_PARED / 2, -cellSize / 2)
					if not (r == 1 and c == 2 and recipe.doors.N) then
						createTwoToneWall(
							Vector3.new(cellSize + config.GROSOR_PARED, config.ALTURA_PARED, config.GROSOR_PARED),
							wallCFrame, model, "N", config
						)
					elseif recipe.doors.N ~= "Shape" then
						createDoorFrame(wallCFrame, model, config)
						createFringeForDoor(model, wallCFrame, config)
					end
				end

				-- Sur
				if (r == 3 or template[r+1][c] == 'x') then
					local wallCFrame = cellCFrame * CFrame.new(0, config.ALTURA_PARED / 2, cellSize / 2)
					if not (r == 3 and c == 2 and recipe.doors.S) then
						createTwoToneWall(
							Vector3.new(cellSize + config.GROSOR_PARED, config.ALTURA_PARED, config.GROSOR_PARED),
							wallCFrame, model, "S", config
						)
					elseif recipe.doors.S ~= "Shape" then
						createDoorFrame(wallCFrame, model, config)
						createFringeForDoor(model, wallCFrame, config)
					end
				end

				-- Oeste
				if (c == 1 or template[r][c-1] == 'x') then
					local wallCFrame = cellCFrame * CFrame.new(-cellSize / 2, config.ALTURA_PARED / 2, 0) * CFrame.Angles(0, math.rad(90), 0)
					if not (c == 1 and r == 2 and recipe.doors.W) then
						createTwoToneWall(
							Vector3.new(cellSize + config.GROSOR_PARED, config.ALTURA_PARED, config.GROSOR_PARED),
							wallCFrame, model, "W", config
						)
					elseif recipe.doors.W ~= "Shape" then
						createDoorFrame(wallCFrame, model, config)
						createFringeForDoor(model, wallCFrame, config)
					end
				end

				-- Este
				if (c == 3 or template[r][c+1] == 'x') then
					local wallCFrame = cellCFrame * CFrame.new(cellSize / 2, config.ALTURA_PARED / 2, 0) * CFrame.Angles(0, math.rad(90), 0)
					if not (c == 3 and r == 2 and recipe.doors.E) then
						createTwoToneWall(
							Vector3.new(cellSize + config.GROSOR_PARED, config.ALTURA_PARED, config.GROSOR_PARED),
							wallCFrame, model, "E", config
						)
					elseif recipe.doors.E ~= "Shape" then
						createDoorFrame(wallCFrame, model, config)
						createFringeForDoor(model, wallCFrame, config)
					end
				end
			end end
	end

	-- 3. Crea el zócalo perimetral
	createPerimeterFringe_Lines(model, recipe, config)
end


function PieceBuilders.buildRoom(model, recipe, config)
	local totalSize = Vector3.new(3 * config.CELL_SIZE, config.ALTURA_PISO, 3 * config.CELL_SIZE)
	local floor = createPart(totalSize, recipe.cframe, model, config.COLOR_PISO_NUEVO, config.MATERIAL_PISO)
	model.PrimaryPart = floor

	-- Crear paredes
	local wallDirs = {N="X", S="X", W="Z", E="Z"}
	for dir, axis in pairs(wallDirs) do
		local wallLength = totalSize.X
		local wallCFrame, wallRotation
		if dir == "N" then wallCFrame, wallRotation = recipe.cframe * CFrame.new(0, config.ALTURA_PARED / 2, -wallLength / 2), CFrame.new()
		elseif dir == "S" then wallCFrame, wallRotation = recipe.cframe * CFrame.new(0, config.ALTURA_PARED / 2, wallLength / 2), CFrame.new()
		elseif dir == "W" then wallCFrame, wallRotation = recipe.cframe * CFrame.new(-wallLength / 2, config.ALTURA_PARED / 2, 0), CFrame.Angles(0, math.rad(90), 0)
		elseif dir == "E" then wallCFrame, wallRotation = recipe.cframe * CFrame.new(wallLength / 2, config.ALTURA_PARED / 2, 0), CFrame.Angles(0, math.rad(90), 0) end

		local finalWallCFrame = wallCFrame * wallRotation

		if recipe.doors[dir] then
			local doorWidth, segmentLen = config.PASILLO_ANCHO, (wallLength - config.PASILLO_ANCHO) / 2
			if segmentLen > 0.1 then
				createTwoToneWall(Vector3.new(segmentLen, config.ALTURA_PARED, config.GROSOR_PARED), finalWallCFrame * CFrame.new(-doorWidth/2 - segmentLen/2, 0, 0), model, dir, config)
				createTwoToneWall(Vector3.new(segmentLen, config.ALTURA_PARED, config.GROSOR_PARED), finalWallCFrame * CFrame.new(doorWidth/2 + segmentLen/2, 0, 0), model, dir, config)
			end
			createDoorFrame(finalWallCFrame, model, config)
			createFringeForDoor(model, finalWallCFrame, config) -- <-- Añadido aquí
		else
			createTwoToneWall(Vector3.new(wallLength, config.ALTURA_PARED, config.GROSOR_PARED), finalWallCFrame, model, dir, config)
		end
	end

	-- Crear el zócalo perimetral para el cuarto
	createPerimeterFringe_Lines(model, recipe, config)
end

return PieceBuilders
