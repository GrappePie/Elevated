-- Made by @Purple
local API = {
	config = {
		ConeCompensation = 2,
	},
}
API.__index = API

type Scalar2D3DConfig = {
	["HeightMin"] : number,
	["HeightMax"] : number,
	["MagnitudeXZ"] : number,
	["ConeAngle"] : number,
	["Origin"] : Vector3,
	["LookVector"] : Vector3,
	["CheckPos"] : Vector3,
}

type PseudoRegionConfig = {
	["CFrame"] : CFrame,
	["Position"] : Vector3?,
	["Size"] : Vector3,
}

function API.new()
	local self = {}
	return setmetatable(self, API)
end

function API:BuildConfig(HeightMin: number, HeightMax: number, MagnitudeXZ: number, ConeAngle: number, LookVector: Vector3, Origin: Vector3, CheckPos: Vector3) : Scalar2D3DConfig
	return {
		HeightMin = HeightMin,
		HeightMax = HeightMax,
		MagnitudeXZ = MagnitudeXZ,
		ConeAngle = ConeAngle,
		LookVector = LookVector,
		Origin = Origin,
		CheckPos = CheckPos,
	}
end

function API:GetPseudoRegion(_CFrame: CFrame, Position: Vector3?, Size: Vector3, Visualize: boolean?, VisualDebrisTime: number?) : PseudoRegionConfig
	local PseudoContstruct = {
		["CFrame"] = _CFrame,
		["Position"] = Position,
		["Size"] = Size,
	}

	local _Meta = {
		__index = function(t,i)
			if (i == "Position" or i == "P" or i == "p") and t["CFrame"] then
				t[i] = t.CFrame.Position
				warn(debug.traceback(),`Issues with indexing {i}, backup from {"CFrame"} value`, `table {t}`)
				return t[i]
			end

			if i == "CFrame" and t["Position"] then
				t[i] = CFrame.new(t.Position)
				warn(debug.traceback(),`Issues with indexing {i}, backup from {"Position"} value`, `table {t}`)
				return t[i]
			end

			if i == "Size" then
				t[i] = Vector3.new(1,1,1)
				warn(debug.traceback(),`Issues with indexing {i}, backup to {Vector3.new(1,1,1)} value`, `table {t}`)
				return t[i]
			end

			warn(`Unknown issue with table {t}, and index {i}`, debug.traceback())
		end
	}
	
	if Visualize then
		local VisualBox = Instance.new("Part")
		
		VisualBox.Anchored = true
		VisualBox.Transparency = .5
		VisualBox.Color = BrickColor.random().Color
		VisualBox.CFrame = PseudoContstruct.CFrame
		VisualBox.Size = PseudoContstruct.Size
		VisualBox.CanCollide = false
		VisualBox.CanQuery = false
		
		VisualBox.Parent = workspace.Hitboxes
		
		task.delay(VisualDebrisTime or .5, function()
			if VisualBox and VisualBox.Parent then
				VisualBox:Destroy()
			end
		end)
	end
	
	return setmetatable(PseudoContstruct, _Meta)
end

function API:CalculateHitsInPseudoRegion(PseudoRegion: PseudoRegionConfig, CheckPos: Vector3)
	local ObjSpacePos = PseudoRegion.CFrame:PointToObjectSpace(CheckPos)
	local PseudoX, PseudoY, PseudoZ = PseudoRegion.Size.X/2, PseudoRegion.Size.Y/2, PseudoRegion.Size.Z/2
	
	if math.abs(ObjSpacePos.X) <= PseudoX and math.abs(ObjSpacePos.Y) <= PseudoY and math.abs(ObjSpacePos.Z) <= PseudoZ then
		return true
	end
	
	return false
end

function API:FastMagnitudeVec2XY(a: Vector3, b: Vector3)
	return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2)
end

function API:FastMagnitudeVec2XZ(a: Vector3, b: Vector3)
	return math.sqrt((a.X-b.X)^2+(a.Z-b.Z)^2)
end

function API:FastMagnitudeVec3(a: Vector3, b: Vector3)
	return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)
end

function API:GetUnitVector(a: Vector3, b: Vector3)
	return (a-b).Unit
end

function API:CalculateDotScalar(coneAngle:Vector3, mainPos: Vector3, checkPos: Vector3, lookVector: Vector3)
	local UnitVectorBetweenPositions = self:GetUnitVector(checkPos,mainPos)
	local dotScalar = UnitVectorBetweenPositions:Dot(lookVector)

	if dotScalar >= math.cos(math.rad((coneAngle+(self.config.ConeCompensation)))) then
		return true
	end

	return false
end

function API:CalculateScalarBounds2D3D(config:Scalar2D3DConfig)
	local HeightCheck = config.CheckPos.Y-config.Origin.Y

	if (HeightCheck >= config.HeightMin and HeightCheck <= config.HeightMax) and self:FastMagnitudeVec2XZ(config.CheckPos, config.Origin) <= config.MagnitudeXZ then
		return self:CalculateDotScalar(config.ConeAngle, config.Origin, config.CheckPos, config.LookVector)
	end
	
	return false
end

return API
