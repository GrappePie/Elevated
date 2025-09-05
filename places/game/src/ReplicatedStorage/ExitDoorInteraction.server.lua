-- Este script se coloca dentro del modelo de la puerta de salida.
-- Se encarga de teletransportar al jugador al siguiente nivel.

local doorModel = script.Parent
local primaryPart = doorModel.PrimaryPart
if not primaryPart then return end

local debounce = false

-- [[ CORRECCIÓN ]]
-- En lugar de una ruta fija, buscamos el módulo "MapBuilder" en cualquier parte
-- dentro de ServerScriptService. Esto es mucho más seguro.
local MapBuilderModule = game:GetService("ServerScriptService"):FindFirstChild("MapBuilder", true)

-- Verificamos si se encontró el módulo antes de requerirlo.
if not MapBuilderModule then
	warn("ExitDoorInteraction: No se pudo encontrar el módulo 'MapBuilder' en ServerScriptService.")
	return
end

local MapBuilder = require(MapBuilderModule)

primaryPart.Touched:Connect(function(hit)
	if debounce then return end

	local player = game.Players:GetPlayerFromCharacter(hit.Parent)
	if not player then return end

	debounce = true
	print("Jugador", player.Name, "ha encontrado una salida.")

	local targetLevel = "Backrooms (level 1)"

	local startPosition = MapBuilder.Generate(targetLevel)

	if startPosition and player.Character then
		player.Character:SetPrimaryPartCFrame(CFrame.new(startPosition))
	end

	task.wait(2)
	debounce = false
end)
