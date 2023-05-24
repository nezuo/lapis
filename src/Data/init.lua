local Config = require(script.Parent.Config)
local Promise = require(script.Parent.Parent.Promise)
local throttleUpdate = require(script.throttleUpdate)
local WriteCooldown = require(script.WriteCooldown)

local addWriteCooldown = WriteCooldown.addWriteCooldown
local getWriteCooldown = WriteCooldown.getWriteCooldown

local pendingSaves = {}

local function getPendingSave(dataStore, key)
	if pendingSaves[dataStore] == nil or pendingSaves[dataStore][key] == nil then
		return Promise.resolve()
	end

	return pendingSaves[dataStore][key].promise
end

local Data = {}

function Data.load(dataStore, key, transform)
	return getPendingSave(dataStore, key)
		:andThenCall(getWriteCooldown, dataStore, key)
		:andThen(function()
			local attempts = Config.get("loadAttempts")
			local retryDelay = Config.get("loadRetryDelay")

			return throttleUpdate(dataStore, key, transform, attempts, retryDelay)
		end)
		:tap(function()
			addWriteCooldown(dataStore, key)
		end)
end

function Data.save(dataStore, key, transform)
	if pendingSaves[dataStore] == nil then
		pendingSaves[dataStore] = {}
	end

	local pendingSave = pendingSaves[dataStore][key]

	if pendingSave ~= nil then
		pendingSave.transform = transform

		return pendingSave.promise
	else
		pendingSaves[dataStore][key] = { transform = transform }

		local promise = getWriteCooldown(dataStore, key)
			:andThen(function()
				local attempts = Config.get("saveAttempts")

				return throttleUpdate(dataStore, key, function(...)
					return pendingSaves[dataStore][key].transform(...)
				end, attempts)
			end)
			:andThenCall(addWriteCooldown, dataStore, key)
			:finally(function()
				pendingSaves[dataStore][key] = nil

				if next(pendingSaves[dataStore]) == nil then
					pendingSaves[dataStore] = nil
				end
			end)

		if promise:getStatus() == Promise.Status.Started then
			pendingSaves[dataStore][key].promise = promise
		end

		return promise
	end
end

function Data.getPendingSaves()
	return pendingSaves
end

return Data
