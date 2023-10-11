local AutoSave = require(script.Parent.AutoSave)
local Collection = require(script.Parent.Collection)
local Config = require(script.Parent.Config)
local Data = require(script.Parent.Data)
local types = require(script.Parent.types)

local Internal = {}

function Internal.new<T>(enableAutoSave: boolean): types.Internal<T>
	local config = Config.new()
	local data = Data.new(config)
	local autoSave = AutoSave.new(data)

	if enableAutoSave then
		autoSave:start()
	end

	local usedCollections = {}

	local internal = {} :: types.Internal<T>

	if not enableAutoSave then
		internal.autoSave = autoSave
	end

	function internal.setConfig(values: types.PartialLapisConfigValues)
		config:set(values)
	end

	function internal.createCollection<U>(name: string, options: types.CollectionOptions<U>): types.Collection<U>
		if usedCollections[name] then
			error(`Collection "{name}" already exists`)
		end

		usedCollections[name] = true

		return Collection.new(name, options, data, autoSave, config)
	end

	return internal
end

return Internal
