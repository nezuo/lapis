local HttpService = game:GetService("HttpService")

local Constants = require(script.Parent.Constants)
local copyDeep = require(script.Parent.copyDeep)
local Data = require(script.Parent.Data)
local Document = require(script.Parent.Document)
local Error = require(script.Parent.Error)
local Promise = require(script.Parent.Parent.Promise)
local Config = require(script.Parent.Config)

local Collection = {}
Collection.__index = Collection

function Collection.new(name, options)
	assert(typeof(options) == "table", "`options` must be a table")
	assert(typeof(options.validate) == "function", "`options.validate` must be a function")
	assert(options.validate(options.defaultData))

	return setmetatable({
		_dataStore = Config.get("dataStoreService"):GetDataStore(name),
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
				return {
					createdAt = os.time(),
					updatedAt = os.time(),
					lockId = lockId,
					data = copyDeep(self._defaultData),
				}
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
		local ok, message = self.validate(data.data)

		if not ok then
			return Promise.reject(message)
		else
			return Promise.resolve(Document.new(self, name, data, lockId))
		end
	end)
end

function Collection:_removeDocument(name)
	self._openDocumentPromises[name] = nil
end

function Collection:openDocument(name)
	if self._openDocumentPromises[name] == nil then
		local promise = self:_openDocument(name)

		self._openDocumentPromises[name] = promise

		-- We use finally instead of catch so it doesn't handle rejection. Otherwise, the promise could silently error.
		promise:finally(function(status)
			if status ~= Promise.Status.Resolved then
				self:_removeDocument(name)
			end
		end)

		return promise
	end

	return self._openDocumentPromises[name]
end

return Collection
