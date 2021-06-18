return function()
	local Clock = require(script.Parent.Parent.Clock)
	local Collection = require(script.Parent.Collection)
	local Error = require(script.Parent.Error)
	local Managers = require(script.Parent.Parent.DataStoreServiceMock.Managers)

	it("should return a collection", function()
		local collection = Collection.new("foo", {
			validate = function(value)
				return typeof(value) == "string", "validation error"
			end,
			defaultData = "string",
		})

		expect(collection).to.be.ok()
		expect(collection.name).to.equal("foo")
	end)

	it("should throw when given no options", function()
		expect(function()
			Collection.new("bar")
		end).to.throw("options")
	end)

	it("should throw when given no validate option", function()
		expect(function()
			Collection.new("baz", {})
		end).to.throw("options.validate")
	end)

	it("should throw when defaultData does not pass validate", function()
		expect(function()
			Collection.new("collection", {
				validate = function()
					return false, "validation error"
				end,
			})
		end).to.throw("validation error")
	end)

	describe("openDocument", function()
		local collection

		beforeEach(function()
			collection = Collection.new("collection", {
				validate = function()
					return true
				end,
			})
		end)

		it("should return a document", function()
			local document = collection:openDocument("document"):expect()

			expect(document).to.be.ok()
			expect(document.name).to.equal("document")
			expect(document.collection).to.equal(collection)
		end)

		it("should return the same document", function()
			local document = collection:openDocument("document"):expect()
			local otherDocument = collection:openDocument("document"):expect()

			expect(document).to.equal(otherDocument)
		end)

		it("should return a unique promise", function()
			local promise = collection:openDocument("document")
			local otherPromise = collection:openDocument("document")

			expect(promise).never.to.equal(otherPromise)

			promise:expect()
			otherPromise:expect()
		end)

		it("should throw when data stores are erroring", function()
			Managers.Errors.setErrorChance(1)

			local ok, err = collection:openDocument("document"):await()
			expect(ok).to.equal(false)
			expect(err.kind).to.equal(Error.Kind.DataStoreFailure)
		end)

		it("should resolve after rejection", function()
			Managers.Errors.setErrorChance(1)

			collection:openDocument("document"):await()

			Managers.Errors.setErrorChance(0)

			local promise = collection:openDocument("document")

			Clock.progress(6)

			expect(promise:expect()).to.be.ok()
		end)

		it("should still return the document after promise is canceled", function()
			collection:openDocument("qux"):cancel()

			local document = collection:openDocument("qux"):expect()

			expect(document).to.be.ok()
			expect(document.name).to.equal("qux")
			expect(document.collection).to.equal(collection)
		end)

		it("should throw when the document is locked", function(context)
			local data = context.makeData({ lockId = "lockId" })
			Managers.Data.Global.set("collection", "global", "locked", data)

			local ok, err = collection:openDocument("locked"):await()

			expect(ok).to.equal(false)
			expect(err.kind).to.equal(Error.Kind.CouldNotAcquireLock)
		end)

		it("should load existing data", function(context)
			local data = context.makeData({ data = "value" })
			Managers.Data.Global.set("collection", "global", "existing", data)

			local document = collection:openDocument("existing"):expect()

			expect(document:read()).to.equal("value")
		end)

		it("should load, write, close, lock, and load the same document", function()
			local document = collection:openDocument("document"):expect()

			document:write("value")

			local closePromise = document:close()

			Clock.progress(6)

			closePromise:expect()

			Clock.progress(6)

			local nextDocument = collection:openDocument("document"):expect()

			expect(document).never.to.equal(nextDocument)
			expect(document:read()).to.equal("value")
		end)

		it("should deep copy defaultData", function()
			local defaultData = { a = 5 }
			local newCollection = Collection.new("newCollection", {
				validate = function()
					return true
				end,
				defaultData = defaultData,
			})

			local document = newCollection:openDocument("test"):expect()

			expect(document:read().a).to.equal(5)
			defaultData.a = 6
			expect(document:read().a).to.equal(5)
		end)

		it("should load document with default data", function()
			local newCollection = Collection.new("newCollection", {
				validate = function()
					return true
				end,
				defaultData = "default",
			})

			local document = newCollection:openDocument("document"):expect()

			expect(document:read()).to.equal("default")
		end)

		it("should throw when existing data does not match validate", function(context)
			Managers.Data.Global.set("validateCollection", "global", "document", context.makeData({ data = { a = 6 } }))

			local newCollection = Collection.new("validateCollection", {
				validate = function(dataToValidate)
					return dataToValidate.a == 5, "a should equal 5"
				end,
				defaultData = { a = 5 },
			})

			local ok, err = newCollection:openDocument("document"):await()

			expect(ok).to.equal(false)
			expect(string.find(err.error, "a should equal 5"))
		end)
	end)

	it("should throw when migration does not return a table", function(context)
		Managers.Data.Global.set("migration", "global", "migration", context.makeData({ data = "data" }))

		local collection = Collection.new("migration", {
			validate = function()
				return true
			end,
			migrations = {
				function() end,
			},
		})

		local ok, err = collection:openDocument("migration"):await()

		expect(ok).to.equal(false)
		expect(string.find(err.extra, "must return a table"))
	end)

	it("should throw when migration does return a validate function", function(context)
		Managers.Data.Global.set("migration", "global", "migration", context.makeData({ data = "data" }))

		local collection = Collection.new("migration", {
			validate = function()
				return true
			end,
			migrations = {
				function()
					return {}
				end,
			},
		})

		local ok, err = collection:openDocument("migration"):await()

		expect(ok).to.equal(false)
		expect(string.find(err.extra, "validate function"))
	end)

	it("should throw when migration does not change value immutably", function(context)
		Managers.Data.Global.set("migration", "global", "migration", context.makeData({ data = "data" }))

		local collection = Collection.new("migration", {
			validate = function()
				return true
			end,
			migrations = {
				function(value)
					return {
						value = value,
						validate = function()
							return true
						end,
					}
				end,
			},
		})

		local ok, err = collection:openDocument("migration"):await()

		expect(ok).to.equal(false)
		expect(string.find(err.extra, "mutably"))
	end)

	it("should throw when validate does not pass", function(context)
		Managers.Data.Global.set("migration", "global", "migration", context.makeData({ data = "data" }))

		local collection = Collection.new("migration", {
			validate = function()
				return true
			end,
			migrations = {
				function(value)
					return {
						value = value,
						validate = function()
							return false, "does not match"
						end,
					}
				end,
			},
		})

		local ok, err = collection:openDocument("migration"):await()

		expect(ok).to.equal(false)
		expect(string.find(err.extra, "failed validation"))
	end)

	it("should migrate the data", function(context)
		Managers.Data.Global.set("migration", "global", "migration", context.makeData({ data = "data" }))

		local collection = Collection.new("migration", {
			validate = function(value)
				return value == "newData", "value does not equal newData"
			end,
			defaultData = "newData",
			migrations = {
				function()
					return {
						value = "newData",
						validate = function(oldValue)
							return oldValue == "data", "oldValue does not equal data"
						end,
					}
				end,
			},
		})

		expect(function()
			collection:openDocument("migration"):expect()
		end).never.to.throw()
	end)
end
