-- ModuleScript: MapConfig
-- Define los parámetros para cada perfil de generación de mapas.

local MapConfig = {}

--[[
	Cada perfil tiene dos secciones:
	- generation: Reglas que usa MapGenerator.lua para decidir la forma del mapa.
	- construction: Parámetros que usa MapBuilderHelpers.lua para construir visualmente el mapa.
]]

MapConfig.Laberinto = {
	generation = {
		-- Perfil por defecto, no necesita reglas especiales.
	},

	construction = {
		CELL_SIZE = 12,
		ALTURA_PISO = 1,
		ALTURA_PARED = 16,
		GROSOR_PARED = 1,
		PASILLO_ANCHO = 8,

		COLOR_PARED_BAJA = Color3.fromRGB(80, 80, 90), -- Tonos más grises y oscuros
		COLOR_PARED_ALTA = Color3.fromRGB(150, 150, 160),
		COLOR_MARCO_PUERTA = Color3.fromRGB(50, 50, 60),
		COLOR_PISO_NUEVO = Color3.fromRGB(100, 100, 100),
		MATERIAL_PISO = Enum.Material.Concrete,
		RATIO_PINTURA = 0.5,
	}
}

MapConfig.Departamentos = {
	generation = {
		force_straight_corridor = 6, -- Intentará crear un pasillo de al menos 6 piezas de largo
		isApartmentWing = false, -- Variable interna, no tocar
	},

	construction = {
		CELL_SIZE = 30,      -- Aumentado de 18 a 30 para hacer todo más grande.
		ALTURA_PISO = 0.5,
		ALTURA_PARED = 14,
		GROSOR_PARED = 0.8,
		PASILLO_ANCHO = 10,   -- Pasillos principales más anchos

		COLOR_PARED_BAJA = Color3.fromRGB(45, 117, 98),
		COLOR_PARED_ALTA = Color3.fromRGB(225, 220, 205),
		COLOR_MARCO_PUERTA = Color3.fromRGB(35, 90, 75),
		COLOR_PISO_NUEVO = Color3.fromRGB(150, 150, 150),
		MATERIAL_PISO = Enum.Material.Concrete,
		RATIO_PINTURA = 0.4,

		-- [[ Parámetros para la franja/zócalo ]]
		COLOR_FRANJA_PISO = Color3.fromRGB(143, 57, 31), -- Marrón rojizo para la franja perimetral
		ALTURA_FRANJA_PISO = 0.01, -- Altura de la franja sobre el piso
	}
}

MapConfig["Backrooms (level 0)"] = {
	generation = {
		type = "Infinite",
		CHUNK_SIZE = 16,
		generatorScript = "BackroomsLvl0",
		renderDistanceHor = 1 -- [[ AÑADIR ESTA LÍNEA: Distancia corta para el laberinto ]]
	},
	construction = {
		CELL_SIZE = 24,
		WALL_HEIGHT = 16,
		decals = {
			wall = "9302433623",
			floor = "9302607585",
			roof = "9302641078"
		},
		-- [[ NUEVO CAMPO PARA SONIDO AMBIENTAL ]]
		ambienceId = {"136413104247411"}, -- El ID del zumbido

		-- Dejamos la música vacía, ya que el zumbido es nuestro sonido principal
		musicId = nil 
	}
}

MapConfig["Backrooms (level 1)"] = {
	generation = {
		type = "Infinite",
		generatorScript = "BackroomsLvl1",
		CHUNK_SIZE = 10,
		finiteWidth = 4,
		finiteDepth = 4,
		isVerticallyInfinite = true,
		renderDistanceHor = 2, -- [[ AÑADIR ESTA LÍNEA: Mantenemos la distancia larga ]]
		renderDistanceVer = 2  -- [[ AÑADIR ESTA LÍNEA: Mantenemos la distancia vertical ]]
	},
	construction = {
		CELL_SIZE = 25,
		WALL_HEIGHT = 15,
		decals = {
			wall = "4733449553",
			floor = "1139802847",
			roof = "5236283959",
			ramp = "863273133"
		},
		ambienceId = {"72182656246843", "137320570572871"},
		musicId = nil 
	}
}
return MapConfig