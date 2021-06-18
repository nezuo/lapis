local Error = {}
Error.__index = Error

Error.Kind = {
	CouldNotAcquireLock = "CouldNotAcquireLock",
	DataStoreFailure = "DataStoreFailure",
	InconsistentLock = "InconsistentLock",
	MigrationError = "MigrationError",
	UnknownScheme = "UnknownScheme",
}

function Error.new(kind, extra)
	local self = setmetatable({}, Error)

	self.kind = kind
	self.extra = extra

	return self
end

function Error:__tostring()
	if self.extra ~= nil then
		return string.format("Error(%s: %s)", self.kind, tostring(self.extra))
	else
		return string.format("Error(%s)", self.kind)
	end
end

return Error
