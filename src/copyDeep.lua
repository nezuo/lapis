local function copyDeep(valueToCopy)
	if typeof(valueToCopy) ~= "table" then
		return valueToCopy
	end

	local clone = {}

	for key, value in pairs(valueToCopy) do
		clone[key] = copyDeep(value)
	end

	return clone
end

return copyDeep
