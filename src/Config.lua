local DataStoreService = game:GetService("DataStoreService")

local config = {
	saveAttempts = 5,
	loadAttempts = 20,
	loadRetryDelay = 1,
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
			error(`Invalid config key "{tostring(key)}"`)
		end

		config[key] = value
	end
end

return Config
