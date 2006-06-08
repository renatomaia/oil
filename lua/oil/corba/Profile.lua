
-- Interface:                                                                 --
--   Tag              Value of Internet IOP tag                               --
--   decodeurl(url)   Decodes an IIOP URL Object defined by corbaloc format   --
--   connect(profile) Creates a connection object to address in IIOP profile  --
--   listen(args)     Creates a listening port object                         --
--   getport(profile) Return the server port specified by the profile         --
--                                                                            --

local require       = require
local ipairs        = ipairs 
local tostring      = tostring
local print         = print
local tonumber = tonumber
local oo            = require "oil.oo"

module ("oil.corba.Profile", oo.class )                                              --[[VERBOSE]] local verbose = require "oil.verbose"

local string          = require "string"
local IDL             = require "oil.idl"
local assert          = require "oil.assert"

--------------------------------------------------------------------------------
-- IIOP IOR profile support ----------------------------------------------------

Tag = 0

local TaggedComponentSeq = IDL.sequence{IDL.struct{
	{name = "tag"           , type = IDL.ulong   },
	{name = "component_data", type = IDL.OctetSeq},
}}

local IIOPProfileBody_v1_ = {
	-- Note: First profile structure field is read/write directly
	[0] = IDL.struct{
		--{name = "iiop_version", type = IDL.Version },
		{name = "host"        , type = IDL.string  },
		{name = "port"        , type = IDL.ushort  },
		{name = "object_key"  , type = IDL.OctetSeq},
	},
	[1] = IDL.struct{
		--{name = "iiop_version", type = IDL.Version       },
		{name = "host"        , type = IDL.string        },
		{name = "port"        , type = IDL.ushort        },
		{name = "object_key"  , type = IDL.OctetSeq      },
		{name = "components"  , type = TaggedComponentSeq},
	},
}
IIOPProfileBody_v1_[2] = IIOPProfileBody_v1_[1] -- same as IIOP 1.1
IIOPProfileBody_v1_[3] = IIOPProfileBody_v1_[1] -- same as IIOP 1.1

local function openprofile(self, profile)                                             --[[VERBOSE]] verbose:connect(true, "open IIOP IOR profile")
	local buffer = self.codec:newDecoder(profile, true)
	local version = buffer:struct(IDL.Version)
	local profileidl = IIOPProfileBody_v1_[version.minor]

	if version.major ~= 1 or not profileidl then
		return nil, Exception{ "INTERNAL", minor_code_value = 0,
			message = "IIOP version not supported, got "..
								version.major.."."..version.minor,
			reason = "version",
			protocol = "IIOP",
			major = version.major,
			minor = version.minor,
		}
	end

	profile = buffer:struct(profileidl)
	profile.iiop_version = version -- add version read directly

	return profile                                                                --[[VERBOSE]] , verbose:connect(false)
end
-- TODISCUSS: what to do with profiles in this case? Answer: see comm.lua
local function createprofile(self, profile, minor)
	if not minor then minor = 0 end
	local profileidl = IIOPProfileBody_v1_[minor]

	if not profileidl then
		return nil, Exception{ "INTERNAL", minor_code_value = 0,
			message = "IIOP version not supported, got 1."..minor,
			reason = "version",
			protocol = "IIOP",
			major = 1,
			minor = minor,
		}
	end
																																								--[[VERBOSE]] verbose:ior(true, "create IIOP IOR profile with version 1.", minor)
	local buffer = self.codec:newEncoder(true)
	buffer:struct({major=1, minor=minor}, IDL.Version)
	buffer:struct(profile, profileidl)                                            --[[VERBOSE]] verbose:ior(false)
	return {
		tag = Tag,  -- TODO:[nogara] this tag=Tag=0 is only for iiop
		profile_data = buffer:getdata(),
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local components = Empty
function decodeurl(self, data)
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
			then host = "localhost"
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

function decode_profile(self, profiles)
		for _, profile in ipairs(profiles) do                                         --[[VERBOSE]] verbose:resolver("got profile with tag ", profile.tag)
		if profile.tag == Tag then
			local decoded = openprofile(self, profile.profile_data)
			return decoded
		end
	end
end

function encode_profile(self, ...)
-- args are (host, port, object_key)
	return createprofile(self, {
		host = arg[1],
		port = arg[2],
		object_key = arg[3],
	})
end
