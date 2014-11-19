-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : IIOP Profile Encoder/Decoder
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local error = _G.error
local ipairs = _G.ipairs
local pcall = _G.pcall
local tonumber = _G.tonumber

local math = require "math"
local min = math.min

local oo = require "oil.oo"
local class = oo.class

local idl = require "oil.corba.idl"
local Version = idl.Version

local Exception = require "oil.corba.giop.Exception"                            --[[VERBOSE]] local verbose = require "oil.verbose"


local Tag = 0
local Empty = {}


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


local IIOPProfiler = class{ minor = 2 }

local VersionData = {major=1, minor=nil}
local function encodeIIOPProfile(self, profile, minor)
	if not minor then minor = self.minor end
	local profileidl = ProfileBody_v1_[minor]
	if profileidl == nil then
		error(Exception{
			"$protocol version $versionmajor.$versionminor is not supported",
			error = "badversion",
			protocol = "IIOP",
			versionmajor = 1,
			versionminor = minor,
			minor = 0,
		})
	end
	local encoder = self.codec:encoder(true)
	VersionData.minor = minor
	encoder:struct(VersionData, Version)
	encoder:struct(profile, profileidl)
	return encoder:getdata()
end
function IIOPProfiler:encode(profiles, object_key, config, minor)               --[[VERBOSE]] verbose:references(true, "encoding IIOP profile")
	for _, addr in ipairs(config.addresses) do
		local profile = {
			components = Empty,
			host = addr.host,
			port = addr.port,
			object_key = object_key
		}
		local ok, encoded = pcall(encodeIIOPProfile, self, profile, minor)
		if not ok then                                                              --[[VERBOSE]] verbose:references(false, "error in encoding of IIOP profile")
			return nil, encoded
		end
		profiles[#profiles+1] = { tag=Tag, profile_data=encoded }
	end                                                                           --[[VERBOSE]] verbose:references(false)
	return true
end

local function decodeIIOPProfile(self, profile)
	local decoder = self.codec:decoder(profile, true)
	local version = decoder:struct(Version)
	if version.major ~= 1 then
		error(Exception{
			"$protocol version not supported (got $versionmajor.$versionminor)",
			error = "badversion",
			protocol = "IIOP",
			versionmajor = version.major,
			versionminor = version.minor,
			minor = 0,
		})
	end
	local minor = min(3, version.minor)
	local profileidl = ProfileBody_v1_[minor]
	profile = decoder:struct(profileidl)
	profile.iiop_version = version -- add read version directly
	profile.giop_minor = minor
	return profile
end
function IIOPProfiler:decode(profile)                                           --[[VERBOSE]] verbose:references(true, "decoding IIOP profile")
	local ok, profile = pcall(decodeIIOPProfile, self, profile)
	if not ok then                                                                --[[VERBOSE]] verbose:references(false, "error in decoding IIOP profile")
		return nil, profile
	end                                                                           --[[VERBOSE]] verbose:references(false)
	return profile
end

function IIOPProfiler:decodeurl(data)
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
			"$protocol $major.$minor not supported",
			error = "badversion",
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

function IIOPProfiler:belongsto(profile, accessinfo)
	local ports = accessinfo.addresses[profile.host]
	if ports ~= nil and ports[profile.port] ~= nil then
		return profile.object_key
	end
end

function IIOPProfiler:equivalent(profile1, profile2)
	return profile1.host == profile2.host and
	       profile1.port == profile2.port and
	       profile1.object_key == profile2.object_key
end



local BI_DIR_IIOP = 5
local ListenPoint = idl.struct{
	{name = "host", type = idl.string},
	{name = "port", type = idl.ushort},
}
local ListenPointList = idl.sequence{ListenPoint}
local BiDirIIOPServiceContext = idl.struct{
	{name = "listen_points", type = ListenPointList},
}

function IIOPProfiler:encodebidir(service_context, address)
	local encoder = self.codec:encoder(true)
	local port = address.port
	local listen_points = {}
	for index, address in ipairs(address.addresses) do
		listen_points[index] = {host=address.host,port=address.port}
	end
	encoder:put({listen_points=listen_points}, BiDirIIOPServiceContext)
	service_context[#service_context+1] = {
		context_id = BI_DIR_IIOP,
		context_data = encoder:getdata(),
	}
end

function IIOPProfiler:decodebidir(service_context)
	local result
	for _, context in ipairs(service_context) do
		if context.context_id == BI_DIR_IIOP then
			local decoder = self.codec:decoder(context.context_data, true)
			context = decoder:get(BiDirIIOPServiceContext)
			if result == nil then
				result = context.listen_points
			else
				for _, listen_point in ipairs(context.listen_points) do
					result[#result+1] = listen_point
				end
			end
		end
	end
	return result
end

return IIOPProfiler
