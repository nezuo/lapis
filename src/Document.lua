local Data = require(script.Parent.Data)
local Error = require(script.Parent.Error)
local Promise = require(script.Parent.Parent.Promise)

local Document = {}
Document.__index = Document

function Document.new(collection, name, data, lockId)
	return setmetatable({
		_data = data,
		_open = true,
		_lockId = lockId,
		collection = collection,
		name = name,
	}, Document)
end

function Document:_isLockInconsistent(value)
	return value.lockId ~= self._lockId
end

function Document:close()
	assert(self._open, "Cannot close a closed document")

	self._open = false

	return Promise.try(Data.update, self.collection, self.name, function(value)
		if self:_isLockInconsistent(value) then
			return nil
		end

		value.updatedAt = os.time()
		value.lockId = nil
		value.data = self._data.data

		return value
	end):finally(function()
		self.collection:_removeDocument(self.name)
	end)
end

function Document:read()
	return self._data.data
end

function Document:save()
	assert(self._open, "Cannot save a closed document")

	return Promise.new(function(resolve, reject)
		self._data = Data.update(self.collection, self.name, function(value)
			if self:_isLockInconsistent(value) then
				reject(Error.new(Error.Kind.InconsistentLock, "The lock was changed after it was acquired"))
				return nil
			end

			value.updatedAt = os.time()
			value.data = self._data.data

			return value
		end)

		resolve()
	end)
end

function Document:write(data)
	assert(self._open, "Cannot write to a closed document")

	if self._data.data == data then
		error("Cannot write to a document mutably")
	end

	assert(self.collection.validate(data))

	self._data.data = data
end

return Document
