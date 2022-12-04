local freezeDeep = require(script.Parent.freezeDeep)

local Migration = {}

function Migration.migrate(migrations, oldVersion, data)
	if oldVersion < #migrations then
		for version = oldVersion + 1, #migrations do
			local migrated = migrations[version](data)

			freezeDeep(migrated)

			data = migrated
		end
	end

	return data
end

return Migration
