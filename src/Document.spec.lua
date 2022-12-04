local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lapis = require(ReplicatedStorage.Packages.Lapis)
local Promise = require(ReplicatedStorage.Packages.Promise)

local DEFAULT_OPTIONS = {
	validate = function(data)
		return typeof(data.foo) == "string", "foo must be a string"
	end,
	defaultData = { foo = "bar" },
}

return function()
	it("combines save and close requests", function(context)
		local document = Lapis.createCollection("fff", DEFAULT_OPTIONS):openDocument("doc"):expect()

		document:write({
			foo = "updated value",
		})

		local save = document:save()
		local close = document:close()

		-- Finish the write cooldown from opening the document.
		context.clock:tick(6)

		Promise.all({ save, close }):expect()

		expect(save).to.equal(close)

		local saved = context.read("fff", "doc")

		expect(saved).to.be.a("table")
		expect(saved.lockId).never.to.be.ok()
		expect(saved.data.foo).to.equal("updated value")
	end)

	it("saves data", function(context)
		local document = Lapis.createCollection("12345", DEFAULT_OPTIONS):openDocument("doc"):expect()

		-- Finish the write cooldown from opening the document.
		context.clock:tick(6)

		document:write({
			foo = "new value",
		})

		document:save():expect()

		local saved = context.read("12345", "doc")

		expect(saved).to.be.a("table")
		expect(saved.lockId).to.be.a("string")
		expect(saved.data.foo).to.equal("new value")
	end)

	it("writes the data", function()
		local document = Lapis.createCollection("1", DEFAULT_OPTIONS):openDocument("doc"):expect()

		document:write({
			foo = "baz",
		})

		expect(document:read().foo).to.equal("baz")
	end)

	it("write throws if data doesn't validate", function()
		local document = Lapis.createCollection("2", DEFAULT_OPTIONS):openDocument("doc"):expect()

		expect(function()
			document:write({
				foo = 5,
			})
		end).to.throw("foo must be a string")
	end)

	it("throws when writing/saving/closing a closed document", function(context)
		local document = Lapis.createCollection("5", DEFAULT_OPTIONS):openDocument("doc"):expect()

		context.clock:tick(6)

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
		local document = Lapis.createCollection("o", DEFAULT_OPTIONS):openDocument("a"):expect()

		expect(document:read().foo).to.equal("bar")
	end)

	it("loads with existing data", function(context)
		local collection = Lapis.createCollection("xyz", DEFAULT_OPTIONS)

		context.write("xyz", "xyz", {
			foo = "existing",
		})

		local document = collection:openDocument("xyz"):expect()

		expect(document:read().foo).to.equal("existing")
	end)

	it("doesn't save data when the lock was stolen", function(context)
		local collection = Lapis.createCollection("hi", DEFAULT_OPTIONS)

		local document = collection:openDocument("hi"):expect()

		context.write("hi", "hi", {
			foo = "stolen",
		}, "stolenLockId")

		document:write({
			foo = "qux",
		})

		context.clock:tick(6)

		expect(function()
			document:save():expect()
		end).to.throw("The session lock was stolen")

		expect(context.read("hi", "hi").data.foo).to.equal("stolen")

		context.clock:tick(6)

		expect(function()
			document:close():expect()
		end).to.throw("The session lock was stolen")

		expect(context.read("hi", "hi").data.foo).to.equal("stolen")
	end)

	it("doesn't throw when the budget is exhausted", function(context)
		local document = Lapis.createCollection("bye", DEFAULT_OPTIONS):openDocument("bye"):expect()

		context.clock:tick(6)

		context.dataStoreService.budget.budgets[Enum.DataStoreRequestType.GetAsync] = 0
		context.dataStoreService.budget.budgets[Enum.DataStoreRequestType.SetIncrementAsync] = 0
		context.dataStoreService.budget.budgets[Enum.DataStoreRequestType.UpdateAsync] = 0

		local promise = document:save()

		context.clock:tick(1)

		expect(function()
			promise:expect()
		end).never.to.throw()
	end)
end
