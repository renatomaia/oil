-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Client-side CORBA GIOP Protocol specific to IIOP
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local getmetatable = _G.getmetatable
local pairs = _G.pairs
local tonumber = _G.tonumber
local tostring = _G.tostring
local rawget = _G.rawget
local rawset = _G.rawset

local table = require "loop.table"
local copy = table.copy

local StringStream = require "loop.serial.StringStream"

local oo = require "oil.oo"
local class = oo.class

local Codec = require "oil.ludo.Codec"


-- TODO:[maia] copied from loop.serial.Serializer. Make it a member function
local function getidfor(value)
	local meta = getmetatable(value)
	local backup
	if meta then
		backup = rawget(meta, "__tostring")
		if backup ~= nil then rawset(meta, "__tostring", nil) end
	end
	local id = tostring(value):match("%l+: (%w+)")
	if meta then
		if backup ~= nil then rawset(meta, "__tostring", backup) end
	end
	return tonumber(id, 16) or id
end

local function resolveref(self, reference)
	local servants = self.servants
	if servants ~= nil and self.localrefs == "implementation" then
		local entry = servants:localref(reference)
		if entry ~= nil then                                                          --[[VERBOSE]] verbose:unmarshal("local object with key '",entry.__objkey,"' restored")
			return entry.__servant
		end
	end
	return self.proxies:newproxy{__reference=reference}
end

local function serialproxy(self, value, id)                                     --[[VERBOSE]] verbose:marshal("marshalling proxy for value ",value)
	self[value] = self.namespace..":value("..id..")"
	self:write(self.namespace,":value(",id,",'table',")
	self:write("proxies:newproxy{__reference=")
	local reference = self.servants:register{__servant=value}.__reference
	StringStream.table(self, reference, getidfor(reference))
	self:write("})")
end

local function serialtable(self, value, id)                                     --[[VERBOSE]] verbose:marshal(true, "marshalling of table ",value)
	local reference = rawget(value, "__reference")
	if reference then                                                             --[[VERBOSE]] verbose:marshal "table is a proxy"
		self[value] = self.namespace..":value("..id..")"
		self:write(self.namespace,":value(",id,",'table',")
		self:write("resolveref(serial.environment,")
		StringStream.table(self, reference, getidfor(reference))
		self:write("))")
	else
		local meta = getmetatable(value)
		if meta and meta.__marshalcopy then                                         --[[VERBOSE]] verbose:marshal "table by copy"
			StringStream.table(self, value, id)
		else                                                                        --[[VERBOSE]] verbose:marshal "table by reference"
			serialproxy(self, value, id)
		end                                                                         --[[VERBOSE]] verbose:marshal(false)
	end
end


local LuDOStream = class({
	table        = serialtable,
	thread       = serialproxy,
	userdata     = serialproxy,
	["function"] = serialproxy,
}, StringStream)


local CodecByRef = class({ localrefs = "implementation" }, Codec)

function CodecByRef:encoder()
	return LuDOStream(copy(self.names, {servants = self.servants}))
end

function CodecByRef:decoder(stream)
	return StringStream{
		environment = copy(self.values, {
			resolveref = resolveref,
			localrefs = self.localrefs,
			proxies = self.proxies,
			servants = self.servants,
		}),
		data = stream,
	}
end

return CodecByRef
