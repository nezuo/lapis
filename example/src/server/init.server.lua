local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lapis = require(ReplicatedStorage.Packages.Lapis)
local t = require(ReplicatedStorage.Packages.t)

local collection = Lapis.createCollection("PlayerData", {
	defaultData = {
		level = 1,
		xp = 0,
		coins = 100,
	},
	validate = t.strictInterface({
		level = t.integer,
		xp = t.number,
		coins = t.integer,
	}),
})

local documents = {}

Players.PlayerAdded:Connect(function(player)
	local ok, document = collection:load(`Player{player.UserId}`):await()

	if ok then
		local old = document:read()

		print(`Player has {old.coins} coins`)

		document:write({
			level = old.level,
			xp = old.xp,
			coins = old.coins + 1,
		})

		documents[player] = document
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local document = documents[player]

	if document ~= nil then
		documents[player] = nil
		document:close():catch(warn)
	end
end)
