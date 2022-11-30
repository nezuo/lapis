local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Clock)
local Data = require(script.Parent.Data)
local DataStoreServiceMock = require(ReplicatedStorage.ServerPackages.DataStoreServiceMock)
local Lapis = require(script.Parent)
local Tasks = require(ReplicatedStorage.Tasks)

local SUPER_SPEED = true

local Constants = DataStoreServiceMock.Constants
local Managers = DataStoreServiceMock.Managers

if SUPER_SPEED then
	Constants.IS_UNIT_TEST_MODE = true
	print("Running tests at SUPER SPEED.")
else
	Constants.IS_UNIT_TEST_MODE = false
	print("Running tests at NORMAL SPEED.")
end

Clock.start(SUPER_SPEED)

Lapis.setGlobalConfig({
	showRetryWarnings = false,
	dataStoreService = DataStoreServiceMock,
})

return function()
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

			expect(function()
				Lapis.createCollection("duplicate")
			end).to.throw("Collection `duplicate` already exists")
		end)
	end)
end
