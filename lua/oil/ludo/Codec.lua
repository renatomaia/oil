--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua                                                  --
-- Release: 0.5                                                               --
-- Title  : Client-side CORBA GIOP Protocol specific to IIOP                  --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- channels:Facet
-- 	channel:object retieve(configs:table)
-- 	channel:object select(channel|configs...)
-- 	configs:table default(configs:table)
-- 
-- sockets:Receptacle
-- 	socket:object tcp()
-- 	input:table, output:table select([input:table], [output:table], [timeout:number])
--------------------------------------------------------------------------------

local _G = require "_G"
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

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"
local class = oo.class

local Referrer = require "oil.ludo.Referrer"

module("oil.ludo.Codec", class)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local WeakKey    = class{ __mode = "k" }
local WeakValues = class{ __mode = "v" }

function __init(self)
	self.names = WeakKey(self.names)
	self.values = WeakValues(self.values)
	self.names[Referrer.Reference] = "LuDOReference"
	self.values.LuDOReference = Referrer.Reference
end

function localresources(self, resources)
	local names = self.names
	local values = self.values
	for name, resource in pairs(resources) do
		names[resource] = name
		values[name] = resource
	end
end

function encoder(self)
	return StringStream(copy(self.names))
end

function decoder(self, stream)
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
