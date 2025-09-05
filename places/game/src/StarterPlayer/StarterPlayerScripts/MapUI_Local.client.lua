-- LocalScript en StarterPlayer.StarterPlayerScripts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MapConfig = require(ReplicatedStorage:WaitForChild("MapConfig"))
-- Carpeta de eventos en ReplicatedStorage
local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local generateEvent = eventsFolder:WaitForChild("GenerateMapEvent")
-- [[ NUEVO: Referencia al evento que esperaremos ]]
local initialChunksLoadedEvent = eventsFolder:WaitForChild("InitialChunksLoadedEvent")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MapGeneratorUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local fadeFrame = Instance.new("Frame", screenGui)
fadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
fadeFrame.BorderSizePixel = 0
fadeFrame.Size = UDim2.new(1, 0, 1, 0)
fadeFrame.Position = UDim2.new(0, 0, 0, 0)
fadeFrame.ZIndex = 100
fadeFrame.BackgroundTransparency = 1
fadeFrame.Visible = false

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 200, 0, 120)
mainFrame.Position = UDim2.new(0, 20, 0, 50)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BackgroundTransparency = 0.2
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = false
local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 8)

local titleLabel = Instance.new("TextLabel", mainFrame)
titleLabel.Size = UDim2.new(1, -20, 0, 30)
titleLabel.Position = UDim2.new(0, 10, 0, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.Text = "Generador de Mapas"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextSize = 16
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

local selectedProfile = "Departamentos"
local dropdownButton = Instance.new("TextButton", mainFrame)
dropdownButton.Size = UDim2.new(1, -20, 0, 30)
dropdownButton.Position = UDim2.new(0, 10, 0, 40)
dropdownButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
dropdownButton.Font = Enum.Font.SourceSans
dropdownButton.Text = selectedProfile
dropdownButton.TextColor3 = Color3.new(1, 1, 1)
dropdownButton.TextSize = 14
local cornerDrop = Instance.new("UICorner", dropdownButton)
cornerDrop.CornerRadius = UDim.new(0, 4)

local optionsFrame = Instance.new("ScrollingFrame", mainFrame)
optionsFrame.Size = UDim2.new(1, -20, 0, 100)
optionsFrame.Position = UDim2.new(0, 10, 0, 75)
optionsFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
optionsFrame.BorderSizePixel = 0
optionsFrame.Visible = false
optionsFrame.ZIndex = 5
optionsFrame.ClipsDescendants = true
optionsFrame.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
optionsFrame.ScrollBarThickness = 8
local listLayout = Instance.new("UIListLayout", optionsFrame)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 5)

local generateButton = Instance.new("TextButton", mainFrame)
generateButton.Size = UDim2.new(1, -20, 0, 30)
generateButton.Position = UDim2.new(0, 10, 0, 80)
generateButton.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
generateButton.Font = Enum.Font.SourceSansBold
generateButton.Text = "Generar Mapa"
generateButton.TextColor3 = Color3.new(1, 1, 1)
generateButton.TextSize = 16
local cornerGen = Instance.new("UICorner", generateButton)
cornerGen.CornerRadius = UDim.new(0, 4)

for profileName, _ in pairs(MapConfig) do
	local optionButton = Instance.new("TextButton", optionsFrame)
	optionButton.Size = UDim2.new(1, 0, 0, 25)
	optionButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	optionButton.BackgroundTransparency = 1
	optionButton.Font = Enum.Font.SourceSans
	optionButton.Text = profileName
	optionButton.TextColor3 = Color3.new(1, 1, 1)
	optionButton.TextSize = 14
	optionButton.ZIndex = 6

	optionButton.MouseEnter:Connect(function() optionButton.BackgroundTransparency = 0.8 end)
	optionButton.MouseLeave:Connect(function() optionButton.BackgroundTransparency = 1 end)

	optionButton.MouseButton1Click:Connect(function()
		selectedProfile = optionButton.Text
		dropdownButton.Text = selectedProfile
		optionsFrame.Visible = false
	end)
end

dropdownButton.MouseButton1Click:Connect(function()
	optionsFrame.Visible = not optionsFrame.Visible
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if not optionsFrame.Visible then return end
		local mousePos = UserInputService:GetMouseLocation()
		local framePos = optionsFrame.AbsolutePosition
		local frameSize = optionsFrame.AbsoluteSize
		if not (mousePos.X > framePos.X and mousePos.X < framePos.X + frameSize.X and mousePos.Y > framePos.Y and mousePos.Y < framePos.Y + frameSize.Y) then
			optionsFrame.Visible = false
		end
	end
end)

local function fade(fadeIn)
	fadeFrame.Visible = true
	local goal = { BackgroundTransparency = (fadeIn and 1 or 0) }
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad)
	local tween = TweenService:Create(fadeFrame, tweenInfo, goal)
	tween:Play()
	tween.Completed:Wait()
	if fadeIn then fadeFrame.Visible = false end
end

generateButton.MouseButton1Click:Connect(function()
	if optionsFrame.Visible then optionsFrame.Visible = false; return end

	fade(false)

	-- Revisa la configuración del perfil para saber cómo actuar
	local profileConfig = MapConfig[selectedProfile]
	local seed = (profileConfig and profileConfig.generation and profileConfig.generation.seed) or Players.LocalPlayer.UserId

	local success, result = pcall(function()
		return generateEvent:InvokeServer(selectedProfile, seed)
	end)

	if success then
		local startPosition = result
		if startPosition then
			local player = Players.LocalPlayer
			local character = player.Character or player.CharacterAdded:Wait()
			local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
			task.wait(0.1)
			character:PivotTo(CFrame.new(startPosition))

			-- [[ INICIO DE LA LÓGICA DE ESPERA ]]
			-- Si el perfil es de tipo "Noise", esperamos la señal del servidor.
			if profileConfig and profileConfig.generation.type == "Noise" then
				print("Esperando la carga de chunks iniciales del servidor...")
				initialChunksLoadedEvent.OnClientEvent:Wait() -- Pausa el script aquí hasta recibir la señal
				print("¡Señal recibida! Mostrando el mundo.")
			end
			-- Si no es de tipo "Noise", no hace nada y el fade(true) se ejecuta inmediatamente.
			-- [[ FIN DE LA LÓGICA DE ESPERA ]]

		else
			warn("El servidor completó la generación pero no devolvió una posición de inicio.")
		end
	else
		warn("Ocurrió un error en el servidor al generar el mapa:", result)
	end

	-- Quita la pantalla negra después de que todo esté listo.
	fade(true) 
end)
