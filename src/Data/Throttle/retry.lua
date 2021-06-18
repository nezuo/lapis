local Config = require(script.Parent.Parent.Parent.Config)
local Error = require(script.Parent.Parent.Parent.Error)

local function retry(callback)
	local ok, value

	for _ = 1, Config.get("retryAttempts") do
		ok, value = pcall(callback)

		if ok then
			return true, value
		end

		if Config.get("showRetryWarnings") then
			warn(string.format("DataStore operation failed. Retrying...\nError: %s", value))
		end
	end

	return false, Error.new(Error.Kind.DataStoreFailure, string.format("DataStores failed after 5 retries: %s", value))
end

return retry
