local Collection = require(script.Collection)
local Error = require(script.Error)

local collections = {}

local Lapis = {
	Error = Error,
}

function Lapis.createCollection(name, options)
	if collections[name] ~= nil then
		error(Error.new(Error.Kind.CollectionAlreadyExists, string.format("Collection %s already exists", name)))
	end

	collections[name] = Collection.new(name, options)

	return collections[name]
end

return Lapis
