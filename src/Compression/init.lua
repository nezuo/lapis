local None = require(script.Schemes.None)

local SCHEMES = {
	None = None,
}

local Compression = {}

function Compression.compress(data)
	local scheme = SCHEMES.None

	return "None", scheme.compress(data)
end

function Compression.decompress(compressionScheme, data)
	local scheme = SCHEMES[compressionScheme]

	if scheme == nil then
		error("Unknown compression scheme")
	end

	return scheme.decompress(data)
end

return Compression
