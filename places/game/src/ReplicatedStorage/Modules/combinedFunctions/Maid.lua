-- Maid.lua
--[[
  Maid (Lifecycle / Cleanup Manager)
  ----------------------------------
  Purpose:
    Manage lifetimes of connections, instances, and arbitrary cleanup callbacks.
    Useful to avoid leaks and to cleanly tear down features (UI screens, enemies, etc).

  API:
    local Maid = require(....Maid)

    -- Construction
    local m1 = Maid.new()                          -- standalone
    local m2 = Maid.new(true, "SharedName")        -- shared by name (retrievable via GetSharedMaid)

    -- Register things to auto-clean
    m1:GiveTask(nil, someSignal, function(...) end)        -- connect a RBXScriptSignal
    m1:GiveSignal(someSignal, function(...) end, "id?")    -- ergonomic alias for GiveTask
    m1:Give(function() print("cleanup!") end)              -- sugar (maps to GiveTask w/ nil id)
    m1:GiveCleanup("id?", function() ... end)              -- register arbitrary callback
    m1:GiveConnection(conn, "id?")                         -- RBXScriptConnection → Disconnect()
    m1:GiveInstance(someInstance, "id?")                   -- Instance → Destroy()
    m1:BindToInstance(someInstance)                        -- auto-destroy Maid when instance is Destroying

    -- Manage tasks
    m1:EndTaskByTaskId("id")        -- returns boolean (true if task existed)
    m1:EndAListOfTasks({ "a", "b" })
    m1:EndAllTasks()
    m1:Destroy()                    -- EndAllTasks + unshare if shared

    -- Introspection
    m1:GetMaidName()
    m1:GetSharedMaid("SharedName")
    m1:GetTasksList()               -- { [taskId] = true, ... }
    m1:Count()                      -- number of tracked tasks

  Notes:
    - If you reuse TaskIds, the previous task with the same id is ended first.
    - Use GiveSignal (or GiveTask) for RBXScriptSignal; GiveConnection for RBXScriptConnection.
    - BindToInstance wires the Maid's lifecycle to an Instance (when it’s Destroying, Maid:Destroy()).
]]

local Maid = { SharedMaids = {} }
Maid.__index = Maid

local Http = game:GetService("HttpService")

local function _guid()
	return Http:GenerateGUID(false)
end

function Maid.new(IsShared: boolean?, MaidName: string?)
	local self = setmetatable({}, Maid)
	self.Cache = {} :: { [string]: { EndTask: ()->() } }
	self.MaidName = MaidName or _guid()
	if IsShared then
		Maid.SharedMaids[self.MaidName] = self
	end
	return self
end

-- Generate a traceable task id (helps debugging)
function Maid:_newTaskId()
	return string.format("%s:%s", self.MaidName, _guid())
end

-- Core: register a RBXScriptSignal + callback
function Maid:GiveTask(TaskId: string?, Signal: RBXScriptSignal, callback: (any) -> ())
	if typeof(Signal) ~= "RBXScriptSignal" then
		warn("Maid:GiveTask → 'Signal' must be RBXScriptSignal", debug.traceback())
		return
	end
	if typeof(callback) ~= "function" then
		warn("Maid:GiveTask → 'callback' must be function", debug.traceback())
		return
	end

	local TaskClass = {}
	TaskClass.TaskId = TaskId or self:_newTaskId()
	TaskClass.Connection = Signal:Connect(callback)
	function TaskClass:EndTask()
		if TaskClass.Connection then
			TaskClass.Connection:Disconnect()
			TaskClass.Connection = nil
		end
	end

	-- Replace existing task with same id
	if self.Cache[TaskClass.TaskId] then
		self.Cache[TaskClass.TaskId]:EndTask()
	end
	self.Cache[TaskClass.TaskId] = TaskClass
	return TaskClass
end

-- Ergonomic alias (STRICT): same as GiveTask but nicer signature.
-- IMPORTANT: keep the parameter order when delegating to GiveTask (TaskId, Signal, callback)
function Maid:GiveSignal(Signal: RBXScriptSignal, callback: (any)->(), TaskId: string?)
	if typeof(Signal) ~= "RBXScriptSignal" then
		warn("Maid:GiveSignal → 'Signal' must be RBXScriptSignal", debug.traceback()); return
	end
	if typeof(callback) ~= "function" then
		warn("Maid:GiveSignal → 'callback' must be function", debug.traceback()); return
	end
	return self:GiveTask(TaskId, Signal, callback)
end

-- Sugar (TOLERANT): allows Maid:Give(signal, cb) or Maid:Give(taskId, signal, cb)
function Maid:Give(a, b, c)
	if typeof(a) == "RBXScriptSignal" then
		return self:GiveTask(nil, a, b)
	else
		return self:GiveTask(a, b, c)
	end
end

-- Register arbitrary cleanup function
function Maid:GiveCleanup(TaskId: string?, cleanup: () -> ())
	if typeof(cleanup) ~= "function" then
		warn("Maid:GiveCleanup → 'cleanup' must be function", debug.traceback()); return
	end
	local TaskClass = {}
	TaskClass.TaskId = TaskId or self:_newTaskId()
	function TaskClass:EndTask()
		pcall(cleanup)
	end

	if self.Cache[TaskClass.TaskId] then
		self.Cache[TaskClass.TaskId]:EndTask()
	end
	self.Cache[TaskClass.TaskId] = TaskClass
	return TaskClass
end

-- Register a RBXScriptConnection (Disconnect on cleanup)
function Maid:GiveConnection(conn: RBXScriptConnection, TaskId: string?)
	if typeof(conn) ~= "RBXScriptConnection" then
		warn("Maid:GiveConnection → 'conn' must be RBXScriptConnection", debug.traceback()); return
	end
	return self:GiveCleanup(TaskId, function()
		if conn.Connected then conn:Disconnect() end
	end)
end

-- Register an Instance (Destroy on cleanup)
function Maid:GiveInstance(inst: Instance, TaskId: string?)
	if typeof(inst) ~= "Instance" then
		warn("Maid:GiveInstance → 'inst' must be Instance", debug.traceback()); return
	end
	return self:GiveCleanup(TaskId, function()
		if inst then
			pcall(function() inst:Destroy() end)
		end
	end)
end

-- Bind Maid's lifecycle to an Instance (auto-destroy)
function Maid:BindToInstance(inst: Instance, TaskId: string?)
	if typeof(inst) ~= "Instance" then
		warn("Maid:BindToInstance expects an Instance", debug.traceback()); return
	end
	return self:GiveConnection(inst.Destroying:Connect(function()
		self:Destroy()
	end), TaskId or (self.MaidName..":bind:"..tostring(inst)))
end

-- End one task by id (returns true if existed)
function Maid:EndTaskByTaskId(TaskId: string?): boolean
	if not TaskId or typeof(TaskId) ~= "string" then
		warn("Maid:EndTaskByTaskId → invalid TaskId", TaskId, debug.traceback())
		return false
	end
	local t = self.Cache[TaskId]
	if t then
		pcall(function() t:EndTask() end)
		self.Cache[TaskId] = nil
		return true
	end
	return false
end

-- End all tasks
function Maid:EndAllTasks()
	for _, v in pairs(self.Cache) do
		pcall(function() v:EndTask() end)
	end
	table.clear(self.Cache)
end

-- Destroy maid and unshare if needed
function Maid:Destroy()
	self:EndAllTasks()
	if Maid.SharedMaids[self.MaidName] == self then
		Maid.SharedMaids[self.MaidName] = nil
	end
end

-- End a list of task ids
function Maid:EndAListOfTasks(tab: table)
	if typeof(tab) ~= "table" then
		warn("Maid:EndAListOfTasks → 'tab' must be table", debug.traceback()); return
	end
	for _, id in ipairs(tab) do
		self:EndTaskByTaskId(id)
	end
end

-- Info / helpers
function Maid:GetMaidName() return self.MaidName end

function Maid:GetSharedMaid(MaidName: string)
	return Maid.SharedMaids[MaidName] or Maid.new(true, MaidName)
end

function Maid:GetTasksList()
	local list = {}
	for id in pairs(self.Cache) do list[id] = true end
	return list
end

function Maid:Count()
	local n = 0
	for _ in pairs(self.Cache) do n += 1 end
	return n
end

function Maid:__tostring()
	return ("Maid<%s>[%d tasks]"):format(self.MaidName, self:Count())
end

return Maid
