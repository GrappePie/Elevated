-- ModuleScript: PropFactory
-- Contiene todas las funciones para crear adornos (props) y luces.

local PropFactory = {}
local TweenService = game:GetService("TweenService")

-- Funciones auxiliares (privadas a este módulo)
local function createPart(size, cframe, parent, color, material)
	local part = Instance.new("Part")
	part.Size, part.CFrame, part.Anchored = size, cframe, true
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Material, part.Color, part.Parent = material or Enum.Material.Concrete, color, parent
	return part
end

local function getNormalIdFromVector(part, worldVector)
	local objectVector = part.CFrame:VectorToObjectSpace(worldVector)
	local faces = {
		[Enum.NormalId.Front] = Vector3.new(0, 0, -1), [Enum.NormalId.Back] = Vector3.new(0, 0, 1),
		[Enum.NormalId.Top] = Vector3.new(0, 1, 0), [Enum.NormalId.Bottom] = Vector3.new(0, -1, 0),
		[Enum.NormalId.Right] = Vector3.new(1, 0, 0), [Enum.NormalId.Left] = Vector3.new(-1, 0, 0),
	}
	local bestFace = Enum.NormalId.Front
	local maxDot = -2
	for face, normal in pairs(faces) do
		local dot = objectVector:Dot(normal)
		if dot > maxDot then maxDot = dot; bestFace = face; end
	end
	return bestFace
end

-----------------------------------------------------------------------------
-- Funciones Públicas del Módulo
-----------------------------------------------------------------------------
function PropFactory.createCeilingLight(parent, pieceCFrame, config)
	local lightModel = Instance.new("Model", parent); lightModel.Name = "CeilingLight"
	local fixtureCFrame = pieceCFrame * CFrame.new(0, config.ALTURA_PARED - 1, 0)
	local fixture = createPart(Vector3.new(8, 1, 2), fixtureCFrame, lightModel, Color3.fromRGB(200,200,200), Enum.Material.Metal)
	createPart(Vector3.new(7, 0.5, 0.5), fixtureCFrame, lightModel, Color3.fromRGB(255,255,255), Enum.Material.Neon)

	local pointLight = Instance.new("PointLight", fixture); 
	pointLight.Range = 25; 
	pointLight.Brightness = 0.8
end

function PropFactory.createElectricalPanel(parent, baseCFrame, inwardNormal)
	local panelModel = Instance.new("Model", parent); panelModel.Name = "ElectricalPanel"
	local panelDepth, panelWidth, panelHeight = 1.2, 5, 7
	local finalCFrame = baseCFrame * CFrame.new(inwardNormal * (panelDepth / 2))
	panelModel:PivotTo(finalCFrame)

	local box = createPart(Vector3.new(panelWidth, panelHeight, panelDepth), finalCFrame, panelModel, Color3.fromRGB(105, 108, 112), Enum.Material.Metal)
	panelModel.PrimaryPart = box

	local interior = Instance.new("Model", panelModel); interior.Name = "Interior"
	for _, part in ipairs(interior:GetChildren()) do part.Transparency = 1 end

	createPart(Vector3.new(panelWidth-0.2, panelHeight-0.2, 0.1), finalCFrame * CFrame.new(0,0, -panelDepth/2 + 0.1), interior, Color3.fromRGB(50,50,50))
	for i = 1, 3 do
		createPart(Vector3.new(1, 1.5, 0.8), finalCFrame * CFrame.new((i-2)*1.5, 2, 0), interior, Color3.fromRGB(200,80,80))
		createPart(Vector3.new(0.4, 0.6, 1), finalCFrame * CFrame.new((i-2)*1.5, 1.8, 0), interior, Color3.fromRGB(20,20,20))
	end

	local hinge = Instance.new("Part", panelModel)
	hinge.Name = "Hinge"
	hinge.Size = Vector3.new(0.1, 0.1, 0.1)
	hinge.Transparency = 1
	hinge.Anchored = true
	hinge.CanCollide = false
	hinge.CFrame = finalCFrame * CFrame.new(-panelWidth/2, 0, panelDepth/2)

	local doorDepth = 0.3
	local doorPart = createPart(Vector3.new(panelWidth - 0.4, panelHeight - 0.6, doorDepth), hinge.CFrame * CFrame.new((panelWidth-0.4)/2, 0, 0), panelModel, Color3.fromRGB(125, 128, 132), Enum.Material.Metal)
	local handle = createPart(Vector3.new(0.8, 0.2, 0.2), doorPart.CFrame * CFrame.new(panelWidth/2 - 0.6, 0, doorDepth/2 + 0.1), panelModel, Color3.fromRGB(80, 80, 80), Enum.Material.Metal)

	local doorWeld = Instance.new("WeldConstraint", hinge); doorWeld.Part0 = hinge; doorWeld.Part1 = doorPart
	local handleWeld = Instance.new("WeldConstraint", hinge); handleWeld.Part0 = hinge; handleWeld.Part1 = handle

	local prompt = Instance.new("ProximityPrompt", doorPart)
	prompt.ActionText = "Abrir Panel"; prompt.ObjectText = "Panel Eléctrico"; prompt.MaxActivationDistance = 10

	local isOpen = false
	prompt.Triggered:Connect(function()
		isOpen = not isOpen
		local openAngle = CFrame.Angles(0, math.rad(isOpen and -90 or 0), 0)
		TweenService:Create(hinge, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {CFrame = hinge.CFrame * openAngle}):Play()
		prompt.ActionText = isOpen and "Cerrar Panel" or "Abrir Panel"
		for _, part in ipairs(interior:GetChildren()) do if part.Name ~= "Hinge" then part.Transparency = isOpen and 0 or 1 end end
	end)
end

function PropFactory.createMailboxes(parent, baseCFrame, inwardNormal)
	local mailModel = Instance.new("Model", parent); mailModel.Name = "Mailboxes"
	local boxDepth, numBoxesPerRow, numRows = 2.5, 5, 3
	local finalCFrame = baseCFrame * CFrame.new(inwardNormal * (boxDepth/2))
	mailModel:PivotTo(finalCFrame)

	local frameWidth, frameHeight = (numBoxesPerRow * 3) + 0.5, (numRows * 4) + 0.5
	local mainFrame = createPart(Vector3.new(frameWidth, frameHeight, boxDepth - 0.2), finalCFrame, mailModel, Color3.fromRGB(80, 70, 60), Enum.Material.Metal)
	mailModel.PrimaryPart = mainFrame

	for row = 1, numRows do
		for i = 1, numBoxesPerRow do
			local offsetX, offsetY = (i - (numBoxesPerRow+1)/2) * 3, (row - (numRows+1)/2) * 4
			local boxCFrame = finalCFrame * CFrame.new(offsetX, offsetY, 0)
			local door = createPart(Vector3.new(2.8, 3.8, 0.2), boxCFrame * CFrame.new(0, 0, boxDepth/2), mailModel, Color3.fromRGB(119, 101, 89), Enum.Material.Metal)
			createPart(Vector3.new(1.5, 0.15, 0.25), door.CFrame * CFrame.new(0, 1.2, 0), mailModel, Color3.fromRGB(40, 40, 40))
			local lock = createPart(Vector3.new(0.4, 0.4, 0.3), door.CFrame * CFrame.new(1, 0, 0), mailModel, Color3.fromRGB(192, 192, 192), Enum.Material.Metal); lock.Shape = Enum.PartType.Cylinder
			local gui = Instance.new("SurfaceGui", door); gui.Face = Enum.NormalId.Front; gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; gui.PixelsPerStud = 50
			local label = Instance.new("TextLabel", gui); label.Size = UDim2.fromScale(0.6, 0.3); label.Position = UDim2.fromScale(0.2, -0.4); label.BackgroundTransparency = 1; label.Text = tostring(100 + i + ((row-1) * numBoxesPerRow)); label.Font = Enum.Font.SourceSans; label.TextColor3 = Color3.fromRGB(220, 220, 200); label.TextSize = 18
		end
	end
end

function PropFactory.createSovietSign(parent, baseCFrame, inwardNormal)
	local signModel = Instance.new("Model", parent); signModel.Name = "SovietSign"
	local finalCFrame = baseCFrame * CFrame.new(inwardNormal * 0.1)
	signModel:PivotTo(finalCFrame)

	local paper = createPart(Vector3.new(4, 5, 0.1), finalCFrame, signModel, Color3.fromRGB(240, 230, 200))
	signModel.PrimaryPart = paper
	local possibleTexts = {"NO SMOKING", "KEEP CLEAN", "QUIET HOUR\nFROM 10:00 PM TO 8:00 AM", "CAUTION", "EXIT", "DO NOT ENTER"}
	local chosenText = possibleTexts[math.random(#possibleTexts)]
	local gui = Instance.new("SurfaceGui", paper);
	gui.Face = getNormalIdFromVector(paper, -paper.CFrame.LookVector)
	local label = Instance.new("TextLabel", gui); label.Size = UDim2.fromScale(0.9, 0.9); label.Position = UDim2.fromScale(0.05, 0.05); label.BackgroundTransparency = 1; label.Text = chosenText; label.Font = Enum.Font.SourceSansBold; label.TextColor3 = Color3.fromRGB(20, 20, 20); label.TextSize = 32; label.TextWrapped = true
end

return PropFactory
