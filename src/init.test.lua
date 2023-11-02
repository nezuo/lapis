local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataStoreServiceMock = require(ReplicatedStorage.DevPackages.DataStoreServiceMock)
local Internal = require(script.Parent.Internal)
local Promise = require(script.Parent.Parent.Promise)

local DEFAULT_OPTIONS = {
	validate = function(data)
		return typeof(data.apples) == "number", "apples should be a number"
	end,
	defaultData = {
		apples = 20,
	},
}

return function(x)
	local shouldThrow = x.shouldThrow

	x.beforeEach(function(context)
		local dataStoreService = DataStoreServiceMock.manual()

		context.dataStoreService = dataStoreService

		-- We want requests to overflow the throttle queue so that they result in errors.
		dataStoreService.budget:setMaxThrottleQueueSize(0)

		context.lapis = Internal.new(false)
		context.lapis.setConfig({ dataStoreService = dataStoreService, showRetryWarnings = false })

		context.write = function(name, key, data, lockId)
			local dataStore = dataStoreService.dataStores[name]["global"]

			dataStore:write(key, {
				compressionScheme = "None",
				migrationVersion = 0,
				lockId = lockId,
				data = data,
			})
		end

		context.read = function(name, key)
			return dataStoreService.dataStores[name]["global"].data[key]
		end

		context.expectUserIds = function(name, key, targetUserIds)
			local keyInfo = dataStoreService.dataStores[name]["global"].keyInfos[key]

			local currentUserIds = if keyInfo ~= nil then keyInfo:GetUserIds() else {}

			if #currentUserIds ~= #targetUserIds then
				error("Incorrect user ids length")
			end

			for index, value in targetUserIds do
				if currentUserIds[index] ~= value then
					error("Invalid user id")
				end
			end
		end
	end)

	x.test("throws when setting invalid config key", function(context)
		shouldThrow(function()
			context.lapis.setConfig({
				foo = true,
			})
		end, 'Invalid config key "foo"')
	end)

	x.test("throws when creating a duplicate collection", function(context)
		context.lapis.createCollection("foo", DEFAULT_OPTIONS)

		shouldThrow(function()
			context.lapis.createCollection("foo", DEFAULT_OPTIONS)
		end, 'Collection "foo" already exists')
	end)

	x.test("freezes default data", function(context)
		local defaultData = { a = { b = { c = 5 } } }

		context.lapis.createCollection("baz", {
			validate = function()
				return true
			end,
			defaultData = defaultData,
		})

		shouldThrow(function()
			defaultData.a.b.c = 8
		end)
	end)

	x.test("validates default data", function(context)
		shouldThrow(function()
			context.lapis.createCollection("bar", {
				validate = function()
					return false, "data is invalid"
				end,
			})
		end, "data is invalid")
	end)

	x.test("throws when loading invalid data", function(context)
		local collection = context.lapis.createCollection("apples", DEFAULT_OPTIONS)

		context.write("apples", "a", { apples = "string" })

		shouldThrow(function()
			collection:load("a"):expect()
		end, "apples should be a number")
	end)

	x.test("should session lock the document", function(context)
		local collection = context.lapis.createCollection("collection", DEFAULT_OPTIONS)
		local document = collection:load("doc"):expect()

		local otherLapis = Internal.new(false)
		otherLapis.setConfig({ dataStoreService = context.dataStoreService, loadAttempts = 1 })

		local otherCollection = otherLapis.createCollection("collection", DEFAULT_OPTIONS)

		shouldThrow(function()
			otherCollection:load("doc"):expect()
		end, "Could not acquire lock")

		-- It should keep the session lock when saved.
		document:save():expect()

		shouldThrow(function()
			otherCollection:load("doc"):expect()
		end, "Could not acquire lock")

		-- It should remove the session lock when closed.
		document:close():expect()

		otherCollection:load("doc"):expect()
	end)

	x.test("load should retry when document is session locked", function(context)
		local collection = context.lapis.createCollection("collection", DEFAULT_OPTIONS)
		local document = collection:load("doc"):expect()

		local otherLapis = Internal.new(false)
		otherLapis.setConfig({
			dataStoreService = context.dataStoreService,
			loadAttempts = 4,
			loadRetryDelay = 0.5,
			showRetryWarnings = false,
		})

		local otherCollection = otherLapis.createCollection("collection", DEFAULT_OPTIONS)
		local promise = otherCollection:load("doc")

		-- Wait for the document to attempt to load once.
		task.wait(0.1)

		-- Remove the sesssion lock.
		document:close():expect()

		promise:expect()
	end)

	x.test("load returns same promise/document", function(context)
		local collection = context.lapis.createCollection("def", DEFAULT_OPTIONS)

		local promise1 = collection:load("def")
		local promise2 = collection:load("def")

		assert(promise1 == promise2, "load returns different promises")

		Promise.all({ promise1, promise2 }):expect()

		assert(promise1:expect() == promise2:expect(), "promise resolved with different values")
	end)

	x.test("load returns a new promise when first load fails", function(context)
		context.lapis.setConfig({ loadAttempts = 1 })
		context.dataStoreService.errors:addSimulatedErrors(1)

		local collection = context.lapis.createCollection("ghi", DEFAULT_OPTIONS)

		local promise1 = collection:load("ghi")

		shouldThrow(function()
			promise1:expect()
		end)

		local promise2 = collection:load("ghi")

		assert(promise1 ~= promise2, "load should return new promise")

		promise2:expect()
	end)

	x.test("migrates the data", function(context)
		local collection = context.lapis.createCollection("migration", {
			validate = function(value)
				return value == "newData", "value does not equal newData"
			end,
			defaultData = "newData",
			migrations = {
				function()
					return "newData"
				end,
			},
		})

		context.write("migration", "migration", "data")

		collection:load("migration"):expect()
	end)

	x.test("throws when migration version is ahead of latest version", function(context)
		local collection = context.lapis.createCollection("collection", {
			validate = function()
				return true
			end,
			defaultData = "a",
		})

		local dataStore = context.dataStoreService.dataStores.collection.global
		dataStore:write("document", {
			compressionScheme = "None",
			migrationVersion = 1,
			data = "b",
		})

		local promise = collection:load("document")

		shouldThrow(function()
			promise:expect()
		end, "Saved migration version ahead of latest version")
	end)

	x.test("closing and immediately opening should return a new document", function(context)
		local collection = context.lapis.createCollection("ccc", DEFAULT_OPTIONS)

		local document = collection:load("doc"):expect()

		local close = document:close()
		local open = collection:load("doc")

		close:expect()

		local newDocument = open:expect()

		assert(newDocument ~= document, "")
	end)

	x.test("closes all document on game:BindToClose", function(context)
		local collection = context.lapis.createCollection("collection", DEFAULT_OPTIONS)

		local one = collection:load("one"):expect()
		local two = collection:load("two"):expect()
		local three = collection:load("three"):expect()

		context.dataStoreService.yield:startYield()

		local thread = task.spawn(function()
			context.lapis.autoSave:onGameClose()
		end)

		assert(coroutine.status(thread) == "suspended", "onGameClose didn't wait for the documents to finish closing")

		for _, document in { one, two, three } do
			shouldThrow(function()
				document:close():expect()
			end, "Cannot close a closed document")
		end

		context.dataStoreService.yield:stopYield()

		-- Wait for documents to finish saving.
		task.wait(0.1)

		assert(coroutine.status(thread) == "dead", "")
	end)

	x.nested("user ids", function()
		x.test("it uses defaultUserIds on first load", function(context)
			local collection = context.lapis.createCollection("collection", DEFAULT_OPTIONS)

			local document = collection:load("document", { 123 }):expect()
			context.expectUserIds("collection", "document", { 123 })
			document:close():expect()
			context.expectUserIds("collection", "document", { 123 })

			-- Since the document has already been created, the defaultUserIds should not override the saved ones.
			document = collection:load("document", { 321 }):expect()
			context.expectUserIds("collection", "document", { 123 })
			document:close():expect()
			context.expectUserIds("collection", "document", { 123 })
		end)

		x.test("adds new user ids", function(context)
			local collection = context.lapis.createCollection("collection", DEFAULT_OPTIONS)

			local document = collection:load("document", {}):expect()

			document:addUserId(111)
			document:addUserId(111) -- It should not add this user id twice.
			document:addUserId(222)

			context.expectUserIds("collection", "document", {})

			document:save():expect()

			context.expectUserIds("collection", "document", { 111, 222 })

			document:close():expect()

			context.expectUserIds("collection", "document", { 111, 222 })
		end)

		x.test("removes new user ids", function(context)
			local collection = context.lapis.createCollection("collection", DEFAULT_OPTIONS)

			local document = collection:load("document", { 333, 444, 555 }):expect()

			document:removeUserId(111) -- It should do nothing if the user id doesn't exist.
			document:removeUserId(444)

			context.expectUserIds("collection", "document", { 333, 444, 555 })

			document:save():expect()

			context.expectUserIds("collection", "document", { 333, 555 })

			document:close():expect()

			context.expectUserIds("collection", "document", { 333, 555 })
		end)
	end)
end
