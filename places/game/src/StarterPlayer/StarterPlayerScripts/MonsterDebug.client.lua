-- MonsterDebug.client.lua
-- LocalScript for debugging monster AI
-- Adds a toggle button to the lower right corner of the screen to show/hide monster vision cones

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create ScreenGui and Toggle Button
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MonsterDebugGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "DebugToggleButton"
toggleButton.Size = UDim2.new(0, 120, 0, 40)
toggleButton.Position = UDim2.new(1, -130, 1, -50)
toggleButton.AnchorPoint = Vector2.new(0, 0)
toggleButton.Text = "Debug: OFF"
toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.Parent = screenGui

toggleButton.MouseButton1Click:Connect(function()
    local enabled = toggleButton.Text == "Debug: OFF"
    toggleButton.Text = enabled and "Debug: ON" or "Debug: OFF"
    ReplicatedStorage:FindFirstChild("MonsterDebugEvent"):FireServer(enabled)
end)

-- Listen for vision cone drawing (to be implemented)
-- You can update this script to draw cones using BillboardGui or other primitives
