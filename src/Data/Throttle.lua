local Promise = require(script.Parent.Parent.Parent.Promise)

local Throttle = {}
Throttle.__index = Throttle

function Throttle.new(config)
	return setmetatable({
		config = config,
	}, Throttle)
end

function Throttle:getUpdateAsyncBudget()
	return self.config:get("dataStoreService"):GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
end

function Throttle:retry(attempts, delay, callback)
	for attempt = 1, attempts do
		local result, value = callback()

		if result == "succeed" then
			return true, value
		elseif result == "fail" then
			return false, value
		elseif attempt == attempts then
			return false, `DataStoreFailure({value})`
		end

		if self.config:get("showRetryWarnings") then
			warn(`DataStore operation failed. Retrying...\nError: {value}`)
		end

		if delay ~= nil then
			Promise.delay(delay):expect()
		end
	end

	error("unreachable")
end

function Throttle:startQueue()
	while #self.queue > 0 do
		local request = table.remove(self.queue, 1)

		local ok, value = self:retry(request.attempts, request.delay, function()
			while self:getUpdateAsyncBudget() == 0 do
				task.wait()
			end

			local result, transformed

			local updateOk, err = pcall(function()
				request.dataStore:UpdateAsync(request.key, function(...)
					result, transformed = request.transform(...)

					if result == "succeed" then
						return transformed
					else
						return nil
					end
				end)
			end)

			if not updateOk then
				return "retry", err
			end

			return result, transformed
		end)

		if ok then
			request.resolve(value)
		else
			request.reject(value)
		end
	end

	self.queue = nil
end

function Throttle:updateAsync(dataStore, key, transform, retryAttempts, retryDelay)
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

		if self.queue == nil then
			self.queue = { request }

			task.spawn(function()
				self:startQueue()
			end)
		else
			table.insert(self.queue, request)
		end
	end)
end

return Throttle
