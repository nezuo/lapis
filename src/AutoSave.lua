local RunService = game:GetService("RunService")

local Data = require(script.Parent.Data)
local Promise = require(script.Parent.Parent.Promise)

local UPDATE_INTERVAL = 5 * 60

local documents = {}

local function start()
	local nextUpdateAt = os.clock() + UPDATE_INTERVAL
	RunService.Heartbeat:Connect(function()
		if os.clock() >= nextUpdateAt then
			for _, document in documents do
				document:save():catch(warn)
			end

			nextUpdateAt += UPDATE_INTERVAL
		end
	end)

	if RunService:IsStudio() then
		return
	end

	game:BindToClose(function()
		while #documents > 0 do
			documents[#documents]:close()
		end

		local promises = {}

		-- This will wait for documents that closed before BindToClose was called.
		for _, pendingSaves in Data.getPendingSaves() do
			for _, pendingSave in pendingSaves do
				table.insert(promises, pendingSave.promise)
			end
		end

		Promise.allSettled(promises):await()
	end)
end

local AutoSave = {}

function AutoSave.addDocument(document)
	table.insert(documents, document)
end

function AutoSave.removeDocument(document)
	local index = table.find(documents, document)

	table.remove(documents, index)
end

start()

return AutoSave
