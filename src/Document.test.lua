local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)

local DEFAULT_OPTIONS = {
	validate = function(data)
		return typeof(data.foo) == "string", "foo must be a string"
	end,
	defaultData = { foo = "bar" },
}

return function(x)
	local shouldThrow = x.shouldThrow

	x.test("it should not merge close into save when save is running", function(context)
		local document = context.lapis.createCollection("collection", DEFAULT_OPTIONS):load("doc"):expect()

		-- It's not safe to merge saves when UpdateAsync is running.
		-- This will yield the UpdateAsync call until stopYield is called.
		context.dataStoreService.yield:startYield()

		local save = document:save()
		document:write({ foo = "new" })
		local close = document:close()

		context.dataStoreService.yield:stopYield()

		Promise.all({ save, close }):expect()

		local saved = context.read("collection", "doc")

		-- If data.foo == "bar", that means the close was merged with the save when it wasn't safe to.
		assert(saved.data.foo == "new", "")
	end)

	x.test("it should merge pending saves", function(context)
		local document = context.lapis.createCollection("collection", DEFAULT_OPTIONS):load("doc"):expect()

		context.dataStoreService.yield:startYield()

		local ongoingSave = document:save()

		local pendingSave = document:save()
		local pendingClose = document:close() -- This should override the pending save.

		context.dataStoreService.yield:stopYield()

		assert(pendingSave == pendingClose, "save and close didn't merge")

		local values = Promise.all({ ongoingSave, pendingSave, pendingClose }):expect()

		-- save and close should never resolve with a value.
		-- It's checked in this test to make sure it works with save merging.
		assert(#values == 0, "")

		local saved = context.read("collection", "doc")

		assert(saved.lockId == nil, "")
	end)

	x.test("saves data", function(context)
		local document = context.lapis.createCollection("12345", DEFAULT_OPTIONS):load("doc"):expect()

		document:write({
			foo = "new value",
		})

		document:save():expect()

		local saved = context.read("12345", "doc")

		assert(typeof(saved) == "table", "")
		assert(typeof(saved.lockId) == "string", "")
		assert(saved.data.foo == "new value", "")
	end)

	x.test("writes the data", function(context)
		local document = context.lapis.createCollection("1", DEFAULT_OPTIONS):load("doc"):expect()

		document:write({
			foo = "baz",
		})

		assert(document:read().foo == "baz", "")
	end)

	x.test("write throws if data doesn't validate", function(context)
		local document = context.lapis.createCollection("2", DEFAULT_OPTIONS):load("doc"):expect()

		shouldThrow(function()
			document:write({
				foo = 5,
			})
		end, "foo must be a string")
	end)

	x.test("throws when writing/saving/closing a closed document", function(context)
		local document = context.lapis.createCollection("5", DEFAULT_OPTIONS):load("doc"):expect()

		local promise = document:close()

		shouldThrow(function()
			document:write({})
		end, "Cannot write to a closed document")

		shouldThrow(function()
			document:save()
		end, "Cannot save a closed document")

		shouldThrow(function()
			document:close()
		end, "Cannot close a closed document")

		promise:expect()
	end)

	x.test("loads with default data", function(context)
		local document = context.lapis.createCollection("o", DEFAULT_OPTIONS):load("a"):expect()

		assert(document:read().foo == "bar", "")
	end)

	x.test("loads with existing data", function(context)
		local collection = context.lapis.createCollection("xyz", DEFAULT_OPTIONS)

		context.write("xyz", "xyz", {
			foo = "existing",
		})

		local document = collection:load("xyz"):expect()

		assert(document:read().foo == "existing", "")
	end)

	x.test("doesn't save data when the lock was stolen", function(context)
		local collection = context.lapis.createCollection("hi", DEFAULT_OPTIONS)

		local document = collection:load("hi"):expect()

		context.write("hi", "hi", {
			foo = "stolen",
		}, "stolenLockId")

		document:write({
			foo = "qux",
		})

		shouldThrow(function()
			document:save():expect()
		end, "The session lock was stolen")

		assert(context.read("hi", "hi").data.foo == "stolen", "")

		shouldThrow(function()
			document:close():expect()
		end, "The session lock was stolen")

		assert(context.read("hi", "hi").data.foo == "stolen", "")
	end)

	x.test("doesn't throw when the budget is exhausted", function(context)
		-- This makes sure the test doesn't pass by retyring after budget is added.
		context.lapis.setConfig({ loadAttempts = 1 })

		local document = context.lapis.createCollection("bye", DEFAULT_OPTIONS):load("bye"):expect()

		context.dataStoreService.budget.budgets[Enum.DataStoreRequestType.GetAsync] = 0
		context.dataStoreService.budget.budgets[Enum.DataStoreRequestType.SetIncrementAsync] = 0
		context.dataStoreService.budget.budgets[Enum.DataStoreRequestType.UpdateAsync] = 0

		local promise = document:save()

		-- This wait is necessary so that the request is run by Throttle.
		task.wait(0.1)

		context.dataStoreService.budget:update()

		promise:expect()
	end)
end
