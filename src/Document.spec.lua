local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)

local DEFAULT_OPTIONS = {
	validate = function(data)
		return typeof(data.foo) == "string", "foo must be a string"
	end,
	defaultData = { foo = "bar" },
}

return function()
	it("it should not merge close into save when save is running", function(context)
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
		expect(saved.data.foo).to.equal("new")
	end)

	it("it should merge pending saves", function(context)
		local document = context.lapis.createCollection("collection", DEFAULT_OPTIONS):load("doc"):expect()

		context.dataStoreService.yield:startYield()

		local ongoingSave = document:save()

		local pendingSave = document:save()
		local pendingClose = document:close() -- This should override the pending save.

		context.dataStoreService.yield:stopYield()

		expect(pendingSave).to.equal(pendingClose)

		Promise.all({ ongoingSave, pendingSave, pendingClose }):expect()

		local saved = context.read("collection", "doc")

		expect(saved.lockId).never.to.be.ok()
	end)

	it("saves data", function(context)
		local document = context.lapis.createCollection("12345", DEFAULT_OPTIONS):load("doc"):expect()

		document:write({
			foo = "new value",
		})

		document:save():expect()

		local saved = context.read("12345", "doc")

		expect(saved).to.be.a("table")
		expect(saved.lockId).to.be.a("string")
		expect(saved.data.foo).to.equal("new value")
	end)

	it("writes the data", function(context)
		local document = context.lapis.createCollection("1", DEFAULT_OPTIONS):load("doc"):expect()

		document:write({
			foo = "baz",
		})

		expect(document:read().foo).to.equal("baz")
	end)

	it("write throws if data doesn't validate", function(context)
		local document = context.lapis.createCollection("2", DEFAULT_OPTIONS):load("doc"):expect()

		expect(function()
			document:write({
				foo = 5,
			})
		end).to.throw("foo must be a string")
	end)

	it("throws when writing/saving/closing a closed document", function(context)
		local document = context.lapis.createCollection("5", DEFAULT_OPTIONS):load("doc"):expect()

		local promise = document:close()

		expect(function()
			document:write({})
		end).to.throw("Cannot write to a closed document")

		expect(function()
			document:save()
		end).to.throw("Cannot save a closed document")

		expect(function()
			document:close()
		end).to.throw("Cannot close a closed document")

		promise:expect()
	end)

	it("loads with default data", function(context)
		local document = context.lapis.createCollection("o", DEFAULT_OPTIONS):load("a"):expect()

		expect(document:read().foo).to.equal("bar")
	end)

	it("loads with existing data", function(context)
		local collection = context.lapis.createCollection("xyz", DEFAULT_OPTIONS)

		context.write("xyz", "xyz", {
			foo = "existing",
		})

		local document = collection:load("xyz"):expect()

		expect(document:read().foo).to.equal("existing")
	end)

	it("doesn't save data when the lock was stolen", function(context)
		local collection = context.lapis.createCollection("hi", DEFAULT_OPTIONS)

		local document = collection:load("hi"):expect()

		context.write("hi", "hi", {
			foo = "stolen",
		}, "stolenLockId")

		document:write({
			foo = "qux",
		})

		expect(function()
			document:save():expect()
		end).to.throw("The session lock was stolen")

		expect(context.read("hi", "hi").data.foo).to.equal("stolen")

		expect(function()
			document:close():expect()
		end).to.throw("The session lock was stolen")

		expect(context.read("hi", "hi").data.foo).to.equal("stolen")
	end)

	it("doesn't throw when the budget is exhausted", function(context)
		local document = context.lapis.createCollection("bye", DEFAULT_OPTIONS):load("bye"):expect()

		context.dataStoreService.budget.budgets[Enum.DataStoreRequestType.GetAsync] = 0
		context.dataStoreService.budget.budgets[Enum.DataStoreRequestType.SetIncrementAsync] = 0
		context.dataStoreService.budget.budgets[Enum.DataStoreRequestType.UpdateAsync] = 0

		local promise = document:save()

		-- This updates the budget so that the document can save.
		context.clock:tick(1)

		expect(function()
			promise:expect()
		end).never.to.throw()
	end)
end
