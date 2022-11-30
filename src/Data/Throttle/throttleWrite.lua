local Constants = require(script.Parent.Parent.Parent.Constants)
local Promise = require(script.Parent.Parent.Parent.Parent.Promise)
local throttle = require(script.Parent.throttle)

local cooldowns = {}
local writeQueues = {}

local function throttleCooldown(methodName, dataStore, key, ...)
	if cooldowns[dataStore] == nil then
		cooldowns[dataStore] = {}
	end

	if cooldowns[dataStore][key] ~= nil then
		cooldowns[dataStore][key]:await()
	end

	local ok, value = throttle(methodName, dataStore, key, ...)

	-- TODO: Do we need the cooldown if throttle fails?
	cooldowns[dataStore][key] = Promise.delay(Constants.WRITE_COOLDOWN):andThen(function()
		cooldowns[dataStore][key] = nil
	end)

	return ok, value
end

local function startWriteQueue(dataStore, key, initialWrite)
	local writeQueue = { initialWrite }

	writeQueues[dataStore][key] = writeQueue

	task.spawn(function()
		while #writeQueue > 0 do
			local write = table.remove(writeQueue, 1)

			write.ok, write.value = throttleCooldown(write.methodName, dataStore, key, unpack(write.arguments))

			write.resolved = true

			coroutine.resume(write.thread)
		end

		writeQueues[dataStore][key] = nil
	end)
end

local function queueWrite(dataStore, key, write)
	if writeQueues[dataStore][key] == nil then
		startWriteQueue(dataStore, key, write)
	else
		table.insert(writeQueues[dataStore][key], write)
	end
end

local function throttleWrite(methodName, dataStore, key, ...)
	if writeQueues[dataStore] == nil then
		writeQueues[dataStore] = {}
	end

	local arguments = { ... }
	local write = {
		methodName = methodName,
		arguments = arguments,
		thread = coroutine.running(),
		resolved = false,
	}

	queueWrite(dataStore, key, write)

	if not write.resolved then
		coroutine.yield()
	end

	return write.ok, write.value
end

return throttleWrite
