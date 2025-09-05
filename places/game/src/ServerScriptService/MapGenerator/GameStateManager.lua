-- ModuleScript: GameStateManager
-- VERSIÓN DÚO-PLAYLIST: Gestiona listas de reproducción para música Y ambiente.

local GameStateManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapConfig = require(ReplicatedStorage:WaitForChild("MapConfig"))

GameStateManager.ActiveMapType = nil

-- ======== CANAL DE MÚSICA ========
local backgroundMusic = Instance.new("Sound")
backgroundMusic.Name = "BackgroundMusic"
backgroundMusic.Volume = 0.5
backgroundMusic.Parent = game.Workspace
local currentMusicPlaylist = nil
local currentMusicIndex = 0

-- ======== CANAL DE AMBIENTE ========
local ambientSound = Instance.new("Sound")
ambientSound.Name = "AmbientSound"
ambientSound.Volume = 0.7
ambientSound.Parent = game.Workspace
local currentAmbiencePlaylist = nil
local currentAmbienceIndex = 0

---------------------------------------------------------------------

-- Función para la playlist de MÚSICA
local function PlayNextMusicTrack()
	if not currentMusicPlaylist then return end

	currentMusicIndex = currentMusicIndex + 1
	if currentMusicIndex > #currentMusicPlaylist then
		currentMusicIndex = 1
	end

	local nextSongId = currentMusicPlaylist[currentMusicIndex]
	print("Reproduciendo track de MÚSICA", currentMusicIndex, "ID:", nextSongId)
	backgroundMusic.SoundId = "rbxassetid://" .. tostring(nextSongId)
	backgroundMusic.Looped = false
	backgroundMusic:Play()
end

-- Función para la playlist de AMBIENTE
local function PlayNextAmbienceTrack()
	if not currentAmbiencePlaylist then return end

	currentAmbienceIndex = currentAmbienceIndex + 1
	if currentAmbienceIndex > #currentAmbiencePlaylist then
		currentAmbienceIndex = 1
	end

	local nextSoundId = currentAmbiencePlaylist[currentAmbienceIndex]
	print("Reproduciendo sonido de AMBIENTE", currentAmbienceIndex, "ID:", nextSoundId)
	ambientSound.SoundId = "rbxassetid://" .. tostring(nextSoundId)
	ambientSound.Looped = false
	ambientSound:Play()
end

-- Conectamos cada reproductor a su respectiva función de playlist
backgroundMusic.Ended:Connect(PlayNextMusicTrack)
ambientSound.Ended:Connect(PlayNextAmbienceTrack)


function GameStateManager.SetActiveMapType(themeName)
	if GameStateManager.ActiveMapType == themeName then return end
	print("Cambiando estado del mapa a:", themeName)
	GameStateManager.ActiveMapType = themeName

	-- Detenemos todo y reseteamos variables
	backgroundMusic:Stop()
	ambientSound:Stop()
	currentMusicPlaylist = nil
	currentMusicIndex = 0
	currentAmbiencePlaylist = nil
	currentAmbienceIndex = 0

	local config = MapConfig[themeName]
	if not config or not config.construction then
		return 
	end

	-- ===== LÓGICA PARA AMBIENTE (AHORA CON PLAYLIST) =====
	if config.construction.ambienceId then
		local ambienceData = config.construction.ambienceId

		if type(ambienceData) == "table" then
			-- Si es una tabla, es una playlist
			print("Playlist de ambiente detectada para '"..themeName.."'")
			currentAmbiencePlaylist = ambienceData
			PlayNextAmbienceTrack()
		elseif (type(ambienceData) == "string" or type(ambienceData) == "number") and tostring(ambienceData) ~= "" then
			-- Si es un solo ID, es un bucle simple
			print("Sonido ambiental único detectado para '"..themeName.."'")
			ambientSound.SoundId = "rbxassetid://" .. tostring(ambienceData)
			ambientSound.Looped = true
			ambientSound:Play()
		end
	end

	-- ===== LÓGICA PARA MÚSICA (SIN CAMBIOS) =====
	if config.construction.musicId then
		local musicData = config.construction.musicId
		if type(musicData) == "table" then
			print("Playlist de música detectada para el mapa '"..themeName.."'")
			currentMusicPlaylist = musicData
			PlayNextMusicTrack() 
		elseif (type(musicData) == "string" or type(musicData) == "number") and tostring(musicData) ~= "" then
			print("Un solo track de música detectado para el mapa '"..themeName.."'")
			backgroundMusic.SoundId = "rbxassetid://" .. tostring(musicData)
			backgroundMusic.Looped = true
			backgroundMusic:Play()
		end
	end
end

return GameStateManager