local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Ensure the RemoteEvent exists once on the server
local SprintEvent = ReplicatedStorage:FindFirstChild("PlayerSprintEvent")
if not SprintEvent then
	SprintEvent = Instance.new("RemoteEvent")
	SprintEvent.Name = "PlayerSprintEvent"
	SprintEvent.Parent = ReplicatedStorage
	print("[SprintServer] Created ReplicatedStorage.PlayerSprintEvent")
end

-- Server-authoritative limits
local MIN_SPEED = 5
local MAX_SPEED = 50

-- Simple anti-spam
local REQUEST_COOLDOWN = 0.08
local lastRequest: { [number]: number } = {}

-- Optional bookkeeping
local playerSpeed: { [number]: number } = {}

local function applySpeed(player: Player, speed: number)
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

SprintEvent.OnServerEvent:Connect(function(player, targetSpeed)
	if typeof(targetSpeed) ~= "number" then return end

	local now = tick()
	local last = lastRequest[player.UserId] or 0
	if now - last < REQUEST_COOLDOWN then return end
	lastRequest[player.UserId] = now

	local clamped = math.clamp(targetSpeed, MIN_SPEED, MAX_SPEED)
	playerSpeed[player.UserId] = clamped

	-- Server applies authoritative value
	applySpeed(player, clamped)

	-- Echo back so client eases to the exact server-approved value
	pcall(function()
		SprintEvent:FireClient(player, clamped)
	end)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid", 5)
		if hum then
			hum.WalkSpeed = 16 -- default Roblox speed
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playerSpeed[player.UserId] = nil
	lastRequest[player.UserId] = nil
end)
