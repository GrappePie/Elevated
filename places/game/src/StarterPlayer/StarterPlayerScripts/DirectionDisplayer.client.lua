-- LocalScript: DirectionDisplayer
-- Ubicación: StarterPlayer > StarterPlayerScripts

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local localPlayer = Players.LocalPlayer

-- Modelos objetivo
local TARGET_PROP_NAMES = {
	["ElectricalPanel"] = true,
	["Mailboxes"]      = true,
	["SovietSign"]     = true,
}

-- Mapas de nombre legible
local DIRECTION_NAMES = {
	N = "Norte",
	S = "Sur",
	E = "Este",
	W = "Oeste",
}

-- Vectores cardinales para cálculo de orientación
local CARDINAL_VECTORS = {
	N = Vector3.new( 0, 0, -1),
	S = Vector3.new( 0, 0,  1),
	E = Vector3.new( 1, 0,  0),
	W = Vector3.new(-1, 0,  0),
}

-- Intenta obtener un BasePart de anclaje
local function getAnchorPart(model)
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

-- Determina la pared más cercana al prop
local function getWallDirectionFromProp(prop)
	local anchor = getAnchorPart(prop)
	if not anchor then return nil end

	local pos = anchor.Position
	local closest, bestDist = nil, math.huge

	for _, piece in ipairs(Workspace:GetChildren()) do
		if piece:IsA("Model") and piece.Name == "ProceduralPiece" then
			for _, part in ipairs(piece:GetChildren()) do
				if part:IsA("BasePart") and part:GetAttribute("WallDirection") then
					local d = (pos - part.Position).Magnitude
					if d < bestDist then
						bestDist, closest = d, part
					end
				end
			end
		end
	end

	return closest and closest:GetAttribute("WallDirection") or nil
end

-- A partir de un LookVector, devuelve la dirección cardinal
local function getFacingDirectionFromVector(vec)
	local bestDir, bestDot = "N", -math.huge
	for dir, cvec in pairs(CARDINAL_VECTORS) do
		local d = vec:Dot(cvec)
		if d > bestDot then
			bestDot, bestDir = d, dir
		end
	end
	return bestDir
end

-- Crea el BillboardGui con nombre, pared y orientación
local function createDirectionLabel(prop)
	if prop:FindFirstChild("DirectionGui") then return end

	-- Intento de anclaje; si no está aún, reintento luego
	local anchor = getAnchorPart(prop)
	if not anchor then
		task.delay(0.1, function()
			createDirectionLabel(prop)
		end)
		return
	end

	-- Pared donde está
	local wallDir = getWallDirectionFromProp(prop)
	if not wallDir then
		warn("No encontré pared cercana para "..prop.Name)
		return
	end

	-- Hacia dónde mira
	local lookVec   = anchor.CFrame.LookVector
	local facingDir = getFacingDirectionFromVector(lookVec)

	-- Nombres legibles
	local wallName   = DIRECTION_NAMES[wallDir]   or wallDir
	local facingName = DIRECTION_NAMES[facingDir] or facingDir

	-- Construcción del GUI
	local gui = Instance.new("BillboardGui")
	gui.Name        = "DirectionGui"
	gui.Adornee     = anchor
	gui.Size        = UDim2.new(0,200,0,60)
	gui.StudsOffset = Vector3.new(0,4,0)
	gui.AlwaysOnTop = true

	local lbl = Instance.new("TextLabel", gui)
	lbl.Size                   = UDim2.fromScale(1,1)
	lbl.BackgroundColor3       = Color3.new(0,0,0)
	lbl.BackgroundTransparency = 0.4
	lbl.TextStrokeColor3       = Color3.new(0,0,0)
	lbl.TextStrokeTransparency = 0
	lbl.Font                   = Enum.Font.SourceSansBold
	lbl.TextSize               = 18
	lbl.TextColor3             = Color3.fromRGB(255,255,0)
	lbl.TextYAlignment         = Enum.TextYAlignment.Top

	lbl.Text = 
		prop.Name .. "\n" ..
		"Pared: "    .. wallName   .. "\n" ..
		"Mira hacia: " .. facingName

	-- Parent al PlayerGui para que sea visible
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	print("→ Etiqueta añadida en "..prop.Name.." | Pared: "..wallDir.." | Mira: "..facingDir)
end

-- Etiquetar todos los props existentes
for _, inst in ipairs(Workspace:GetDescendants()) do
	if inst:IsA("Model") and TARGET_PROP_NAMES[inst.Name] then
		createDirectionLabel(inst)
	end
end

-- Etiquetar props que aparezcan en el futuro
Workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("Model") and TARGET_PROP_NAMES[inst.Name] then
		task.delay(0.05, function()
			createDirectionLabel(inst)
		end)
	end
end)

print("DirectionDisplayer activo.")
