local require       = require
local ipairs        = ipairs 
local tostring      = tostring
local print         = print
local oo            = require "oil.oo"

module ("oil.ReferenceHandler", oo.class )                                              --[[VERBOSE]] local verbose = require "oil.verbose"

local assert          = require "oil.assert"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local components = Empty
function decodeurl(data)
	local temp, objectkey = string.match(data, "^([^/]*)/(.*)$")
	if temp
		then data = temp
		else objectkey = "" -- TODO:[maia] is this correct?
	end
	local major, minor
	major, minor, temp = string.match(data, "^(%d+).(%d+)@(.+)$")
	if major and major ~= "1" then
		return nil, Exception{ "INTERNAL", minor_code_value = 0,
			message = "IIOP version not supported, got "..major.."."..minor,
			reason = "version",
			protocol = "IIOP",
			major = major,
			minor = minor,
		}
	end
	if temp then data = temp end
	local host, port = string.match(data, "^([^:]+):(%d*)$")
	if port then
		port = tonumber(port)
	else
		port = 2809
		if data == ""
			then host = "*"
			else host = data
		end
	end                                                                           --[[VERBOSE]] verbose:ior("got host ", host, ":", port, " and object key '", objectkey, "'")
	return createprofile(self, {
			host = host,
			port = port,
			object_key = objectkey,
			components = components,
		},
		tonumber(minor)
	)
end

function decode_profile(self, profile)
	local profile_type = profile._type or "corba"                                 --[[VERBOSE]] verbose:ior("decoding profile type ", profile_type)
	if self.profile_resolver[profile_type] then                                   
		return self.profile_resolver[profile_type]:decode_profile(profile)
	else 
		return nil, Exception{ "INTERNAL", minor_code_value = 0,
			message = "Profile resolver not found for type "..
								profile_type,
			reason = "version",
			protocol = "IIOP",
			major = version.major,
			minor = version.minor,
		}
	end
end

function encode_profile(self, ...)
	local prefs
	if arg then prefs = args[1] end 
	local profile_type 
	if prefs then 
		profile_type = prefs._type or "corba"
	end
	return self.profile_resolver[profile_type]:encode_profile(...)
end

function encode(self, ...)
	return self.reference_resolver["corba"]:encode(...)
end

function decode(self, ...)
	return self.reference_resolver["corba"]:decode(...)
end
