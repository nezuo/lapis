local Promise = require(script.Parent.Parent.Promise)
local Throttle = require(script.Throttle)

local Data = {}
Data.__index = Data

function Data.new(config)
	local throttle = Throttle.new(config)

	throttle:start()

	return setmetatable({
		config = config,
		throttle = throttle,
		ongoingSaves = {},
	}, Data)
end

function Data:waitForOngoingSave(dataStore, key)
	if self.ongoingSaves[dataStore] == nil or self.ongoingSaves[dataStore][key] == nil then
		return Promise.resolve()
	end

	local ongoingSave = self.ongoingSaves[dataStore][key]

	return Promise.allSettled({
		ongoingSave.promise,
		if ongoingSave.pendingSave ~= nil then ongoingSave.pendingSave.promise else nil,
	})
end

function Data:waitForOngoingSaves()
	local promises = {}

	for _, ongoingSaves in self.ongoingSaves do
		for _, ongoingSave in ongoingSaves do
			if ongoingSave.pendingSave ~= nil then
				table.insert(promises, ongoingSave.pendingSave.promise)
			end

			table.insert(promises, ongoingSave.promise)
		end
	end

	return Promise.allSettled(promises)
end

function Data:load(dataStore, key, transform)
	return self:waitForOngoingSave(dataStore, key):andThen(function()
		local attempts = self.config:get("loadAttempts")
		local retryDelay = self.config:get("loadRetryDelay")

		return self.throttle:updateAsync(dataStore, key, transform, attempts, retryDelay)
	end)
end

function Data:save(dataStore, key, transform)
	if self.ongoingSaves[dataStore] == nil then
		self.ongoingSaves[dataStore] = {}
	end

	local ongoingSave = self.ongoingSaves[dataStore][key]

	if ongoingSave == nil then
		local attempts = self.config:get("saveAttempts")
		local promise = self
			.throttle
			:updateAsync(dataStore, key, transform, attempts)
			:andThenReturn() -- Save promise should not resolve with a value.
			:finally(function()
				self.ongoingSaves[dataStore][key] = nil

				if next(self.ongoingSaves[dataStore]) == nil then
					self.ongoingSaves[dataStore] = nil
				end
			end)

		if promise:getStatus() == Promise.Status.Started then
			self.ongoingSaves[dataStore][key] = { promise = promise }
		end

		return promise
	elseif ongoingSave.pendingSave == nil then
		local pendingSave = { transform = transform }

		local function save()
			return self:save(dataStore, key, pendingSave.transform)
		end

		-- promise:finally(save) can't be used because if the ongoingSave promise rejects, so will the promise returned from finally.
		pendingSave.promise = ongoingSave.promise:andThen(save, save)

		ongoingSave.pendingSave = pendingSave

		return pendingSave.promise
	else
		ongoingSave.pendingSave.transform = transform

		return ongoingSave.pendingSave.promise
	end
end

return Data
