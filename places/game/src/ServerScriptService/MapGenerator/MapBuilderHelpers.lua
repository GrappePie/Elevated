-- ModuleScript: MapBuilderHelpers
-- Actúa como un orquestador que utiliza otros módulos para construir y decorar.

local Helpers = {}

-- Cargar los nuevos módulos especializados
local PieceBuilders = require(script.Parent:WaitForChild("PieceBuilders"))
local PropFactory = require(script.Parent:WaitForChild("PropFactory"))

-- Lógica de colocación de props (se queda aquí porque depende de la pieza recién creada)
-- Esta función reordena una lista de forma aleatoria.
local function shuffleTable(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end
-- Lógica de colocación de props (se queda aquí porque depende de la pieza recién creada)
local function getPropPlacement(pieceModel, recipe)
	-- Paso 2: Usar la función de barajar
	-- Ahora, cada vez que se llame, el orden de las paredes será diferente.
	local wallPreferences = shuffleTable({"N", "E", "S", "W"})

	for _, wallDir in ipairs(wallPreferences) do
		if not recipe.doors[wallDir] then
			for _, child in ipairs(pieceModel:GetChildren()) do
				if child:IsA("Model") and child.Name == "WallSegment" and child:GetAttribute("WallDirection") == wallDir then
					local wallPart = child:FindFirstChildWhichIsA("BasePart")
					if wallPart then
						return {
							wallCFrame = wallPart.CFrame,
							inwardNormal = -wallPart.CFrame.LookVector,
							wallLength = wallPart.Size.X
						}
					end
				end
			end
		end
	end
	return nil
end

-----------------------------------------------------------------------------
-- Funciones Públicas del Módulo
-----------------------------------------------------------------------------

-- Función principal que orquesta la creación de una pieza completa.
function Helpers.createPiece(parent, recipe, config)
	local model = Instance.new("Model")
	model.Name = "ProceduralPiece"
	model.Parent = parent

	-- 1. Delegar la construcción de la geometría al módulo PieceBuilders
	if recipe.type == "Room" then
		PieceBuilders.buildRoom(model, recipe, config)
	elseif recipe.type == "Shape" then
		PieceBuilders.buildShape(model, recipe, config)
	end

	-- Establecer la parte primaria del modelo
	if not model.PrimaryPart and model:GetChildren()[1] then
		local firstChild = model:GetChildren()[1]
		if firstChild:IsA("BasePart") then model.PrimaryPart = firstChild
		elseif firstChild:IsA("Model") and firstChild.PrimaryPart then model.PrimaryPart = firstChild.PrimaryPart end
	end

	-- 2. Decidir si se añaden adornos y delegar su creación a PropFactory
	if recipe.type == "Room" and math.random() < 0.4 then
		local placement = getPropPlacement(model, recipe)
		if placement then
			local propFunctions = {PropFactory.createElectricalPanel, PropFactory.createMailboxes, PropFactory.createSovietSign}
			local chosenPropFunc = propFunctions[math.random(#propFunctions)]

			local randomHorizontalOffset = (math.random() - 0.5) * (placement.wallLength * 0.8)
			local randomVerticalOffset = math.random(2, 5) - (config.ALTURA_PARED / 2)

			local basePropCFrame = placement.wallCFrame * CFrame.new(randomHorizontalOffset, randomVerticalOffset, 0)

			-- Llamar a la función de creación de props del módulo PropFactory
			chosenPropFunc(model, basePropCFrame, placement.inwardNormal)
		end
	end

	return model
end

-- Función de paso para mantener la compatibilidad con MapBuilder.lua
function Helpers.createCeilingLight(...)
	-- Simplemente llama a la función correspondiente en PropFactory
	return PropFactory.createCeilingLight(...)
end

return Helpers
