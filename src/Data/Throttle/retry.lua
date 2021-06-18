local Error = require(script.Parent.Parent.Parent.Error)

local MAX_ATTEMPTS = 5

local function retry(callback)
	local ok, value

	for _ = 1, MAX_ATTEMPTS do
		ok, value = pcall(callback)

		if ok then
			return true, value
		end

		-- TODO: We only want to show this in production, not unit tests!
		warn(string.format("DataStore operation failed. Retrying...\nError: %s", value))
	end

	return false, Error.new(Error.Kind.DataStoreFailure, string.format("DataStores failed after 5 retries: %s", value))
end

return retry
