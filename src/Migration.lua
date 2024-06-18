local Migration = {}

function Migration.migrate(migrations, oldVersion, data)
	if oldVersion < #migrations then
		for version = oldVersion + 1, #migrations do
			local ok, migrated = pcall(migrations[version], data)
			if not ok then
				return false, `Migration {version} threw an error: {migrated}`
			end

			if migrated == nil then
				return false, `Migration {version} returned 'nil'`
			end

			data = migrated
		end
	end

	return true, data
end

return Migration
