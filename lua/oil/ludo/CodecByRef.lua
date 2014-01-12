-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Client-side CORBA GIOP Protocol specific to IIOP
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local getmetatable = _G.getmetatable
local rawget = _G.rawget

local StringStream = require "loop.serial.StringStream"
local serialascopy = StringStream.table

local oo = require "oil.oo"
local class = oo.class

local Codec = require "oil.ludo.Codec"


local function resolveref(self, reference)
	local servants = self.servants
	if servants ~= nil and self.localrefs == "implementation" then
		local entry = servants:localref(reference)
		if entry ~= nil then                                                        --[[VERBOSE]] verbose:unmarshal("local object with key '",entry.__objkey,"' restored")
			return entry.__servant
		end
	end
	return self.proxies:newproxy{__reference=reference}
end

local function serialasproxy(self, value)                                       --[[VERBOSE]] verbose:marshal("marshalling proxy for value ",value)
	local reference = self.context.servants:register{__servant=value}.__reference
	local reflabel = serialascopy(self, reference)
	local label = self:newlabel()
	self:write(self.varprefix,label," = context.proxies:newproxy{__reference=",reflabel,"}")
	self[value] = label
	return label
end

local function serialtable(self, value)                                         --[[VERBOSE]] verbose:marshal(true, "marshalling of table ",value)
	local reference = rawget(value, "__reference")
	if reference then                                                             --[[VERBOSE]] verbose:marshal "table is a proxy"
		local reflabel = serialascopy(self, reference)
		local label = self:newlabel()
		self:write(self.varprefix,label," = resolveref(context, ",reflabel,")")
		self[value] = label
		return label
	else
		local meta = getmetatable(value)
		if meta and meta.__marshalcopy then                                         --[[VERBOSE]] verbose:marshal "table by copy"
			return serialascopy(self, value)
		else                                                                        --[[VERBOSE]] verbose:marshal "table by reference"
			return serialasproxy(self, value)
		end                                                                         --[[VERBOSE]] verbose:marshal(false)
	end
end


local CodecByRef = class({ localrefs = "implementation" }, Codec)

function CodecByRef:localresources(...)
	Codec.localresources(self, ...)
	self.encoderprototype.table = serialtable
	self.encoderprototype.thread = serialasproxy
	self.encoderprototype.userdata = serialasproxy
	self.encoderprototype["function"] = serialasproxy
	self.encoderprototype.context = self
	self.decoderprototype.resolveref = resolveref
	self.decoderprototype.context = self
end

return CodecByRef
