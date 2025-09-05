-- MonsterDebugEvent for toggling debug mode
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not ReplicatedStorage:FindFirstChild("MonsterDebugEvent") then
    local event = Instance.new("RemoteEvent")
    event.Name = "MonsterDebugEvent"
    event.Parent = ReplicatedStorage
end
