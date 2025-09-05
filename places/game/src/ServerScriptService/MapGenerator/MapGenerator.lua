-- ModuleScript: MapGenerator (Versión con Perfiles)

local MapGenerator = {}

local NEIGH = {
	N = {r = -1, c =  0, opp = "S"}, S = {r =  1, c =  0, opp = "N"},
	E = {r =  0, c =  1, opp = "W"}, W = {r =  0, c = -1, opp = "E"},
}

local TEMPLATES = {
	Room = {type = "Room", template = {{'o', 'o', 'o'},{'o', 'o', 'o'},{'o', 'o', 'o'}}, exits = {N=true, S=true, E=true, W=true}},
	Cross = {type = "Shape", template = {{'x', 'o', 'x'},{'o', 'o', 'o'},{'x', 'o', 'x'}}, exits = {N=true, S=true, E=true, W=true}},
	Corridor_V = {type = "Shape", template = {{'x', 'o', 'x'},{'x', 'o', 'x'},{'x', 'o', 'x'}}, exits = {N=true, S=true}},
	Corridor_H = {type = "Shape", template = {{'x', 'x', 'x'},{'o', 'o', 'o'},{'x', 'x', 'x'}}, exits = {E=true, W=true}},
	T_Up = {type = "Shape", template = {{'x', 'o', 'x'},{'o', 'o', 'o'},{'x', 'x', 'x'}}, exits = {N=true, E=true, W=true}},
	T_Down = {type = "Shape", template = {{'x', 'x', 'x'},{'o', 'o', 'o'},{'x', 'o', 'x'}}, exits = {S=true, E=true, W=true}},
	T_Left = {type = "Shape", template = {{'x', 'o', 'x'},{'o', 'o', 'x'},{'x', 'o', 'x'}}, exits = {N=true, S=true, W=true}},
	T_Right = {type = "Shape", template = {{'x', 'o', 'x'},{'x', 'o', 'o'},{'x', 'o', 'x'}}, exits = {N=true, S=true, E=true}},
	L_TopLeft = {type = "Shape", template = {{'x', 'x', 'x'},{'x', 'o', 'o'},{'x', 'o', 'x'}}, exits = {S=true, E=true}},
	L_TopRight = {type = "Shape", template = {{'x', 'x', 'x'},{'o', 'o', 'x'},{'x', 'o', 'x'}}, exits = {S=true, W=true}},
	L_BottomLeft = {type = "Shape", template = {{'x', 'o', 'x'},{'x', 'o', 'o'},{'x', 'x', 'x'}}, exits = {N=true, E=true}},
	L_BottomRight = {type = "Shape", template = {{'x', 'o', 'x'},{'o', 'o', 'x'},{'x', 'x', 'x'}}, exits = {N=true, W=true}},
}

local function getCompatibleTemplates(entryDir, themeConfig)
	local compatible = {}
	local generationRules = themeConfig.generation

	for name, data in pairs(TEMPLATES) do
		if generationRules.isApartmentWing and data.type == "Room" then
			if data.exits[entryDir] then
				table.insert(compatible, {name = name, data = data})
			end
		elseif not generationRules.isApartmentWing then
			if data.exits[entryDir] then
				table.insert(compatible, {name = name, data = data})
			end
		end
	end
	return compatible
end

function MapGenerator.generateLayout(config, themeConfig)
	config = config or {}
	local rows, cols, maxPieces = config.rows or 15, config.cols or 20, config.maxPieces or 40
	local grid = {}
	for r = 1, rows do grid[r] = {} for c = 1, cols do grid[r][c] = {isOccupied = false} end end

	local pieces = {}
	local pieceIdMap = {}
	local openSockets = {}
	local pieceCounter = 0

	if themeConfig and themeConfig.generation.force_straight_corridor then
		local corridorLength = themeConfig.generation.force_straight_corridor
		local startR = math.floor(rows / 2)
		local totalLength = corridorLength + 2
		local startC = math.floor(cols / 2) - math.floor(totalLength / 2)

		pieceCounter += 1
		local startPos = {r = startR, c = startC}
		local startTemplate = TEMPLATES.Room
		local startRecipe = {id = pieceCounter, name = "Room_Start", type = "Room", pos = startPos, template = startTemplate.template, doors = {}}
		table.insert(pieces, startRecipe)
		grid[startPos.r][startPos.c] = {isOccupied = true, pieceId = pieceCounter}
		pieceIdMap[pieceCounter] = startRecipe

		for i = 1, corridorLength do
			pieceCounter += 1
			local pos = {r = startR, c = startC + i}
			if grid[pos.r] and grid[pos.r][pos.c] and not grid[pos.r][pos.c].isOccupied then
				local templateData = TEMPLATES.Cross
				local recipe = {id = pieceCounter, name = "Cross", type = "Shape", pos = pos, template = templateData.template, doors = {}}
				table.insert(pieces, recipe)
				grid[pos.r][pos.c] = {isOccupied = true, pieceId = recipe.id}
				pieceIdMap[recipe.id] = recipe
				table.insert(openSockets, {originId = recipe.id, originPos = pos, dir = "N"})
				table.insert(openSockets, {originId = recipe.id, originPos = pos, dir = "S"})
			end
		end

		pieceCounter += 1
		local endPos = {r = startR, c = startC + corridorLength + 1}
		if grid[endPos.r] and grid[endPos.r][endPos.c] and not grid[endPos.r][endPos.c].isOccupied then
			local endTemplate = TEMPLATES.Room
			local endRecipe = {id = pieceCounter, name = "Room_End", type = "Room", pos = endPos, template = endTemplate.template, doors = {}}
			table.insert(pieces, endRecipe)
			grid[endPos.r][endPos.c] = {isOccupied = true, pieceId = pieceCounter}
			pieceIdMap[pieceCounter] = endRecipe
		end

		themeConfig.generation.isApartmentWing = true
	else
		pieceCounter = 1
		local startPos = {r = math.floor(rows / 2), c = math.floor(cols / 2)}
		local startTemplateName = math.random() > 0.5 and "Room" or "Cross"
		local startTemplateData = TEMPLATES[startTemplateName]
		local recipe = {id = pieceCounter, name = startTemplateName, type = startTemplateData.type, pos = startPos, template = startTemplateData.template, doors = {}}
		table.insert(pieces, recipe)
		grid[startPos.r][startPos.c] = {isOccupied = true, pieceId = recipe.id}
		pieceIdMap[recipe.id] = recipe
		for dir, _ in pairs(startTemplateData.exits) do table.insert(openSockets, {originId = recipe.id, originPos = startPos, dir = dir}) end
	end

	while pieceCounter < maxPieces and #openSockets > 0 do
		local socketIndex = math.random(#openSockets)
		local currentSocket = table.remove(openSockets, socketIndex)
		local oppositeDir = NEIGH[currentSocket.dir].opp
		local compatible = getCompatibleTemplates(oppositeDir, themeConfig)

		if #compatible > 0 then
			local chosenTemplate = compatible[math.random(#compatible)]
			local newPos = {r = currentSocket.originPos.r + NEIGH[currentSocket.dir].r, c = currentSocket.originPos.c + NEIGH[currentSocket.dir].c}
			if newPos.r >= 1 and newPos.r <= rows and newPos.c >= 1 and newPos.c <= cols and not grid[newPos.r][newPos.c].isOccupied then
				pieceCounter = pieceCounter + 1
				local newRecipe = {id = pieceCounter, name = chosenTemplate.name, type = chosenTemplate.data.type, pos = newPos, template = chosenTemplate.data.template, doors = {}}
				table.insert(pieces, newRecipe)
				grid[newPos.r][newPos.c] = {isOccupied = true, pieceId = newRecipe.id}
				pieceIdMap[newRecipe.id] = newRecipe
				if not (themeConfig.generation.isApartmentWing) then
					for dir, _ in pairs(chosenTemplate.data.exits) do
						if dir ~= oppositeDir then table.insert(openSockets, {originId = newRecipe.id, originPos = newPos, dir = dir}) end
					end
				end
			end
		end
	end

	local finalLayout = {}
	for _, piece in ipairs(pieces) do
		local templateName = piece.name
		if string.find(templateName, "Room_") then templateName = "Room" end
		local templateData = TEMPLATES[templateName]

		if templateData then
			local finalDoors = {}
			for dir, _ in pairs(templateData.exits) do
				local neighborPos = {r = piece.pos.r + NEIGH[dir].r, c = piece.pos.c + NEIGH[dir].c}
				if neighborPos.r >= 1 and neighborPos.r <= rows and neighborPos.c >= 1 and neighborPos.c <= cols and grid[neighborPos.r][neighborPos.c].isOccupied then
					local neighborId = grid[neighborPos.r][neighborPos.c].pieceId
					if pieceIdMap[neighborId] then
						local neighborPiece = pieceIdMap[neighborId]
						if themeConfig.generation.force_straight_corridor and piece.type == "Room" and neighborPiece.type == "Room" then
							-- No hacer nada
						else
							local neighborTemplateName = neighborPiece.name
							if string.find(neighborTemplateName, "Room_") then neighborTemplateName = "Room" end
							if TEMPLATES[neighborTemplateName] and TEMPLATES[neighborTemplateName].exits[NEIGH[dir].opp] then
								finalDoors[dir] = true
							end
						end
					end
				end
			end
			piece.doors = finalDoors
			table.insert(finalLayout, piece)
		end
	end

	return finalLayout, grid, pieceIdMap
end

return MapGenerator
