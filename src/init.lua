local Collection = require(script.Collection)
local Config = require(script.Config)
local Error = require(script.Error)

local usedCollections = {}

local Lapis = {
	Error = Error,
	setGlobalConfig = Config.set,
}

function Lapis.createCollection(name, options)
	if usedCollections[name] then
		error(string.format("Collection `%s` already exists", name))
	end

	usedCollections[name] = true

	return Collection.new(name, options)
end

return Lapis
