local DataStoreService = game:GetService("DataStoreService")

local currentConfig = {
	retryAttempts = 5,
	showRetryWarnings = true,
	dataStoreService = DataStoreService,
}

local validKeys = {}
for key in currentConfig do
	table.insert(validKeys, key)
end

local function makeInvalidKeyError(key)
	return string.format("Invalid config key `%s`. Valid keys are: %s", tostring(key), table.concat(validKeys, ", "))
end

local Config = {}

function Config.set(configValues)
	for key, value in configValues do
		if currentConfig[key] == nil then
			error(makeInvalidKeyError(key))
		end

		currentConfig[key] = value
	end
end

function Config.get(key)
	if currentConfig[key] == nil then
		error(makeInvalidKeyError(key))
	end

	return currentConfig[key]
end

return Config
