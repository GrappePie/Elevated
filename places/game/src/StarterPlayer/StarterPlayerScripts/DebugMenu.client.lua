-- Polished debug menu (draggable, animated, backdrop click-to-close).
-- Uses: MonsterDebugEvent (direct) and DebugToggleEvent(key, enabled).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local ALLOWED_USER_IDS: {[number]: boolean} = {
	[1649598894] = true,
	[1021056267] = true,
	[3454147180] = true,
}

local ALLOWED_ROLES: {[string]: boolean} = {
	Developer = true,
}

local function isAuthorized(player: Player): boolean
	if ALLOWED_USER_IDS[player.UserId] then
	        return true
	end
	local role = player:GetAttribute("Role")
	if role and ALLOWED_ROLES[role] then
	        return true
	end
	return false
end

if not isAuthorized(localPlayer) then
	return
end

local playerGui = localPlayer:WaitForChild("PlayerGui")

----------------------------------------------------------------------
-- Remotes
----------------------------------------------------------------------
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
local function getRemote(name)
        -- Search in ReplicatedStorage or ReplicatedStorage.Events
        return ReplicatedStorage:FindFirstChild(name) or (eventsFolder and eventsFolder:FindFirstChild(name))
end

local function toFlagName(key: string): string
	local flagName = key:gsub("_(%w)", function(s)
		return s:upper()
	end)
	return flagName:sub(1,1):upper() .. flagName:sub(2)
end

local initialFlags: {[string]: boolean} = {}
do
	local getFlags = getRemote("GetDebugFlags")
	if getFlags then
		local ok, result = pcall(function()
			return getFlags:InvokeServer()
		end)
		if ok and type(result) == "table" then
			initialFlags = result
		end
	end
end

----------------------------------------------------------------------
-- Style config
----------------------------------------------------------------------
local THEME = {
	bgDark       = Color3.fromRGB(25,25,25),
	bgMid        = Color3.fromRGB(40,40,40),
	bgLight      = Color3.fromRGB(60,60,60),
	accent       = Color3.fromRGB(80,160,255),
	ok           = Color3.fromRGB(22,120,60),
	warn         = Color3.fromRGB(210,100,40),
	error        = Color3.fromRGB(180,40,40),
	textMain     = Color3.fromRGB(230,230,230),
	textSub      = Color3.fromRGB(180,180,180),
	stroke       = Color3.fromRGB(255,255,255),
	buttonOff    = Color3.fromRGB(80,20,20),
	knob         = Color3.fromRGB(245,245,245),
}

local RADIUS_PANEL  = 10
local RADIUS_BTN    = 8
local RADIUS_ROW    = 10
local RADIUS_SWITCH = 14

local Z_MENU = 50
local HOTKEY_TOGGLE_MENU = Enum.KeyCode.F3

----------------------------------------------------------------------
-- Toggle definitions (add more if needed)
----------------------------------------------------------------------
-- type="direct": fires a specific RemoteEvent by name (e.g., MonsterDebugEvent)
-- type="remote": fires DebugToggleEvent with a 'key'
local TOGGLES = {
	{ section="Monsters", label="Vision Cones", type="direct", remoteName="MonsterDebugEvent", default=false, tooltip="Show/hide monster vision cones." },
	{ section="Elevator", label="Show Sensors", type="remote", key="elevator_sensors",       default=false, tooltip="Paint doorway & cabin sensors (server-side)." },
	{ section="Elevator", label="Music",         type="remote", key="elevator_music",         default=true,  tooltip="Enable/disable elevator music logic." },
	{ section="AI",       label="Nav Paths",     type="remote", key="ai_paths",               default=false, tooltip="Show AI navigation/path debug." },
}

----------------------------------------------------------------------
-- UI helpers
----------------------------------------------------------------------
local function corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
	return c
end

local function stroke(instance, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or THEME.stroke
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = instance
	return s
end

local function padding(container, px)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = container
	return p
end

local function label(parent, text, size, bold, color)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Text = text
	t.Font = bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
	t.TextSize = size or 14
	t.TextColor3 = color or THEME.textMain
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = parent
	return t
end

local function tween(obj, info, props)
	local tw = TweenService:Create(obj, info, props)
	tw:Play()
	return tw
end

local function setCanvasToContent(scroll)
	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	if layout then
		scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
	end
end

----------------------------------------------------------------------
-- ScreenGui root
----------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DebugMenuUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

----------------------------------------------------------------------
-- Floating action button (open/close)
----------------------------------------------------------------------
local fab = Instance.new("TextButton")
	fab.Name = "DebugFab"
	fab.Size = UDim2.fromOffset(48, 48)
	fab.Position = UDim2.new(1, -60, 1, -60)
	fab.AnchorPoint = Vector2.new(0,0)
	fab.Text = "🐞"
	fab.Font = Enum.Font.SourceSansBold
	fab.TextSize = 21
	fab.BackgroundColor3 = THEME.bgMid
	fab.TextColor3 = THEME.textMain
	fab.AutoButtonColor = true
	fab.Parent = screenGui
	fab.ZIndex = Z_MENU
corner(fab, RADIUS_BTN)
stroke(fab, THEME.stroke, 1, 0.5)

fab.MouseEnter:Connect(function()
	tween(fab, TweenInfo.new(0.12, Enum.EasingStyle.Sine), {BackgroundColor3 = THEME.bgLight})
end)
fab.MouseLeave:Connect(function()
	tween(fab, TweenInfo.new(0.15, Enum.EasingStyle.Sine), {BackgroundColor3 = THEME.bgMid})
end)

----------------------------------------------------------------------
-- Backdrop (click outside to close)
----------------------------------------------------------------------
local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundColor3 = Color3.new(0,0,0)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1,1)
	backdrop.Position = UDim2.fromScale(0,0)
	backdrop.Visible = false
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.ZIndex = Z_MENU
	backdrop.Parent = screenGui

----------------------------------------------------------------------
-- Main panel (draggable)
----------------------------------------------------------------------
local panel = Instance.new("Frame")
	panel.Name = "DebugPanel"
	panel.Size = UDim2.fromOffset(330, 380)
	panel.Position = UDim2.new(1, -380, 1, -430)
	panel.BackgroundColor3 = THEME.bgDark
	panel.Visible = false
	panel.ZIndex = Z_MENU + 1
	panel.Parent = screenGui
corner(panel, RADIUS_PANEL)
stroke(panel, THEME.stroke, 1, 0.6)
padding(panel, 8)

-- Pop-in effect
panel.BackgroundTransparency = 1
local scale = Instance.new("UIScale", panel)
scale.Scale = 0.94

-- Header
local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 34)
	header.Parent = panel

local title = label(header, "Debug Menu", 18, true, THEME.textMain)
	title.Size = UDim2.new(1, -70, 1, 0)
	title.Position = UDim2.fromOffset(4, 0)

local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "✕"
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.TextSize = 18
	closeBtn.TextColor3 = THEME.textMain
	closeBtn.BackgroundColor3 = THEME.bgMid
	closeBtn.AutoButtonColor = true
	closeBtn.Size = UDim2.fromOffset(30, 26)
	closeBtn.Position = UDim2.new(1, -34, 0, 4)
	closeBtn.Parent = header
corner(closeBtn, 6)
stroke(closeBtn, THEME.stroke, 1, 0.5)

closeBtn.MouseEnter:Connect(function() tween(closeBtn, TweenInfo.new(0.1),  {BackgroundColor3 = THEME.bgLight}) end)
closeBtn.MouseLeave:Connect(function() tween(closeBtn, TweenInfo.new(0.12), {BackgroundColor3 = THEME.bgMid})  end)

-- Body
local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 1, -42)
	body.Position = UDim2.fromOffset(0, 40)
	body.ScrollBarThickness = 6
	body.CanvasSize = UDim2.fromOffset(0, 0)
	body.ZIndex = panel.ZIndex
	body.Parent = panel

local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

-- Floating tooltip
local tooltip = Instance.new("Frame")
	tooltip.Name = "Tooltip"
	tooltip.BackgroundColor3 = THEME.bgLight
	tooltip.Visible = false
	tooltip.Size = UDim2.fromOffset(220, 48)
	tooltip.ZIndex = panel.ZIndex + 10
	tooltip.Parent = screenGui
corner(tooltip, 8)
stroke(tooltip, THEME.stroke, 1, 0.5)
padding(tooltip, 8)

local tooltipText = label(tooltip, "", 13, false, THEME.textMain)
	tooltipText.Size = UDim2.new(1, 0, 1, 0)

local followTooltipConn
local function showTooltip(text)
	tooltipText.Text = text or ""
	tooltip.Visible = true
	if followTooltipConn then followTooltipConn:Disconnect() end
	followTooltipConn = RunService.RenderStepped:Connect(function()
		local m = UserInputService:GetMouseLocation()
		tooltip.Position = UDim2.fromOffset(m.X + 12, m.Y + 12)
	end)
end
local function hideTooltip()
	tooltip.Visible = false
	if followTooltipConn then followTooltipConn:Disconnect(); followTooltipConn = nil end
end

----------------------------------------------------------------------
-- Sections & nice switch rows
----------------------------------------------------------------------
local function addSection(name)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 22)
	holder.Parent = body

	local lbl = label(holder, name, 14, true, Color3.fromRGB(180,200,255))
	lbl.Size = UDim2.new(1, 0, 1, 0)
	return holder
end

local function addSwitchRow(sectionName, labelText, tooltipText, defaultState, onChanged)
	local row = Instance.new("Frame")
	row.BackgroundColor3 = THEME.bgMid
	row.Size = UDim2.new(1, -4, 0, 52)
	row.Parent = body
	corner(row, RADIUS_ROW)
	stroke(row, THEME.stroke, 1, 0.7)
	padding(row, 8)

	local left = Instance.new("Frame")
	left.BackgroundTransparency = 1
	left.Size = UDim2.new(1, -100, 1, 0)
	left.Parent = row

	local title = label(left, labelText, 15, true, THEME.textMain)
	title.Size = UDim2.new(1, 0, 0, 22)
	title.Position = UDim2.fromOffset(2, 2)

	local sub = label(left, tooltipText or "", 12, false, THEME.textSub)
	sub.Size = UDim2.new(1, 0, 0, 18)
	sub.Position = UDim2.fromOffset(2, 26)

	-- Switch
	local switch = Instance.new("TextButton")
	switch.Text = ""
	switch.AutoButtonColor = false
	switch.Size = UDim2.fromOffset(74, 28)
	switch.Position = UDim2.new(1, -84, 0.5, -14)
	switch.BackgroundColor3 = THEME.buttonOff
	switch.Parent = row
	corner(switch, RADIUS_SWITCH)
	stroke(switch, THEME.stroke, 1, 0.5)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(26, 26)
	knob.Position = UDim2.fromOffset(2, 1)
	knob.BackgroundColor3 = THEME.knob
	knob.ZIndex = switch.ZIndex + 1
	knob.Parent = switch
	corner(knob, RADIUS_SWITCH)

	local on = defaultState and true or false

	local function applyVisual(animated)
		if on then
			if animated then tween(switch, TweenInfo.new(0.12, Enum.EasingStyle.Sine), {BackgroundColor3 = THEME.ok})
			else switch.BackgroundColor3 = THEME.ok end
			local target = UDim2.fromOffset(74 - 26 - 2, 1)
			if animated then tween(knob, TweenInfo.new(0.12, Enum.EasingStyle.Sine), {Position = target})
			else knob.Position = target end
		else
			if animated then tween(switch, TweenInfo.new(0.12, Enum.EasingStyle.Sine), {BackgroundColor3 = THEME.buttonOff})
			else switch.BackgroundColor3 = THEME.buttonOff end
			local target = UDim2.fromOffset(2, 1)
			if animated then tween(knob, TweenInfo.new(0.12, Enum.EasingStyle.Sine), {Position = target})
			else knob.Position = target end
		end
	end

	local function setState(v, animated)
		on = v and true or false
		applyVisual(animated)
		if onChanged then onChanged(on) end
	end

	switch.MouseButton1Click:Connect(function()
		setState(not on, true)
	end)

	-- Tooltip on hover
	row.MouseEnter:Connect(function() if tooltipText and #tooltipText > 0 then showTooltip(tooltipText) end end)
	row.MouseLeave:Connect(function() hideTooltip() end)

	applyVisual(false)
	return {
		Set = function(v) setState(v, true) end,
		Get = function() return on end,
	}
end

----------------------------------------------------------------------
-- Build UI from TOGGLES
----------------------------------------------------------------------
local function fireGeneric(key, enabled)
	local ev = getRemote("DebugToggleEvent")
	if ev then ev:FireServer(key, enabled) else warn("[DebugMenu] Missing RemoteEvent: DebugToggleEvent") end
end

local function fireDirect(remoteName, enabled)
	local ev = getRemote(remoteName)
	if ev then ev:FireServer(enabled) else warn(("[DebugMenu] Missing RemoteEvent: %s"):format(remoteName)) end
end

do
	local lastSection = nil
	for _, def in ipairs(TOGGLES) do
		if def.section ~= lastSection then
			addSection(def.section)
			lastSection = def.section
		end
		local initial = def.default
		if def.type == "remote" then
			initial = initialFlags[toFlagName(def.key)] or def.default
		end
		addSwitchRow(def.section, def.label, def.tooltip, initial, function(enabled)
			if def.type == "direct" then
				fireDirect(def.remoteName, enabled)
			else
				fireGeneric(def.key, enabled)
			end
		end)
	end
end

-- Maintain CanvasSize to content
body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() setCanvasToContent(body) end)
task.defer(function() setCanvasToContent(body) end)

----------------------------------------------------------------------
-- Open/Close with animation & backdrop
----------------------------------------------------------------------
local function setMenuVisible(v)
	if v then
		backdrop.Visible = true
		panel.Visible = true
		panel.BackgroundTransparency = 1
		scale.Scale = 0.94

		tween(backdrop, TweenInfo.new(0.15, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.35})
		tween(panel,    TweenInfo.new(0.14, Enum.EasingStyle.Sine), {BackgroundTransparency = 0})
		tween(scale,    TweenInfo.new(0.14, Enum.EasingStyle.Sine), {Scale = 1})
	else
		local twBack = tween(backdrop, TweenInfo.new(0.12, Enum.EasingStyle.Sine), {BackgroundTransparency = 1})
		twBack.Completed:Connect(function() backdrop.Visible = false end)

		local twPanel = tween(panel, TweenInfo.new(0.12, Enum.EasingStyle.Sine), {BackgroundTransparency = 1})
		twPanel.Completed:Connect(function() panel.Visible = false end)

		scale.Scale = 0.97
	end
end

fab.MouseButton1Click:Connect(function()
	setMenuVisible(not panel.Visible)
end)

closeBtn.MouseButton1Click:Connect(function()
	setMenuVisible(false)
end)

backdrop.MouseButton1Click:Connect(function()
	setMenuVisible(false)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == HOTKEY_TOGGLE_MENU then
		setMenuVisible(not panel.Visible)
	end
end)

----------------------------------------------------------------------
-- Drag panel via header
----------------------------------------------------------------------
do
	local dragging = false
	local dragStart, startPos

	local function update(input)
		local delta = input.Position - dragStart
		panel.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end

	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or
		   input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = panel.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	header.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or
		   input.UserInputType == Enum.UserInputType.Touch then
			if dragging then update(input) end
		end
	end)
end