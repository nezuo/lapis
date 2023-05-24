local Promise = require(script.Parent.Parent.Parent.Promise)

local WRITE_COOLDOWN = 6

local writeCooldowns = {}

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

local function getWriteCooldown(dataStore, key)
	if writeCooldowns[dataStore] == nil or writeCooldowns[dataStore][key] == nil then
		return Promise.resolve()
	end

	return writeCooldowns[dataStore][key]
end

return {
	addWriteCooldown = addWriteCooldown,
	getWriteCooldown = getWriteCooldown,
}
