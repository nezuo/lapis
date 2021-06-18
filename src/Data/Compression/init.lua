local HttpService = game:GetService("HttpService")

local Raw = require(script.Schemes.Raw)
local Error = require(script.Parent.Parent.Error)

local SCHEMES = {
	Raw = Raw,
}

local Compression = {}

function Compression.pack(value)
	value = HttpService:JSONEncode(value)

	local schemeKind = "Raw"
	local scheme = SCHEMES[schemeKind]
	local schemeVersion = #scheme

	return {
		data = scheme[schemeVersion].compress(value),
		schemeKind = schemeKind,
		schemeVersion = schemeVersion,
	}
end

function Compression.unpack(value)
	local scheme = SCHEMES[value.schemeKind]
	local schemeVersion = value.schemeVersion

	if scheme == nil or scheme[schemeVersion] == nil then
		error(Error.new(Error.Kind.UnknownScheme, "Unknown compression scheme"))
	end

	return HttpService:JSONDecode(scheme[schemeVersion].decompress(value.data))
end

return Compression
