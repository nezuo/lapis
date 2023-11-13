local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)

local DEFAULT_OPTIONS = {
	validate = function(data)
		return typeof(data.foo) == "string", "foo must be a string"
	end,
	defaultData = { foo = "bar" },
}

return function(x)
	local assertEqual = x.assertEqual
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

		local values = Promise.all({ ongoingSave, pendingSave }):expect()

		-- This stops the close if it wasn't merged.
		context.dataStoreService.yield:startYield()

		-- Since the following code is resumed by the save promise, we need to wait for the close promise to resolve.
		task.wait()

		pendingClose:now("save and close didn't merge"):expect()

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

	x.test("freezes document data", function(context)
		local collection = context.lapis.createCollection("collection", {
			validate = function()
				return true
			end,
			defaultData = {},
		})

		context.write("collection", "document", { a = { b = 1 } })

		local document = collection:load("document"):expect()

		shouldThrow(function()
			document:read().a.b = 2
		end)

		document:write({ a = { b = 2 } })

		shouldThrow(function()
			document:read().a.b = 3
		end)
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

	x.nested("Document:beforeSave", function()
		x.test("throws when setting twice", function(context)
			local document = context.lapis.createCollection("collection", DEFAULT_OPTIONS):load("document"):expect()

			document:beforeSave(function() end)

			shouldThrow(function()
				document:beforeSave(function() end)
			end, "Document:beforeSave can only be called once")
		end)

		x.test("throws when calling close in callback", function(context)
			local document = context.lapis.createCollection("collection", DEFAULT_OPTIONS):load("document"):expect()

			document:beforeSave(function()
				document:close()
			end)

			shouldThrow(function()
				document:close():expect()
			end, "beforeSave callback threw error")
		end)

		x.test("throws when calling save in callback", function(context)
			local document = context.lapis.createCollection("collection", DEFAULT_OPTIONS):load("document"):expect()

			document:beforeSave(function()
				document:save()
			end)

			shouldThrow(function()
				document:close():expect()
			end, "beforeSave callback threw error")
		end)

		x.test("saves new data in document:save", function(context)
			local document = context.lapis.createCollection("collection", DEFAULT_OPTIONS):load("document"):expect()

			document:beforeSave(function()
				document:read() -- This checks that read doesn't error in the callback.
				document:write({ foo = "new" })
			end)

			document:save():expect()

			assertEqual(context.read("collection", "document").data.foo, "new")
		end)

		x.test("saves new data in document:close", function(context)
			local document = context.lapis.createCollection("collection", DEFAULT_OPTIONS):load("document"):expect()

			document:beforeSave(function()
				document:write({ foo = "new" })
			end)

			document:close():expect()

			assertEqual(context.read("collection", "document").data.foo, "new")
		end)
	end)

	x.nested("Document:beforeClose", function()
		x.test("throws when setting twice", function(context)
			local document = context.lapis.createCollection("collection", DEFAULT_OPTIONS):load("document"):expect()

			document:beforeClose(function() end)

			shouldThrow(function()
				document:beforeClose(function() end)
			end, "Document:beforeClose can only be called once")
		end)

		x.test("throws when calling close in callback", function(context)
			local document = context.lapis.createCollection("collection", DEFAULT_OPTIONS):load("document"):expect()

			document:beforeClose(function()
				document:close()
			end)

			shouldThrow(function()
				document:close():expect()
			end, "beforeClose callback threw error")
		end)

		x.test("throws when calling save in callback", function(context)
			local document = context.lapis.createCollection("collection", DEFAULT_OPTIONS):load("document"):expect()

			document:beforeClose(function()
				document:save()
			end)

			shouldThrow(function()
				document:close():expect()
			end, "beforeClose callback threw error")
		end)

		x.test("closes document even if beforeClose errors", function(context)
			local collection = context.lapis.createCollection("collection", DEFAULT_OPTIONS)

			local promise = collection:load("document")
			local document = promise:expect()

			document:beforeClose(function()
				error("error")
			end)

			shouldThrow(function()
				document:close():expect()
			end)

			local secondPromise = collection:load("document")

			assert(secondPromise ~= promise, "collection:load should return a new promise")

			shouldThrow(function()
				document:write({ foo = "baz" })
			end, "Cannot write to a closed document")

			-- Ignore the could not acquire lock error.
			secondPromise:catch(function() end)
		end)

		x.test("saves new data", function(context)
			local document = context.lapis.createCollection("collection", DEFAULT_OPTIONS):load("document"):expect()

			document:beforeClose(function()
				document:read() -- This checks that read doesn't error in the callback.

				document:write({ foo = "new" })
			end)

			document:close():expect()

			assertEqual(context.read("collection", "document").data.foo, "new")
		end)

		x.test("beforeSave runs before beforeClose", function(context)
			local document = context.lapis.createCollection("collection", DEFAULT_OPTIONS):load("document"):expect()

			local order = ""

			document:beforeSave(function()
				order ..= "s"
			end)

			document:beforeClose(function()
				order ..= "c"
			end)

			document:close():expect()

			assertEqual(order, "sc")
		end)
	end)
end
