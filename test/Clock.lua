local Clock = {}
Clock.__index = Clock

function Clock.new(dataStoreService, superSpeed)
	return setmetatable({
		clock = 0,
		tasks = {},
		dataStoreService = dataStoreService,
		locked = not superSpeed,
	}, Clock)
end

function Clock:now()
	return self.clock
end

function Clock:addTask(newTask)
	local insertAt = 1

	for index = #self.tasks, 1, -1 do
		if self.tasks[index].resumeAt <= newTask.resumeAt then
			insertAt = index + 1
			break
		end
	end

	table.insert(self.tasks, insertAt, newTask)
end

function Clock:tick(seconds)
	if self.locked then
		return
	end

	local finishAt = self.clock + seconds

	for _, task in self.dataStoreService.budget:tick(seconds) do
		self:addTask(task)
	end

	while #self.tasks > 0 do
		if self.tasks[1].resumeAt > finishAt then
			break
		end

		local task = table.remove(self.tasks, 1)

		self.clock = task.resumeAt
		self.dataStoreService:setClock(task.resumeAt)

		task.resume()
	end

	self.clock = finishAt
	self.dataStoreService:setClock(finishAt)
end

return Clock
