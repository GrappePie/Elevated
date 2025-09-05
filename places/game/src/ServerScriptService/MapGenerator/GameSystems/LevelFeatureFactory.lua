-- ModuleScript: LevelFeatureFactory
-- Construye características de nivel específicas, como puertas de salida.

local LevelFeatureFactory = {}

-- Función auxiliar para crear partes rápidamente
local function createPart(props)
	local part = Instance.new("Part")
	part.Name = props.Name or "Part"
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color
	part.Material = props.Material or Enum.Material.Metal
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.Parent
	if props.Shape then part.Shape = props.Shape end
	part.CanCollide = props.CanCollide or false -- Por defecto, las partes son decorativas
	return part
end

--================================================================
--=                  FUNCIÓN PARA CREAR LA PUERTA                =
--================================================================
function LevelFeatureFactory.createExitDoor_ToLevel1(config)
	local doorModel = Instance.new("Model")
	doorModel.Name = "SalidaNivel1_Generated"

	local WALL_HEIGHT = config.WALL_HEIGHT or 16
	local doorWidth = 8 
	local doorHeight = WALL_HEIGHT * 0.7

	-- 1. El marco principal de la puerta
	local frame = createPart({
		Name = "Frame",
		Size = Vector3.new(doorWidth + 1, doorHeight + 1, 0.5),
		CFrame = CFrame.new(),
		Color = Color3.fromRGB(80, 80, 80),
		Parent = doorModel,
		CanCollide = true -- El marco sí debe colisionar
	})
	-- El marco es la parte principal para posicionar el modelo
	doorModel.PrimaryPart = frame

	-- 2. La puerta (roja)
	local door = createPart({
		Name = "Door",
		Size = Vector3.new(doorWidth, doorHeight, 0.4),
		CFrame = frame.CFrame * CFrame.new(0, 0, 0.1),
		Color = Color3.fromRGB(190, 40, 40),
		Parent = doorModel,
		CanCollide = true -- La puerta debe colisionar para que el evento .Touched funcione
	})

	-- 3. La barra horizontal para empujar
	createPart({
		Name = "PushBar",
		Size = Vector3.new(doorWidth * 0.8, 0.5, 0.2),
		CFrame = door.CFrame * CFrame.new(0, 0, 0.3),
		Color = Color3.fromRGB(180, 180, 180),
		Parent = doorModel
	})

	-- 4. La placa metálica en la base
	createPart({
		Name = "KickPlate",
		Size = Vector3.new(doorWidth, doorHeight * 0.1, 0.2),
		CFrame = door.CFrame * CFrame.new(0, -doorHeight/2 + (doorHeight * 0.05), 0.3),
		Color = Color3.fromRGB(150, 150, 150),
		Material = Enum.Material.DiamondPlate,
		Parent = doorModel
	})

	-- 5. La perilla/manija
	createPart({
		Name = "Handle",
		Size = Vector3.new(1, 0.8, 0.8),
		CFrame = door.CFrame * CFrame.new(doorWidth/2 - 1, 0, 0.3) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 200, 200),
		Shape = Enum.PartType.Cylinder,
		Parent = doorModel
	})

	-- 6. El letrero "EXIT"
	local sign = createPart({
		Name = "Sign",
		Size = Vector3.new(doorWidth * 0.8, doorHeight * 0.15, 0.2),
		CFrame = frame.CFrame * CFrame.new(0, frame.Size.Y/2 + 1, 0),
		-- Usamos un color más oscuro para que el neón no sea tan brillante
		Color = Color3.fromRGB(180, 180, 180), 
		Material = Enum.Material.Neon,
		Parent = doorModel
	})

	local gui = Instance.new("SurfaceGui", sign)
	-- La cara 'Back' se ve correctamente desde el frente cuando el modelo se rota
	gui.Face = Enum.NormalId.Back 
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50

	local label = Instance.new("TextLabel", gui)
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "EXIT"
	label.Font = Enum.Font.SourceSansBold
	label.TextColor3 = Color3.fromRGB(10, 10, 10)
	label.TextScaled = true

	return doorModel
end

return LevelFeatureFactory
