-- Project: OiL - ORB in Lua
-- Release: 0.5
-- Title  : IIOP Profile Encoder/Decoder
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local ipairs = _G.ipairs
local tonumber = _G.tonumber

local oo = require "oil.oo"
local class = oo.class

local idl = require "oil.corba.idl"
local Version = idl.Version

local Exception = require "oil.corba.giop.Exception"                            --[[VERBOSE]] local verbose = require "oil.verbose"

module(..., class)

--------------------------------------------------------------------------------
-- IIOP profile structure

local Empty = {}

local Tag = 0

local TaggedComponentSeq = idl.sequence{idl.struct{
	{name = "tag"           , type = idl.ulong   },
	{name = "component_data", type = idl.OctetSeq},
}}

local ProfileBody_v1_ = {
	-- Note: First profile structure field is read/write directly
	[0] = idl.struct{
		--{name = "iiop_version", type = idl.Version },
		{name = "host"        , type = idl.string  },
		{name = "port"        , type = idl.ushort  },
		{name = "object_key"  , type = idl.OctetSeq},
	},
	[1] = idl.struct{
		--{name = "iiop_version", type = idl.Version       },
		{name = "host"        , type = idl.string        },
		{name = "port"        , type = idl.ushort        },
		{name = "object_key"  , type = idl.OctetSeq      },
		{name = "components"  , type = TaggedComponentSeq},
	},
}
ProfileBody_v1_[2] = ProfileBody_v1_[1] -- same as IIOP 1.1
ProfileBody_v1_[3] = ProfileBody_v1_[1] -- same as IIOP 1.1

--------------------------------------------------------------------------------
-- IIOP profile encode/decode

function encode(self, profiles, object_key, config, minor)
	if not minor then minor = 0 end
	local profileidl = ProfileBody_v1_[minor]
	if profileidl then
		local port = config.refport or config.port
		for _, addr in ipairs(config.addresses) do
			local profile = {
				components = Empty,
				host = addr,
				port = port,
				object_key = object_key
			}
			local encoder = self.codec:encoder(true)
			encoder:struct({major=1, minor=minor}, Version)
			encoder:struct(profile, profileidl)
			profiles[#profiles+1] = {
				tag          = Tag,
				profile_data = encoder:getdata(),
			}
		end
		return true
	else
		return nil, Exception{ "INTERNAL", minor = 0,
			error = "badversion",
			message = "$protocol minor version $version not supported",
			protocol = "IIOP",
			version = minor,
		}
	end
end

function decode(self, profile)
	local decoder = self.codec:decoder(profile, true)
	local version = decoder:struct(Version)
	local profileidl = ProfileBody_v1_[version.minor]

	if version.major ~= 1 or not profileidl then
		return nil, Exception{ "INTERNAL", minor = 0,
			error = "badversion",
			message = "$protocol version not supported (got $major.$minor)",
			protocol = "IIOP",
			major = version.major,
			minor = version.minor,
		}
	end

	profile = decoder:struct(profileidl)
	profile.iiop_version = version -- add read version directly

	return profile, profile.object_key
end

--------------------------------------------------------------------------------
-- IIOP profile and local ORB config match

function belongsto(self, profile, config)
	local objectkey
	profile, objectkey = self:decode(profile)
	if config.addresses[profile.host] and profile.port == config.port then
		return objectkey
	end
end

--------------------------------------------------------------------------------
-- IIOP profile are equivalent

function equivalent(self, profile1, profile2)
	local objectkey1, objectkey2
	profile1, objectkey1 = self:decode(profile1)
	profile2, objectkey2 = self:decode(profile2)
	return objectkey1 == objectkey2 and
	       profile1.host == profile2.host and
	       profile1.port == profile2.port
end

--------------------------------------------------------------------------------
-- IIOP corbaloc URL decoder

function decodeurl(self, data)
	local temp, objectkey = data:match("^([^/]*)/(.*)$")
	if temp
		then data = temp
		else objectkey = "" -- TODO:[maia] is this correct?
	end
	local major, minor
	major, minor, temp = data:match("^(%d+).(%d+)@(.+)$")
	if not minor then
		minor = 0
	else
		minor = tonumber(minor)
	end
	local profileidl = ProfileBody_v1_[minor]
	if (major and major ~= "1") or (not profileidl) then
		return nil, Exception{ "INTERNAL", minor = 0,
			error = "badversion",
			message = "$protocol $major.$minor not supported",
			protocol = "IIOP",
			major = major,
			minor = minor,
		}
	end
	if temp then data = temp end
	local host, port = data:match("^([^:]+):(%d*)$")
	if port then
		port = tonumber(port)
	else
		port = 2809
		if data == ""
			then host = "*"
			else host = data
		end
	end
	
	temp = self.codec:encoder(true)
	temp:struct({major=1,minor=minor}, Version)
	temp:struct({
		components = Empty,
		host = host,
		port = port,
		object_key = objectkey
	}, profileidl)
	return {
		tag = Tag,
		profile_data = temp:getdata(),
	}
end
