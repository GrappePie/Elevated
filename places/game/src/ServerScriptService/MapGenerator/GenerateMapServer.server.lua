-- Script en ServerScriptService
-- VERSIÓN FINAL: Simplificado para delegar toda la lógica de generación.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))

-- --- CONFIGURACIÓN DE OBJETOS REMOTOS ---
-- Se asegura de que los eventos existan para evitar errores.

-- Asegura que exista la carpeta de eventos en ReplicatedStorage
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder or not eventsFolder:IsA("Folder") then
	if eventsFolder then eventsFolder:Destroy() end
	eventsFolder = Instance.new("Folder", ReplicatedStorage)
	eventsFolder.Name = "Events"
end
local generateEventName = "GenerateMapEvent"
local generateEvent = eventsFolder:FindFirstChild(generateEventName)
if not generateEvent or not generateEvent:IsA("RemoteFunction") then
	if generateEvent then generateEvent:Destroy() end
	generateEvent = Instance.new("RemoteFunction", eventsFolder)
	generateEvent.Name = generateEventName
end

local initialLoadEventName = "InitialChunksLoadedEvent"
local initialChunksLoadedEvent = ReplicatedStorage:FindFirstChild(initialLoadEventName)
if not initialChunksLoadedEvent or not initialChunksLoadedEvent:IsA("RemoteEvent") then
	if initialChunksLoadedEvent then initialChunksLoadedEvent:Destroy() end
	initialChunksLoadedEvent = Instance.new("RemoteEvent", ReplicatedStorage)
	initialChunksLoadedEvent.Name = initialLoadEventName
end


-- Función que se ejecuta cuando un cliente la invoca
local function onGenerateRequest(player, themeName)
	print("Petición recibida de", player.Name, "para generar el tema:", themeName)

	-- Llama al MapBuilder para que haga todo el trabajo.
	-- Ya no necesitamos controlar otros scripts desde aquí.
	local startPosition = MapBuilder.Generate(themeName)

	if startPosition then
		print("Mapa '"..themeName.."' generado. Posición de inicio:", startPosition)
	else
		warn("MapBuilder no devolvió una posición de inicio para el tema:", themeName)
	end

	-- Devuelve la posición de inicio al cliente que la pidió
	return startPosition
end

-- Conectar la función al evento
generateEvent.OnServerInvoke = onGenerateRequest

print("Servidor de generación de mapas listo y escuchando peticiones.")