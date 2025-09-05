local Maid = { SharedMaids = {} }
Maid.__index = Maid
local HTTP = game:GetService("HttpService")

function Maid.new(IsShared: boolean?, MaidName: string?)
	local self = setmetatable({}, Maid)
	self.Cache = {}
	self.MaidName = MaidName or HTTP:GenerateGUID(false)
	if IsShared then
		Maid.SharedMaids[self.MaidName] = self
	end
	return self
end

function Maid:GiveTask(TaskId: string?, Signal: RBXScriptSignal, callback: (any) -> ())
	if typeof(Signal) ~= "RBXScriptSignal" then
		return warn("Signal must be a valid RBXScriptSignal", debug.traceback())
	end
	if typeof(callback) ~= "function" then
		return warn("callback must be a valid function", debug.traceback())
	end
	local TaskClass = {}
	TaskClass.TaskId = TaskId or HTTP:GenerateGUID(false)
	TaskClass.Connection = Signal:Connect(callback)
	function TaskClass:EndTask()
		if TaskClass.Connection then
			TaskClass.Connection:Disconnect()
			TaskClass.Connection = nil
		end
	end
	if self.Cache[TaskClass.TaskId] then self.Cache[TaskClass.TaskId]:EndTask() end
	self.Cache[TaskClass.TaskId] = TaskClass
	return TaskClass
end

function Maid:EndTaskByTaskId(TaskId: string?)
	if not TaskId or typeof(TaskId) ~= "string" then
		return warn("Invalid TaskId", TaskId, debug.traceback())
	end
	local t = self.Cache[TaskId]
	if t then
		t:EndTask()
		self.Cache[TaskId] = nil
	end
end

function Maid:EndAllTasks()
	for _,v in self.Cache do
		v:EndTask()
	end
	table.clear(self.Cache)
end

function Maid:Destroy()
	self:EndAllTasks()
	if Maid.SharedMaids[self.MaidName] == self then
		Maid.SharedMaids[self.MaidName] = nil
	end
end

function Maid:EndAListOfTasks(tab: table)
	if typeof(tab) ~= 'table' then return warn('Invalid type of data, must be table', debug.traceback()) end
	for _,id in tab do
		self:EndTaskByTaskId(id)
	end
end

function Maid:GetMaidName() return self.MaidName end

function Maid:GetSharedMaid(MaidName: string): typeof(Maid)
	return Maid.SharedMaids[MaidName] or Maid.new(true, MaidName)
end

function Maid:GetTasksList()
	local list = {}
	for id in self.Cache do list[id] = '/' end
	return list
end

return Maid
