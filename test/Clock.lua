local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataStoreServiceMock = require(ReplicatedStorage.ServerPackages.DataStoreServiceMock)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Tasks = require(ReplicatedStorage.Tasks)

local Managers = DataStoreServiceMock.Managers

local clock = 0

local Clock = {
	isLocked = true,
}

function Clock.start(isSuperSpeed)
	Clock.isLocked = not isSuperSpeed

	if isSuperSpeed then
		Promise.delay = function(duration)
			if Tasks.isLocked then
				return Promise.resolve()
			end

			return Promise.try(function()
				local thread = coroutine.running()
				local task = {
					resumeAt = clock + duration,
					resume = function()
						coroutine.resume(thread)
					end,
				}

				Tasks.addTask(task)

				coroutine.yield()
			end)
		end

		Promise.defer = function()
			Clock.progress(1)

			return Promise.resolve()
		end
	end
end

function Clock.reset()
	clock = 0
	Managers.Clock.set(0)
end

function Clock.progress(amount)
	if Clock.isLocked then
		return
	end

	local finishAt = clock + amount

	for _, task in ipairs(Managers.Tasks.get(finishAt)) do
		Tasks.addTask(task)
	end

	while #Tasks.tasks > 0 do
		if Tasks.tasks[1].resumeAt > finishAt then
			break
		end

		local task = table.remove(Tasks.tasks, 1)

		clock = task.resumeAt
		Managers.Clock.set(task.resumeAt)

		task.resume()
	end

	clock = finishAt
end

return Clock
