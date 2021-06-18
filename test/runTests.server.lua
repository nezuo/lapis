local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestEZ = require(ReplicatedStorage.Vendor.TestEZ)

local startedAt = os.clock()

TestEZ.TestBootstrap:run({
	ReplicatedStorage.Vendor.Lapis,
})

print(string.format("Tests finished running in %.3f seconds", os.clock() - startedAt))
