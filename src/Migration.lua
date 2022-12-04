local freezeDeep = require(script.Parent.freezeDeep)

local Migration = {}

function Migration.migrate(migrations, value)
	local oldVersion = value.migrationVersion

	if oldVersion < #migrations then
		for version = oldVersion + 1, #migrations do
			local migrated = migrations[version](value.data)

			freezeDeep(migrated)

			value.data = migrated
		end

		value.migrationVersion = #migrations
	end
end

return Migration
