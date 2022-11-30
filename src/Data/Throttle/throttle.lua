local callDataStore = require(script.Parent.callDataStore)
local Config = require(script.Parent.Parent.Parent.Config)
local Promise = require(script.Parent.Parent.Parent.Parent.Promise)
local retry = require(script.Parent.retry)

local queues = {}

local function hasBudget(requestType)
	return Config.get("dataStoreService"):GetRequestBudgetForRequestType(requestType) > 0
end

local function startQueue(requestType, initialRequest)
	local queue = { initialRequest }

	queues[requestType] = queue

	task.spawn(function()
		while #queue > 0 do
			local request = table.remove(queue, 1)

			request.ok, request.value = retry(function()
				while not hasBudget(requestType) do
					Promise.defer():await()
				end

				return callDataStore(unpack(request.arguments))
			end)

			request.resolved = true

			coroutine.resume(request.thread)
		end

		queues[requestType] = nil
	end)
end

local function queueRequest(requestType, request)
	if queues[requestType] == nil then
		startQueue(requestType, request)
	else
		table.insert(queues[requestType], request)
	end
end

local function throttle(methodName, dataStore, ...)
	local arguments = { dataStore, methodName, ... }
	local requestType = Enum.DataStoreRequestType[methodName]
	local request = {
		arguments = arguments,
		thread = coroutine.running(),
		resolved = false,
	}

	queueRequest(requestType, request)

	if not request.resolved then
		coroutine.yield()
	end

	return request.ok, request.value
end

return throttle
