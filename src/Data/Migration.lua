local Migration = {}

function Migration.pack(data, migrations)
	return {
		data = data,
		migrationVersion = #migrations,
	}
end

local function assertValidMigration(oldValue, migrated, migrationVersion)
	if typeof(migrated) ~= "table" then
		error(string.format("Migration %i must return a table", migrationVersion))
	end

	if typeof(migrated.validate) ~= "function" then
		error(string.format("Migration %i must return a validate function", migrationVersion))
	end

	local ok, err = migrated.validate(oldValue)

	if not ok then
		error(string.format("Migration %i failed validation: %s", migrationVersion, err))
	end

	if oldValue == migrated.value then
		error(string.format("Migration %i changed value mutably", migrationVersion))
	end
end

function Migration.unpack(migration, migrations)
	local data = migration.data
	local version = migration.migrationVersion

	if version < #migrations then
		for migrationVersion = version + 1, #migrations do
			local currentData = data.data

			local migrated = migrations[migrationVersion](currentData)

			assertValidMigration(currentData, migrated, migrationVersion)

			data.data = migrated.value
		end
	end

	return data
end

return Migration
