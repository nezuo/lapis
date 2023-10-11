local RunService = game:GetService("RunService")

local Promise = require(script.Parent.Parent.Parent.Promise)
local types = require(script.Parent.Parent.types)

local function updateAsync(request)
	return Promise.new(function(resolve)
		local result, transformed

		local ok, err = pcall(function()
			request.dataStore:UpdateAsync(request.key, function(...)
				result, transformed = request.transform(...)

				if result == "succeed" then
					return transformed
				else
					return nil
				end
			end)
		end)

		if not ok then
			resolve("retry", err)
		else
			resolve(result, transformed)
		end
	end)
end

local Throttle = {}
Throttle.__index = Throttle

function Throttle.new<T>(config: types.Config): types.Throttle<T>
	return (setmetatable({
		config = config,
		queue = {},
	}, Throttle) :: any) :: types.Throttle<T>
end

function Throttle:getUpdateAsyncBudget()
	return self.config:get("dataStoreService"):GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
end

function Throttle:start()
	RunService.PostSimulation:Connect(function()
		for index = #self.queue, 1, -1 do
			local request = self.queue[index]

			if request.attempts == 0 then
				table.remove(self.queue, index)
			end
		end

		for _, request in self.queue do
			if self:getUpdateAsyncBudget() == 0 then
				break
			end

			if request.promise ~= nil then
				continue
			end

			local promise = updateAsync(request):andThen(function(result, value)
				if result == "succeed" then
					request.attempts = 0
					request.resolve(value)
				elseif result == "fail" then
					request.attempts = 0
					request.reject(`DataStoreFailure({value})`)
				elseif result == "retry" then
					request.attempts -= 1

					if request.attempts == 0 then
						request.reject(`DataStoreFailure({value})`)
					else
						if self.config:get("showRetryWarnings") then
							warn(`DataStore operation failed. Retrying...\nError: {value}`)
						end

						task.wait(request.retryDelay)
					end
				else
					error("unreachable")
				end

				request.promise = nil
			end)

			if promise:getStatus() == Promise.Status.Started then
				request.promise = promise
			end
		end
	end)
end

function Throttle:updateAsync(dataStore, key, transform, retryAttempts, retryDelay)
	return Promise.new(function(resolve, reject)
		table.insert(self.queue, {
			dataStore = dataStore,
			key = key,
			transform = transform,
			attempts = retryAttempts,
			retryDelay = retryDelay,
			resolve = resolve,
			reject = reject,
		})
	end)
end

return Throttle
