local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)

local startedAt = os.clock()

TestEZ.TestBootstrap:run({ ReplicatedStorage.Packages.Lapis })

print(string.format("Tests finished running in %.3f seconds", os.clock() - startedAt))
