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

return function()
	beforeEach(function(context)
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
	end)

	it("throws when setting invalid config key", function(context)
		expect(function()
			context.lapis.setConfig({
				foo = true,
			})
		end).to.throw('Invalid config key "foo"')
	end)

	it("throws when creating a duplicate collection", function(context)
		context.lapis.createCollection("foo", DEFAULT_OPTIONS)

		expect(function()
			context.lapis.createCollection("foo", DEFAULT_OPTIONS)
		end).to.throw('Collection "foo" already exists')
	end)

	it("freezes default data", function(context)
		local defaultData = { a = { b = { c = 5 } } }

		context.lapis.createCollection("baz", {
			validate = function()
				return true
			end,
			defaultData = defaultData,
		})

		expect(function()
			defaultData.a.b.c = 8
		end).to.throw()
	end)

	it("validates default data", function(context)
		expect(function()
			context.lapis.createCollection("bar", {
				validate = function()
					return false, "data is invalid"
				end,
			})
		end).to.throw("data is invalid")
	end)

	it("throws when loading invalid data", function(context)
		local collection = context.lapis.createCollection("apples", DEFAULT_OPTIONS)

		context.write("apples", "a", { apples = "string" })

		expect(function()
			collection:load("a"):expect()
		end).to.throw("apples should be a number")
	end)

	it("should session lock the document", function(context)
		local collection = context.lapis.createCollection("collection", DEFAULT_OPTIONS)
		local document = collection:load("doc", DEFAULT_OPTIONS):expect()

		local otherLapis = Internal.new(false)
		otherLapis.setConfig({ dataStoreService = context.dataStoreService, loadAttempts = 1 })

		local otherCollection = otherLapis.createCollection("collection", DEFAULT_OPTIONS)

		expect(function()
			otherCollection:load("doc"):expect()
		end).to.throw("Could not acquire lock")

		-- It should keep the session lock when saved.
		document:save():expect()

		expect(function()
			otherCollection:load("doc"):expect()
		end).to.throw("Could not acquire lock")

		-- It should remove the session lock when closed.
		document:close():expect()

		expect(function()
			otherCollection:load("doc"):expect()
		end).never.to.throw()
	end)

	it("load should retry when document is session loked", function(context)
		local collection = context.lapis.createCollection("collection", DEFAULT_OPTIONS)
		local document = collection:load("doc", DEFAULT_OPTIONS):expect()

		local otherLapis = Internal.new(false)
		otherLapis.setConfig({
			dataStoreService = context.dataStoreService,
			loadAttempts = 2,
			loadRetryDelay = 0.5,
			showRetryWarnings = false,
		})

		local otherCollection = otherLapis.createCollection("collection", DEFAULT_OPTIONS)
		local promise = otherCollection:load("doc")

		-- Wait for the document to attempt to load once.
		task.wait(0.1)

		-- Remove the sesssion lock.
		document:close():expect()

		expect(function()
			promise:expect()
		end).never.to.throw()
	end)

	it("load returns same promise/document", function(context)
		local collection = context.lapis.createCollection("def", DEFAULT_OPTIONS)

		local promise1 = collection:load("def")
		local promise2 = collection:load("def")

		expect(promise1).to.equal(promise2)

		Promise.all({ promise1, promise2 }):expect()

		expect(promise1:expect()).to.equal(promise2:expect())
	end)

	it("load returns a new promise when first load fails", function(context)
		context.lapis.setConfig({ loadAttempts = 1 })
		context.dataStoreService.errors:addSimulatedErrors(1)

		local collection = context.lapis.createCollection("ghi", DEFAULT_OPTIONS)

		local promise1 = collection:load("ghi")

		expect(function()
			promise1:expect()
		end).to.throw()

		local promise2 = collection:load("ghi")

		expect(promise1).never.to.equal(promise2)

		promise2:expect()
	end)

	it("migrates the data", function(context)
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

		expect(function()
			collection:load("migration"):expect()
		end).never.to.throw()
	end)

	it("throws when migration version is ahead of latest version", function(context)
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

		expect(function()
			promise:expect()
		end).to.throw("Saved migration version ahead of latest version")
	end)

	it("closing and immediately opening should return a new document", function(context)
		local collection = context.lapis.createCollection("ccc", DEFAULT_OPTIONS)

		local document = collection:load("doc"):expect()

		local close = document:close()
		local open = collection:load("doc")

		close:expect()

		local newDocument = open:expect()

		expect(newDocument).never.to.equal(document)
	end)

	it("closes all document on game:BindToClose", function(context)
		local collection = context.lapis.createCollection("collection", DEFAULT_OPTIONS)

		local one = collection:load("one"):expect()
		local two = collection:load("two"):expect()
		local three = collection:load("three"):expect()

		context.dataStoreService.yield:startYield()

		local thread = task.spawn(function()
			context.lapis.autoSave:onGameClose()
		end)

		-- This is to make sure onGameClose is waiting for the documents to finish closing.
		expect(coroutine.status(thread)).to.equal("suspended")

		for _, document in { one, two, three } do
			expect(function()
				document:close():expect()
			end).to.throw("Cannot close a closed document")
		end

		context.dataStoreService.yield:stopYield()

		-- Wait for documents to finish saving.
		task.wait(0.1)

		expect(coroutine.status(thread)).to.equal("dead")
	end)
end
