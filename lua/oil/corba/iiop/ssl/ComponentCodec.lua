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

local bit32 = require "bit32"
local band = bit32.band

local oo = require "oil.oo"
local class = oo.class

local idl = require "oil.corba.idl"
local Version = idl.Version

local Exception = require "oil.corba.giop.Exception"                            --[[VERBOSE]] local verbose = require "oil.verbose"


local Tag = 20 -- TAG_SSL_SEC_TRANS
local Empty = {}

local NoProtection = 1
local Integrity = 2
local Confidentiality = 4
local DetectReplay = 8
local DetectMisordering = 16
local EstablishTrustInTarget = 32
local EstablishTrustInClient = 64
local NoDelegation = 128
local SimpleDelegation = 256
local CompositeDelegation = 512
local BasicOptions = Integrity
                   + Confidentiality
                   + DetectReplay
                   + DetectMisordering 
                   + NoDelegation

local ComponentBody = idl.struct{
	{name = "target_supports", type = idl.ushort},
	{name = "target_requires", type = idl.ushort},
	{name = "port", type = idl.ushort},
}


local SSLIOPComponent = class{ tag = Tag }

local function encodeSSLIOPComponent(self, component)
	local encoder = self.codec:encoder(true)
	encoder:struct(component, ComponentBody)
	return encoder:getdata()
end
function SSLIOPComponent:encode(components, entry, config, address)
	local sslcfg = config.sslcfg
	if sslcfg ~= nil then                                                         --[[VERBOSE]] verbose:references(true, "encoding SSLIOP component of IIOP profile")
		local supported, required = BasicOptions, 0
		if sslcfg.cafile ~= nil then
			supported = supported + EstablishTrustInClient
		end
		if entry.__security then
			required = supported
		else
			required = required + NoProtection
			supported = supported + NoProtection
		end
		if sslcfg.certificate ~= nil then
			supported = supported + EstablishTrustInTarget
		end
		local ok, encoded = pcall(encodeSSLIOPComponent, self, {
			target_supports = supported,
			target_requires = required,
			port = address.sslport or config.sslport,
		})
		if not ok then                                                              --[[VERBOSE]] verbose:references(false, "error in encoding of SSLIOP component of IIOP profile")
			return nil, encoded
		end
		components[#components+1] = { tag=Tag, component_data=encoded }             --[[VERBOSE]] verbose:references(false)
	end
	return true
end

local function decodeSSLIOPComponent(self, component)
	local decoder = self.codec:decoder(component, true)
	return decoder:struct(ComponentBody)
end
function SSLIOPComponent:decode(data, profile)                                  --[[VERBOSE]] verbose:references(true, "decoding SSLIOP component of IIOP profile")
	local ok, component = pcall(decodeSSLIOPComponent, self, data)
	if not ok then                                                                --[[VERBOSE]] verbose:references(false, "error in decoding SSLIOP component of IIOP profile")
		return nil, component
	end                                                                           --[[VERBOSE]] verbose:references(false)
	local supported = component.target_supports
	local required = component.target_requires
	component.required = band(supported, NoProtection) == 0
	component.targettrust = band(supported, EstablishTrustInTarget) ~= 0
	component.clienttrust = band(required, EstablishTrustInClient) ~= 0
	profile.ssl = component
	return component
end

return SSLIOPComponent
