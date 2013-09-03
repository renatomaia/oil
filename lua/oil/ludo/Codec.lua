-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Client-side LuDO Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local loadstring = _G.loadstring
local pairs = _G.pairs
local setfenv = _G.setfenv
local setmetatable = _G.setmetatable

local debug = _G.debug -- only if available
local setupvalue = debug and debug.setupvalue
local upvaluejoin = debug and debug.upvaluejoin

local table = require "loop.table"
local copy = table.copy

local StringStream = require "loop.serial.StringStream"

local oo = require "oil.oo"
local class = oo.class

local Referrer = require "oil.ludo.Referrer"

local Codec = class()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local WeakKey    = class{ __mode = "k" }
local WeakValues = class{ __mode = "v" }

function Codec:__init()
	self.names = WeakKey(self.names)
	self.values = WeakValues(self.values)
	self.names[Referrer.Reference] = "LuDOReference"
	self.values.LuDOReference = Referrer.Reference
end

function Codec:localresources(resources)
	local names = self.names
	local values = self.values
	for name, resource in pairs(resources) do
		names[resource] = name
		values[name] = resource
	end
end

function Codec:encoder()
	return StringStream(copy(self.names))
end

function Codec:decoder(stream)
	return StringStream{
		environment = copy(self.values, {
			loadstring = loadstring,
			setfenv = setfenv,
			setmetatable = setmetatable,
			setupvalue = setupvalue,
			upvaluejoin = upvaluejoin,
		}),
		data = stream,
	}
end

return Codec
