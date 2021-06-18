local function callDataStore(dataStore, methodName, ...)
	return dataStore[methodName](dataStore, ...)
end

return callDataStore
