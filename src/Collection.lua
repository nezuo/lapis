local HttpService = game:GetService("HttpService")

local Constants = require(script.Parent.Constants)
local copyDeep = require(script.Parent.copyDeep)
local Data = require(script.Parent.Data)
local Document = require(script.Parent.Document)
local Error = require(script.Parent.Error)
local Promise = require(script.Parent.Parent.Promise)
local getDataStoreService = require(script.Parent.getDataStoreService).getDataStoreService

local function getDefaultData(defaultData, lockId)
	return {
		createdAt = os.time(),
		updatedAt = os.time(),
		lockId = lockId,
		data = copyDeep(defaultData),
	}
end

local Collection = {}
Collection.__index = Collection

function Collection.new(name, options)
	assert(typeof(options) == "table", "`options` must be a table")
	assert(typeof(options.validate) == "function", "`options.validate` must be a function")
	assert(options.validate(options.defaultData))

	return setmetatable({
		_dataStore = getDataStoreService():GetDataStore(name),
		_defaultData = options.defaultData,
		_openDocumentPromises = {},
		migrations = options.migrations or {},
		name = name,
		validate = options.validate,
	}, Collection)
end

function Collection:_openDocument(name)
	local lockId = HttpService:GenerateGUID(false)

	return Promise.new(function(resolve, reject)
		local data = Data.update(self, name, function(oldValue)
			if oldValue == nil then
				return getDefaultData(self._defaultData, lockId)
			end

			if oldValue.lockId ~= nil and os.time() - oldValue.updatedAt < Constants.LOCK_EXPIRE then
				return nil
			end

			oldValue.updatedAt = os.time()
			oldValue.lockId = lockId

			return oldValue
		end)

		if data == nil then
			reject(Error.new(Error.Kind.CouldNotAcquireLock))
		else
			resolve(data)
		end
	end):andThen(function(data)
		return Promise.try(function()
			assert(self.validate(data.data))

			return Document.new(self, name, data, lockId)
		end)
	end)
end

function Collection:_removeDocument(name)
	self._openDocumentPromises[name] = nil
end

function Collection:openDocument(name)
	if self._openDocumentPromises[name] == nil then
		local promise = self:_openDocument(name)

		self._openDocumentPromises[name] = promise

		promise:catch(function()
			self:_removeDocument(name)
		end)

		return Promise.resolve(promise)
	end

	return Promise.resolve(self._openDocumentPromises[name])
end

return Collection
