local Config = require(script.Parent.Parent.Config)
local Promise = require(script.Parent.Parent.Parent.Promise)
local retry = require(script.Parent.retry)

local queue = nil

local function budget()
	return Config.get("dataStoreService"):GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
end

local function startQueue()
	task.spawn(function()
		while #queue > 0 do
			local request = table.remove(queue, 1)

			local ok, value = retry(request.attempts, request.delay, function()
				while budget() == 0 do
					task.wait()
				end

				local success, transformed

				local data = request.dataStore:UpdateAsync(request.key, function(...)
					success, transformed = request.transform(...)

					if not success then
						return nil
					else
						return transformed
					end
				end)

				if not success then
					error(transformed)
				end

				return data
			end)

			if ok then
				request.resolve(value)
			else
				request.reject(value)
			end
		end

		queue = nil
	end)
end

local function throttleUpdate(dataStore, key, transform, retryAttempts, retryDelay)
	return Promise.new(function(resolve, reject)
		local request = {
			dataStore = dataStore,
			key = key,
			transform = transform,
			attempts = retryAttempts,
			delay = retryDelay,
			resolve = resolve,
			reject = reject,
		}

		if queue == nil then
			queue = { request }
			startQueue()
		else
			table.insert(queue, request)
		end
	end)
end

return throttleUpdate
