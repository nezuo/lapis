local RunService = game:GetService("RunService")

local Promise = require(script.Parent.Parent.Promise)

local UPDATE_INTERVAL = 5 * 60

local AutoSave = {}
AutoSave.__index = AutoSave

function AutoSave.new(data)
	return setmetatable({
		documents = {},
		data = data,
	}, AutoSave)
end

function AutoSave:addDocument(document)
	table.insert(self.documents, document)
end

function AutoSave:removeDocument(document)
	local index = table.find(self.documents, document)

	table.remove(self.documents, index)
end

function AutoSave:start()
	local nextUpdateAt = os.clock() + UPDATE_INTERVAL
	RunService.Heartbeat:Connect(function()
		if os.clock() >= nextUpdateAt then
			for _, document in self.documents do
				document:save():catch(warn)
			end

			nextUpdateAt += UPDATE_INTERVAL
		end
	end)

	game:BindToClose(function()
		while #self.documents > 0 do
			self.documents[#self.documents]:close()
		end

		local promises = {}

		-- This will wait for documents that closed before BindToClose was called.
		for _, pendingSaves in self.data:getPendingSaves() do
			for _, pendingSave in pendingSaves do
				table.insert(promises, pendingSave.promise)
			end
		end

		Promise.allSettled(promises):await()
	end)
end

return AutoSave
