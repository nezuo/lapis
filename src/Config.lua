local DataStoreService = game:GetService("DataStoreService")

local config = {
	retryAttempts = 5,
	acquireLockAttempts = 20,
	acquireLockDelay = 1,
	showRetryWarnings = true,
	dataStoreService = DataStoreService,
}

local Config = {}

function Config.get(key)
	return config[key]
end

function Config.set(values)
	for key, value in values do
		if config[key] == nil then
			error(string.format("Invalid config key `%s`", tostring(key)))
		end

		config[key] = value
	end
end

return Config
