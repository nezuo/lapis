local RunService = game:GetService("RunService")

local types = require(script.Parent.types)

local UPDATE_INTERVAL = 5 * 60

local AutoSave = {}
AutoSave.__index = AutoSave

function AutoSave.new<T>(data: types.Data<T>): types.Autosave<T>
	return (setmetatable({
		documents = {},
		data = data,
	}, AutoSave) :: any) :: types.Autosave<T>
end

function AutoSave:addDocument(document)
	table.insert(self.documents, document)
end

function AutoSave:removeDocument(document)
	local index = table.find(self.documents, document)

	table.remove(self.documents, index)
end

function AutoSave:onGameClose()
	while #self.documents > 0 do
		self.documents[#self.documents]:close()
	end

	self.data:waitForOngoingSaves():await()
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
		self:onGameClose()
	end)
end

return AutoSave
