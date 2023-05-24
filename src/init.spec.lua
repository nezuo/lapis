local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Clock)
local DataStoreServiceMock = require(ReplicatedStorage.ServerPackages.DataStoreServiceMock)
local Lapis = require(script.Parent)
local Promise = require(script.Parent.Parent.Promise)
local UnixTimestampMillis = require(script.Parent.UnixTimestampMillis)

local SUPER_SPEED = true
local DEFAULT_OPTIONS = {
	validate = function(data)
		return typeof(data.apples) == "number", "apples should be a number"
	end,
	defaultData = {
		apples = 20,
	},
}

if SUPER_SPEED then
	print("Running tests at SUPER SPEED.")
else
	print("Running tests at NORMAL SPEED.")
end

Lapis.setConfig({ showRetryWarnings = false })

return function()
	beforeEach(function(context)
		local dataStoreService = if SUPER_SPEED then DataStoreServiceMock.manual() else DataStoreServiceMock.new()

		context.dataStoreService = dataStoreService

		-- We want requests to overflow the throttle queue so that they result in errors.
		dataStoreService.budget:setMaxThrottleQueueSize(0)

		Lapis.setConfig({ dataStoreService = dataStoreService })

		context.clock = Clock.new(dataStoreService, SUPER_SPEED)

		UnixTimestampMillis.get = function()
			return context.clock:now() * 1000
		end

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

		if SUPER_SPEED then
			Promise.delay = function(duration)
				return Promise.new(function(resolve)
					context.clock:addTask({
						resumeAt = context.clock:now() + duration,
						resume = resolve,
					})
				end)
			end
		end
	end)

	afterEach(function(context)
		-- Complete any remaining write cooldowns.
		context.clock:tick(6)
	end)

	it("throws when setting invalid config key", function()
		expect(function()
			Lapis.setConfig({
				foo = true,
			})
		end).to.throw('Invalid config key "foo"')
	end)

	it("throws when creating a duplicate collection", function()
		Lapis.createCollection("foo", DEFAULT_OPTIONS)

		expect(function()
			Lapis.createCollection("foo", DEFAULT_OPTIONS)
		end).to.throw('Collection "foo" already exists')
	end)

	it("freezes default data", function()
		local defaultData = {
			a = {
				b = {
					c = 5,
				},
			},
		}

		Lapis.createCollection("baz", {
			validate = function()
				return true
			end,
			defaultData = defaultData,
		})

		expect(function()
			defaultData.a.b.c = 8
		end).to.throw()
	end)

	it("validates default data", function()
		expect(function()
			Lapis.createCollection("bar", {
				validate = function()
					return false, "data is invalid"
				end,
			})
		end).to.throw("data is invalid")
	end)

	it("throws when loading invalid data", function(context)
		local collection = Lapis.createCollection("apples", DEFAULT_OPTIONS)

		context.write("apples", "a", { apples = "string" })

		expect(function()
			collection:load("a"):expect()
		end).to.throw("apples should be a number")
	end)

	it("load throws when document is already locked", function(context)
		local collection = Lapis.createCollection("abc", DEFAULT_OPTIONS)

		context.write("abc", "abc", { apples = 2 }, 12345)

		local promise = collection:load("abc")

		context.clock:tick(19)

		expect(function()
			promise:expect()
		end).to.throw("Could not acquire lock")
	end)

	it("load continuously tries to get the lock", function(context)
		local collection = Lapis.createCollection("lock", DEFAULT_OPTIONS)

		context.write("lock", "lock", { apples = 2 }, "lockId")

		local promise = collection:load("lock")

		context.clock:tick(18)

		expect(promise:getStatus()).to.equal(Promise.Status.Started)

		-- Remove the lock.
		context.write("lock", "lock", { apples = 2 })

		context.clock:tick(1)

		expect(function()
			promise:expect()
		end).never.to.throw()
	end)

	it("load returns same promise/document", function()
		local collection = Lapis.createCollection("def", DEFAULT_OPTIONS)

		local promise1 = collection:load("def")
		local promise2 = collection:load("def")

		expect(promise1).to.equal(promise2)

		Promise.all({ promise1, promise2 }):expect()

		expect(promise1:expect()).to.equal(promise2:expect())
	end)

	it("load returns a new promise when first load fails", function(context)
		local collection = Lapis.createCollection("ghi", DEFAULT_OPTIONS)

		context.dataStoreService.errors:addSimulatedErrors(20)

		local promise1 = collection:load("ghi")

		context.clock:tick(19)

		expect(function()
			promise1:expect()
		end).to.throw()

		local promise2 = collection:load("ghi")

		expect(promise1).never.to.equal(promise2)

		promise2:expect()
	end)

	it("migrates the data", function(context)
		local collection = Lapis.createCollection("migration", {
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

	it("closing and immediately opening should return a new document", function(context)
		local collection = Lapis.createCollection("ccc", DEFAULT_OPTIONS)

		local document = collection:load("doc"):expect()

		local close = document:close()
		local open = collection:load("doc")

		context.clock:tick(6)

		close:expect()

		context.clock:tick(6)

		local newDocument = open:expect()

		expect(newDocument).never.to.equal(document)
	end)
end
