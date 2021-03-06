local Compression = require(script.Compression)
local Migration = require(script.Migration)
local Throttle = require(script.Throttle)

local Data = {}

function Data.unpack(value, migrations)
	if value == nil then
		return nil
	end

	return Migration.unpack(Compression.unpack(value), migrations)
end

function Data.pack(value, migrations)
	return Compression.pack(Migration.pack(value, migrations))
end

function Data.update(collection, key, transform)
	local data

	local ok, err = Throttle.update(collection._dataStore, key, function(oldValue)
		data = transform(Data.unpack(oldValue, collection.migrations))

		if data == nil then
			return nil
		end

		return Data.pack(data, collection.migrations)
	end)

	if not ok then
		error(err)
	end

	return data
end

return Data
