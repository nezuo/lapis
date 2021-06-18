local Tasks = {
	isLocked = true,
	tasks = {},
}

function Tasks.lock()
	Tasks.isLocked = true
end

function Tasks.unlock()
	Tasks.isLocked = false
end

function Tasks.addTask(task)
	local insertAt = 1

	for index = #Tasks.tasks, 1, -1 do
		if Tasks.tasks[index].resumeAt <= task.resumeAt then
			insertAt = index + 1

			break
		end
	end

	table.insert(Tasks.tasks, insertAt, task)
end

function Tasks.resumeAll()
	for _, task in ipairs(Tasks.tasks) do
		task.resume()
	end

	Tasks.tasks = {}
end

return Tasks
