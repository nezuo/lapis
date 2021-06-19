local DataStoreService = game:GetService("DataStoreService")

local defaultConfig = {
	retryAttempts = 5,
	showRetryWarnings = true,
	dataStoreService = DataStoreService,
}

local defaultConfigKeys = {}
for key in pairs(defaultConfig) do
	table.insert(defaultConfigKeys, key)
end

local function makeInvalidKeyError(key)
	return string.format(
		"Invalid config key %s. Valid config keys are: %s",
		tostring(key),
		table.concat(defaultConfigKeys, ", ")
	)
end

local currentConfig = setmetatable({}, {
	__index = function(_, key)
		error(makeInvalidKeyError(key))
	end,
})

local Config = {}

function Config.set(configValues)
	for key, value in pairs(configValues) do
		if defaultConfig[key] == nil then
			error(makeInvalidKeyError(key))
		end

		currentConfig[key] = value
	end
end

function Config.get(key)
	return currentConfig[key]
end

Config.set(defaultConfig)

return Config
