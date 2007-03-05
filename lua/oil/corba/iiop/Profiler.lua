-- $Id$
--******************************************************************************
-- Copyright 2002 Noemi Rodriquez & Roberto Ierusalimschy. All rights reserved. 
--******************************************************************************

--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua: An Object Request Broker in Lua                 --
-- Release: 0.3 alpha                                                         --
-- Title  : Interoperable Object Reference (IOR) support                      --
-- Authors: Noemi Rodriquez       <noemi@inf.puc-rio.br>                      --
--          Roberto Ierusalimschy <roberto@inf.puc-rio.br>                    --
--          Renato Cerqueira      <rcerq@inf.puc-rio.br>                      --
--          Pedro Miller          <miller@inf.puc-rio.br>                     --
--          Reinaldo Mello        <rmello@inf.puc-rio.br>                     --
--          Luiz Nogara           <nogara@inf.puc-rio.br>                     --
--          Renato Maia           <maia@inf.puc-rio.br>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   URLProtocols     List of protocols used to decode URL object references  --
--   encode(ior)      Encodes IOR to textual representation                   --
--   decode(string)   Decodes IOR from textual representation                 --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   See section 13.6 of CORBA 3.0 specification.                             --
--   See section 13.6.10 of CORBA 3.0 specification for corbaloc.             --
--------------------------------------------------------------------------------

local require  = require
local tonumber = tonumber
local print = print
local ipairs = ipairs
local pairs = pairs

local string   = require "string"
local oo       = require "oil.oo"

module ("oil.corba.reference", oo.class)                                        --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local assert  = require "oil.assert"
local IDL     = require "oil.idl"

--------------------------------------------------------------------------------
-- String/byte conversions -----------------------------------------------------

local function byte2hexa(value)
	return (string.gsub(value, '(.)', function (char)
		-- TODO:[maia] check char to byte conversion
		return (string.format("%02x", string.byte(char)))
	end))
end

local function hexa2byte(value)
	local error
	value = (string.gsub(value, '(%x%x)', function (hexa)
		hexa = tonumber(hexa, 16)
		if hexa
			-- TODO:[maia] check byte to char conversion
			then return string.char(hexa)
			else error = true
		end
	end))
	if not error then return value end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local Decoder = {}

function Decoder.IOR(reference, stream)                                         --[[VERBOSE]] verbose:ior(true, "using stringified IOR format")
	local buffer = reference.codec:newDecoder(hexa2byte(stream), true)
	local iortbl = buffer:IOR()
	return iortbl                                                                 --[[VERBOSE]] , verbose:ior(false)
end

function Decoder.corbaloc(reference, encoded)                                   --[[VERBOSE]] verbose:ior "using corbaloc IOR format"
	for token, data in string.gmatch(encoded, "(%w*):([^,]*)") do                 --[[VERBOSE]] verbose:ior("attempt to decode corbaloc with protocol '", token, "'")
		if reference.profile_resolver then                                               --[[VERBOSE]] verbose:ior(true, "using protocol '", token, "' to decode corbaloc")
			return {
				_type_id = "IDL:omg.org/CORBA/Object:1.0",
				-- TODO:[nogara] check this
				_profiles = { reference.profile_resolver:decodeurl(data) },
			}                                                                         --[[VERBOSE]] , verbose:ior(false)
		end
	end
	assert.illegal(encoded, "corbaloc, no supported protocol found", "INV_OBJREF")
end

--------------------------------------------------------------------------------
-- Coding ----------------------------------------------------------------------

function resolve(self, ...)                                                  --[[VERBOSE]] verbose:ior(true, "decode IOR")
	assert.type(arg[1], "string", "encoded IOR", "INV_OBJREF")
	local token, stream = string.match(arg[1], "^(%w+):(.+)$")                   --[[VERBOSE]] verbose:ior("got ", token, " IOR format")
	local decoder = Decoder[token]
	if not decoder then
		assert.illegal(token, "IOR format, currently not supported", "INV_OBJREF")
	end
	local decodedRef = decoder(self, stream)                                                        --[[VERBOSE]] , verbose:ior(false)
	local profile = decode_profile(self, decodedRef)
	profile._type_id = decodedRef._type_id
	return profile
end

function referto(self, ...)                                                            --[[VERBOSE]] verbose:ior(true, "encode IOR")
	local buffer = self.codec:newEncoder(true)
	-- create profile structure using the arguments provided by the serverbroker
	local servant = arg[1]
	local info = arg[2]
	local profile = self:encode_profile(info.host, info.port, servant._objectid)
	servant._profiles = {profile}
	buffer:IOR(servant) -- marshall IOR
	return "IOR:"..byte2hexa(buffer:getdata())                                    --[[VERBOSE]] , verbose:ior(false)
end

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

function decode_profile(self, decodedRef)
	for _, profile in ipairs(decodedRef._profiles) do                                         --[[VERBOSE]] verbose:resolver("got profile with tag ", profile.tag)
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



