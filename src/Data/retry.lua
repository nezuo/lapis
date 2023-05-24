local Config = require(script.Parent.Parent.Config)
local Promise = require(script.Parent.Parent.Parent.Promise)

local function retry(attempts, delay, callback)
	for attempt = 1, attempts do
		local result, value = callback()

		if result == "succeed" then
			return true, value
		elseif result == "fail" then
			return false, value
		elseif attempt == attempts then
			return false, `DataStoreFailure({value})`
		end

		if Config.get("showRetryWarnings") then
			warn(`DataStore operation failed. Retrying...\nError: {value}`)
		end

		if delay ~= nil then
			Promise.delay(delay):expect()
		end
	end

	error("unreachable")
end

return retry
