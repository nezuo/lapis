local SUPER_SPEED = true

return function()
	local HttpService = game:GetService("HttpService")

	local Constants = require(script.Parent.Parent.DataStoreServiceMock.Constants)

	if SUPER_SPEED then
		Constants.IS_UNIT_TEST_MODE = true
		print("Running tests at SUPER SPEED.")
	else
		Constants.IS_UNIT_TEST_MODE = false
		print("Running tests at NORMAL SPEED.")
	end

	local DataStoreServiceMock = require(script.Parent.Parent.DataStoreServiceMock)
	local getDataStoreService = require(script.Parent.getDataStoreService)
	getDataStoreService.getDataStoreService = function()
		return DataStoreServiceMock
	end

	local Clock = require(script.Parent.Parent.Clock)
	local Tasks = require(script.Parent.Parent.Tasks)
	local Managers = require(script.Parent.Parent.DataStoreServiceMock.Managers)
	local Data = require(script.Parent.Data)

	Clock.start(SUPER_SPEED)

	beforeAll(function(context)
		context.makeData = function(options)
			options = options or {}

			return {
				schemeKind = "Raw",
				schemeVersion = 1,
				data = HttpService:JSONEncode({
					migrationVersion = 0,
					data = {
						createdAt = os.time(),
						updatedAt = os.time(),
						lockId = options.lockId,
						data = options.data,
					},
				}),
			}
		end

		context.read = function(collection, document)
			return Data.unpack(
				Managers.Data.Global.get(collection.name, "global")[document.name],
				collection.migrations
			)
		end
	end)

	beforeEach(function()
		Tasks.unlock()
	end)

	afterEach(function()
		Tasks.lock()
		Tasks.resumeAll()
		Clock.reset()
		Managers.DataStores.reset()
		Managers.Errors.setErrorChance(0)
		Managers.Errors.setErrorCounter(0)
		Managers.Budget.resetThrottleQueueSize()
		Managers.Budget.reset()
	end)

	local Lapis = require(script.Parent)

	describe("createCollection", function()
		it("should return a collection", function()
			local collection = Lapis.createCollection("collection", {
				validate = function()
					return true
				end,
			})

			expect(collection).to.be.ok()
			expect(collection.name).to.equal("collection")
		end)

		it("should throw when creating a duplicate collection", function()
			Lapis.createCollection("duplicate", {
				validate = function()
					return true
				end,
			})

			local ok, err = pcall(Lapis.createCollection, "duplicate")

			expect(ok).to.equal(false)
			expect(err.kind).to.equal(Lapis.Error.Kind.CollectionAlreadyExists)
		end)
	end)
end
