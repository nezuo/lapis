local Config = require(script.Parent.Config)
local Promise = require(script.Parent.Parent.Promise)
local throttleUpdate = require(script.throttleUpdate)

local WRITE_COOLDOWN = 6

local writeCooldowns = {}
local pendingSaves = {}

local function removeWriteCooldown(dataStore, key)
	writeCooldowns[dataStore][key] = nil

	if next(writeCooldowns[dataStore]) == nil then
		writeCooldowns[dataStore] = nil
	end
end

local function addWriteCooldown(dataStore, key)
	local cooldown = Promise.delay(WRITE_COOLDOWN):finallyCall(removeWriteCooldown, dataStore, key)

	-- This condition prevents adding the promise to writeCooldowns after removeWriteCooldown is called.
	-- It's necessary because Promise.delay can resolve instantly in tests.
	if cooldown:getStatus() == Promise.Status.Started then
		if writeCooldowns[dataStore] == nil then
			writeCooldowns[dataStore] = {}
		end

		writeCooldowns[dataStore][key] = cooldown
	end
end

local function writeCooldown(dataStore, key)
	if writeCooldowns[dataStore] ~= nil and writeCooldowns[dataStore][key] ~= nil then
		return writeCooldowns[dataStore][key]
	else
		return nil
	end
end

local Data = {}

function Data.load(dataStore, key, transform)
	return Promise.resolve()
		:andThen(function()
			if pendingSaves[dataStore] ~= nil and pendingSaves[dataStore][key] ~= nil then
				return pendingSaves[dataStore][key].promise
			else
				return nil
			end
		end)
		:andThenCall(writeCooldown, dataStore, key)
		:andThen(function()
			local attempts, delay = Config.get("acquireLockAttempts"), Config.get("acquireLockDelay")

			return throttleUpdate(dataStore, key, transform, attempts, delay)
		end)
		:tap(function()
			addWriteCooldown(dataStore, key)
		end)
end

function Data.save(dataStore, key, transform)
	if pendingSaves[dataStore] == nil then
		pendingSaves[dataStore] = {}
	end

	if pendingSaves[dataStore][key] == nil then
		pendingSaves[dataStore][key] = { transform = transform }

		local promise = Promise.resolve()
			:andThenCall(writeCooldown, dataStore, key)
			:andThen(function()
				return throttleUpdate(dataStore, key, function(...)
					return pendingSaves[dataStore][key].transform(...)
				end, Config.get("retryAttempts"))
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
	else
		local pendingSave = pendingSaves[dataStore][key]

		pendingSave.transform = transform

		return pendingSave.promise
	end
end

function Data.getPendingSaves()
	return pendingSaves
end

return Data
