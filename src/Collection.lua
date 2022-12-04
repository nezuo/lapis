local HttpService = game:GetService("HttpService")

local Compression = require(script.Parent.Compression)
local Config = require(script.Parent.Config)
local Data = require(script.Parent.Data)
local Document = require(script.Parent.Document)
local freezeDeep = require(script.Parent.freezeDeep)
local Migration = require(script.Parent.Migration)
local Promise = require(script.Parent.Parent.Promise)
local UnixTimestampMillis = require(script.Parent.UnixTimestampMillis)

local LOCK_EXPIRE = 30 * 60

--[=[
	Collections are analagous to [GlobalDataStore].

	@class Collection
]=]
local Collection = {}
Collection.__index = Collection

function Collection.new(name, options)
	assert(options.validate(options.defaultData))

	freezeDeep(options.defaultData)

	options.migrations = options.migrations or {}

	return setmetatable({
		dataStore = Config.get("dataStoreService"):GetDataStore(name),
		options = options,
		openDocuments = {},
	}, Collection)
end

--[=[
	Loads the document with `key`, migrates it, and session locks it.

	@param key string
	@return Promise<Document>
]=]
function Collection:openDocument(key)
	if self.openDocuments[key] == nil then
		local lockId = HttpService:GenerateGUID(false)

		local promise = Data.load(self.dataStore, key, function(value, keyInfo)
			if value == nil then
				return {
					compressionScheme = "None",
					migrationVersion = #self.options.migrations,
					lockId = lockId,
					data = self.options.defaultData,
				}
			end

			if value.lockId ~= nil and (UnixTimestampMillis.get() - keyInfo.UpdatedTime) / 1000 < LOCK_EXPIRE then
				error("Could not acquire lock")
			end

			local decompressed = Compression.decompress(value.compressionScheme, value.data)
			local migrated = Migration.migrate(self.options.migrations, value.migrationVersion, decompressed)
			local scheme, compressed = Compression.compress(migrated)

			return {
				compressionScheme = scheme,
				migrationVersion = #self.options.migrations,
				lockId = lockId,
				data = compressed,
			}
		end):andThen(function(value)
			local data = Compression.decompress(value.compressionScheme, value.data)
			local ok, message = self.options.validate(data)

			if ok then
				return Document.new(self, key, self.options.validate, lockId, data)
			else
				return Promise.reject(message)
			end
		end)

		self.openDocuments[key] = promise

		-- finally is used instead of catch so it doesn't handle rejection.
		promise:finally(function(status)
			if status ~= Promise.Status.Resolved then
				self.openDocuments[key] = nil
			end
		end)

		return promise
	end

	return self.openDocuments[key]
end

return Collection
