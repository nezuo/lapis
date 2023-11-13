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

local function addCoin(document)
	local old = document:read()

	document:write({
		level = old.level,
		xp = old.xp,
		coins = old.coins + 1,
	})

	print(`Player has {old.coins} coins`)
end

Players.PlayerAdded:Connect(function(player)
	collection
		:load(`Player{player.UserId}`, { player.UserId })
		:andThen(function(document)
			if player.Parent == nil then
				document:close():catch(warn)
				return
			end

			documents[player] = document

			addCoin(document)
		end)
		:catch(function(message)
			warn(`Player {player.Name}'s data failed to load: {message}`)
		end)
end)

Players.PlayerRemoving:Connect(function(player)
	local document = documents[player]

	if document ~= nil then
		documents[player] = nil
		document:close():catch(warn)
	end
end)
