local Internal = require(script.Internal)
local types = require(script.types)

local internal = Internal.new(true)

export type Document<T> = types.Document<T>
export type Collection<T> = types.Collection<T>

--[=[
	@class Lapis
]=]
local Lapis = {}

--[=[
	@interface ConfigValues
	@within Lapis
	.saveAttempts number? -- Max save/close retry attempts
	.loadAttempts number? -- Max load retry attempts
	.loadRetryDelay number? -- Seconds between load attempts
	.showRetryWarnings boolean? -- Show warning on retry
	.dataStoreService (DataStoreService | table)? -- Useful for mocking DataStoreService, especially in a local place
]=]

--[=[
	```lua
	Lapis.setConfig({
		saveAttempts = 10,
		showRetryWarnings = false,
	})
	```

	```lua
	-- The default config values:
	{
		saveAttempts = 5,
		loadAttempts = 20,
		loadRetryDelay = 1,
		showRetryWarnings = true,
		dataStoreService = DataStoreService,
	}
	```

	@param values ConfigValues
]=]
function Lapis.setConfig(values: types.PartialLapisConfigValues)
	internal.setConfig(values)
end

--[=[
	@interface CollectionOptions
	@within Lapis
	.validate (any) -> true | (false, string) -- Takes a document's data and returns true on success or false and an error on fail.
	.defaultData any
	.migrations { (any) -> any } -- Migrations take old data and return new data. Order is first to last.
]=]

--[=[
	Creates a [Collection].

	@param name string
	@param options CollectionOptions
	@return Collection
]=]
function Lapis.createCollection<T>(name: string, options: types.CollectionOptions<T>): types.Collection<T>
	return internal.createCollection(name, options)
end

return Lapis
