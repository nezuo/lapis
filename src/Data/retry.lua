local Config = require(script.Parent.Parent.Config)
local Promise = require(script.Parent.Parent.Parent.Promise)

local function retry(attempts, delay, callback)
	for attempt = 1, attempts do
		local ok, value = pcall(callback)

		if ok then
			return true, value
		end

		if attempt == attempts then
			return false, string.format("DataStoreFailure(%s)", value)
		end

		if Config.get("showRetryWarnings") then
			warn(string.format("DataStore operation failed. Retrying...\nError: %s", value))
		end

		if delay ~= nil then
			Promise.delay(delay):expect()
		end
	end

	error("unreachable")
end

return retry
