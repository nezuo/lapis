local throttleWrite = require(script.throttleWrite)

local Throttle = {}

function Throttle.update(dataStore, key, transform)
	return throttleWrite("UpdateAsync", dataStore, key, transform)
end

return Throttle
