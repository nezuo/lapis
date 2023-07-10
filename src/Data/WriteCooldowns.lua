local Promise = require(script.Parent.Parent.Parent.Promise)

local WRITE_COOLDOWN = 6

local WriteCooldowns = {}
WriteCooldowns.__index = WriteCooldowns

function WriteCooldowns.new()
	return setmetatable({
		writeCooldowns = {},
	}, WriteCooldowns)
end

function WriteCooldowns:removeWriteCooldown(dataStore, key)
	self.writeCooldowns[dataStore][key] = nil

	if next(self.writeCooldowns[dataStore]) == nil then
		self.writeCooldowns[dataStore] = nil
	end
end

function WriteCooldowns:addWriteCooldown(dataStore, key)
	local cooldown = Promise.delay(WRITE_COOLDOWN):finally(function()
		self:removeWriteCooldown(dataStore, key)
	end)

	-- This condition prevents adding the promise to writeCooldowns after removeWriteCooldown is called.
	-- It's necessary because Promise.delay can resolve instantly in tests.
	if cooldown:getStatus() == Promise.Status.Started then
		if self.writeCooldowns[dataStore] == nil then
			self.writeCooldowns[dataStore] = {}
		end

		self.writeCooldowns[dataStore][key] = cooldown
	end
end

function WriteCooldowns:getWriteCooldown(dataStore, key)
	if self.writeCooldowns[dataStore] == nil or self.writeCooldowns[dataStore][key] == nil then
		return Promise.resolve()
	end

	return self.writeCooldowns[dataStore][key]
end

return WriteCooldowns
