-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Client-side LuDO Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local ipairs = _G.ipairs
local pairs = _G.pairs

local package = require "package"
local loaded = package.loaded

local proto = require "loop.proto"
local clone = proto.clone

local StringStream = require "loop.serial.StringStream"

local oo = require "oil.oo"
local class = oo.class


local Codec = class()

function Codec:localresources(resources)
	local names = {}
	local values = {}
	for name, resource in pairs(resources) do
		names[resource] = name
		values[name] = resource
	end
	local proxykind = resources.proxykind
	for _, kind in ipairs(proxykind) do
		local manager = proxykind[kind]
		local class = manager.class
		local name = kind.."ProxyClass"
		names[class] = name
		values[name] = class
	end
	self.encoderprototype = StringStream(names)
	self.decoderprototype = StringStream(values)
	self.encoderprototype:register(loaded)
end

function Codec:encoder()
	return clone(self.encoderprototype)
end

function Codec:decoder(stream)
	return clone(self.decoderprototype, { data = stream })
end

return Codec
