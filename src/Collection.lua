local HttpService = game:GetService("HttpService")

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
	if typeof(options.defaultData) ~= "function" then
		assert(options.validate(options.defaultData))
	end

	freezeDeep(options.defaultData)

	options.migrations = options.migrations or {}

	return setmetatable({
		dataStore = config:get("dataStoreService"):GetDataStore(name),
		options = options,
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
	if self.autoSave.gameClosed then
		-- If game:BindToClose has been called, this infinitely yields so the document can't load.
		return Promise.new(function() end)
	end

	local lockId = HttpService:GenerateGUID(false)

	self.autoSave.ongoingLoads += 1

	return self
		.data
		:load(self.dataStore, key, function(value, keyInfo)
			if value == nil then
				local defaultData
				if typeof(self.options.defaultData) == "function" then
					local defaultOk, tailoredDefaultData = pcall(self.options.defaultData, key)
					if not defaultOk then
						return "fail", `'defaultData' threw an error: {tailoredDefaultData}`
					end

					local validateOk, valid, message = pcall(self.options.validate, tailoredDefaultData)
					if not validateOk then
						return "fail", `'validate' threw an error: {valid}`
					elseif not valid then
						return "fail", `Invalid data: {message}`
					end

					defaultData = tailoredDefaultData
				else
					-- The data was validated when the collection was created
					defaultData = self.options.defaultData
				end

				local data = {
					migrationVersion = #self.options.migrations,
					lockId = lockId,
					data = defaultData,
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

			local migrationOk, migrated = Migration.migrate(self.options.migrations, value.migrationVersion, value.data)
			if not migrationOk then
				return "fail", migrated
			end

			local validateOk, valid, message = pcall(self.options.validate, migrated)
			if not validateOk then
				return "fail", `'validate' threw an error: {valid}`
			elseif not valid then
				return "fail", `Invalid data: {message}`
			end

			local data = {
				migrationVersion = #self.options.migrations,
				lockId = lockId,
				data = migrated,
			}

			return "succeed", data, keyInfo:GetUserIds(), keyInfo:GetMetadata()
		end)
		:andThen(function(value, keyInfo)
			if value == "cancelled" then
				self.autoSave.ongoingLoads -= 1

				-- Infinitely yield because the load was cancelled by game:BindToClose.
				return Promise.new(function() end)
			end

			local data = value.data

			freezeDeep(data)

			local document = Document.new(self, key, self.options.validate, lockId, data, keyInfo)

			self.autoSave:finishLoad(document)

			if self.autoSave.gameClosed then
				-- Infinitely yield because the document will automatically be closed.
				return Promise.new(function() end)
			end

			self.autoSave:addDocument(document)

			return document
		end)
		-- finally is used instead of catch so it doesn't handle rejection.
		:finally(function(status)
			if status ~= Promise.Status.Resolved then
				self.autoSave.ongoingLoads -= 1
			end
		end)
end

return Collection
