local HttpService = game:GetService("HttpService")

local Compression = require(script.Parent.Compression)
local Document = require(script.Parent.Document)
local freezeDeep = require(script.Parent.freezeDeep)
local Migration = require(script.Parent.Migration)
local Promise = require(script.Parent.Parent.Promise)

local LOCK_EXPIRE = 30 * 60

--[=[
	Collections are analagous to [GlobalDataStore].

	@class Collection
]=]
local Collection = {}
Collection.__index = Collection

function Collection.new(name, options, data, autoSave, config)
	assert(options.validate(options.defaultData))

	freezeDeep(options.defaultData)

	options.migrations = options.migrations or {}

	return setmetatable({
		dataStore = config:get("dataStoreService"):GetDataStore(name),
		options = options,
		openDocuments = {},
		data = data,
		autoSave = autoSave,
	}, Collection)
end

--[=[
	Loads the document with `key`, migrates it, and session locks it.

	If specified, the document's `DataStoreKeyInfo:GetUserIds()` will be set to `defaultUserIds` if the document has
	never been loaded.

	@param key string
	@param defaultUserIds {number}?
	@return Promise<Document>
]=]
function Collection:load(key, defaultUserIds)
	if self.openDocuments[key] == nil then
		local lockId = HttpService:GenerateGUID(false)

		self.openDocuments[key] = self
			.data
			:load(self.dataStore, key, function(value, keyInfo)
				if value == nil then
					local data = {
						compressionScheme = "None",
						migrationVersion = #self.options.migrations,
						lockId = lockId,
						data = self.options.defaultData,
					}

					return "succeed", data, defaultUserIds
				end

				if value.migrationVersion > #self.options.migrations then
					return "fail", "Saved migration version ahead of latest version"
				end

				if
					value.lockId ~= nil
					and (DateTime.now().UnixTimestampMillis - keyInfo.UpdatedTime) / 1000 < LOCK_EXPIRE
				then
					return "retry", "Could not acquire lock"
				end

				local decompressed = Compression.decompress(value.compressionScheme, value.data)
				local migrated = Migration.migrate(self.options.migrations, value.migrationVersion, decompressed)
				local scheme, compressed = Compression.compress(migrated)

				local data = {
					compressionScheme = scheme,
					migrationVersion = #self.options.migrations,
					lockId = lockId,
					data = compressed,
				}

				return "succeed", data, keyInfo:GetUserIds(), keyInfo:GetMetadata()
			end)
			:andThen(function(value, keyInfo)
				local data = Compression.decompress(value.compressionScheme, value.data)

				local ok, message = self.options.validate(data)
				if not ok then
					return Promise.reject(message)
				end

				freezeDeep(data)

				local document = Document.new(self, key, self.options.validate, lockId, data, keyInfo:GetUserIds())

				self.autoSave:addDocument(document)

				return document
			end)
			-- finally is used instead of catch so it doesn't handle rejection.
			:finally(function(status)
				if status ~= Promise.Status.Resolved then
					self.openDocuments[key] = nil
				end
			end)
	end

	return self.openDocuments[key]
end

return Collection
