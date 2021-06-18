return function()
	local Clock = require(script.Parent.Parent.Clock)
	local Collection = require(script.Parent.Collection)
	local Error = require(script.Parent.Error)
	local Managers = require(script.Parent.Parent.DataStoreServiceMock.Managers)

	local document
	local collection
	beforeEach(function()
		collection = Collection.new("collection", {
			validate = function(data)
				return typeof(data.foo) == "string", "foo must be a string"
			end,
			defaultData = { foo = "bar" },
		})

		document = collection:openDocument("document"):expect()
		Clock.progress(6)
	end)

	describe("read", function()
		it("should return the data", function()
			expect(document:read().foo).to.equal("bar")
		end)
	end)

	describe("write", function()
		it("should write the data", function()
			document:write({
				foo = "baz",
			})

			expect(document:read().foo).to.equal("baz")
		end)

		it("should throw when writing to a closed document", function()
			local promise = document:close()

			expect(function()
				document:write({
					foo = "qux",
				})
			end).to.throw("Cannot write to a closed document")

			promise:expect()
		end)

		it("should throw when setting the same value", function()
			local value = document:read()

			expect(function()
				document:write(value)
			end).to.throw("Cannot write to a document mutably")
		end)

		it("should throw when writing a value that does not match validate", function()
			expect(function()
				document:write({
					foo = 5,
				})
			end).to.throw("foo must be a string")
		end)
	end)

	describe("close", function()
		it("should remove the lock", function()
			document:close():expect()

			Clock.progress(6)

			expect(function()
				collection:openDocument("document"):expect()
			end).never.to.throw()
		end)

		it("should remove the document from the collection", function()
			document:close():expect()

			Clock.progress(6)

			local nextDocument = collection:openDocument("document"):expect()

			expect(document).never.to.equal(nextDocument)
		end)

		it("should throw when closing a closed document", function()
			local promise = document:close()

			expect(function()
				document:close()
			end).to.throw("Cannot close a closed document")

			promise:expect()
		end)

		it("should save the data", function(context)
			document:write({
				foo = "hello",
			})

			document:close():expect()

			expect(context.read(collection, document).data.foo).to.equal("hello")
		end)

		it("should not save the data when lock is inconsistent", function(context)
			Managers.Data.Global.set("collection", "global", "document", context.makeData({ data = document:read() }))

			document:write({
				foo = "updated",
			})

			document:close():expect()

			expect(context.read(collection, document).data.foo).never.to.equal("updated")
		end)
	end)

	describe("save", function()
		it("should throw when saving a closed document", function()
			local promise = document:close()

			expect(function()
				document:save()
			end).to.throw("Cannot save a closed document")

			promise:expect()
		end)

		it("should save the data", function(context)
			document:write({
				foo = "hello",
			})

			document:save():expect()

			expect(context.read(collection, document).data.foo).to.equal("hello")
		end)

		it("should not save the data when lock is inconsistent", function(context)
			Managers.Data.Global.set("collection", "global", "document", context.makeData({ data = document:read() }))

			document:write({
				foo = "updated",
			})

			document:save():await()

			expect(context.read(collection, document).data.foo).never.to.equal("hello")
		end)

		it("should throw when lock is inconsistent", function(context)
			Managers.Data.Global.set("collection", "global", "document", context.makeData({ data = document:read() }))

			local ok, err = document:save():await()

			expect(ok).to.equal(false)
			expect(err.kind).to.equal(Error.Kind.InconsistentLock)
		end)

		it("should throw when data stores are erroring", function()
			Managers.Errors.setErrorChance(1)

			local ok, err = document:save():await()

			expect(ok).to.equal(false)
			expect(err.kind).to.equal(Error.Kind.DataStoreFailure)
		end)

		it("should retry", function()
			Managers.Errors.setErrorCounter(1)

			expect(function()
				document:save():expect()
			end).never.to.throw()
		end)

		describe("when the budget is exhausted", function()
			beforeEach(function()
				Managers.Budget.setBudget(Enum.DataStoreRequestType.UpdateAsync, 0)
				Managers.Budget.setThrottleQueueSize(0)
			end)

			it("should not throw", function()
				expect(function()
					document:save():expect()
				end).never.to.throw()
			end)

			it("should should update the data", function(context)
				document:write({
					foo = "newValue",
				})

				document:save():expect()

				expect(context.read(collection, document).data.foo).to.equal("newValue")
			end)
		end)

		describe("when the document is on write cooldown", function()
			beforeEach(function()
				Managers.Budget.setThrottleQueueSize(0)
				document:save()
			end)

			it("should not throw", function()
				local promise = document:save()

				Clock.progress(6)

				expect(function()
					promise:expect()
				end).never.to.throw()
			end)

			it("should not throw on multiple requests", function()
				local first = document:save()
				local second = document:save()

				Clock.progress(12)

				expect(function()
					first:expect()
					second:expect()
				end).never.to.throw()
			end)

			it("should not throw when the budget is exhausted", function()
				Managers.Budget.setBudget(Enum.DataStoreRequestType.UpdateAsync, 0)

				local promise = document:save()

				Clock.progress(6)

				expect(function()
					promise:expect()
				end).never.to.throw()
			end)

			it("should should update the data when the budget is exhausted", function(context)
				Managers.Budget.setBudget(Enum.DataStoreRequestType.UpdateAsync, 0)

				document:write({
					foo = "newValue",
				})

				local promise = document:save()

				Clock.progress(6)

				promise:expect()

				expect(context.read(collection, document).data.foo).to.equal("newValue")
			end)
		end)
	end)
end
