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
-- Release: 0.4                                                               --
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

local getmetatable = getmetatable
local pairs = pairs
local tostring = tostring
local rawget = rawget

local table        = require "loop.table"
local StringStream = require "loop.serial.StringStream"

local oo    = require "oil.oo"
local Codec = require "oil.ludo.Codec"                                             --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.ludo.CodecByRef"

oo.class(_M, Codec)

context = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function serialproxy(self, value, id)                                     --[[VERBOSE]] verbose:marshal("marshalling proxy for value ",value)
	self[value] = self.namespace..":value("..id..")"
	self:write(self.namespace,":value(",id,",'table',")
	self:write("proxies:resolve(")
	self:serialize(self.servants:register(value).__reference)
	self:write("))")
end

local function serialtable(self, value, id)                                     --[[VERBOSE]] verbose:marshal(true, "marshalling of table ",value)
	local reference = rawget(value, "__reference")
	if reference then                                                     --[[VERBOSE]] verbose:marshal "table is a proxy"
		self[value] = self.namespace..":value("..id..")"
		self:write(self.namespace,":value(",id,",'table',")
		self:write("proxies:resolve(")
		self:serialize(reference)
		self:write("))")
	elseif getmetatable(value) == nil then                                        --[[VERBOSE]] verbose:marshal "table by copy"
		StringStream.table(self, value, id)
	else                                                                          --[[VERBOSE]] verbose:marshal "table by reference"
		serialproxy(self, value, id)
	end                                                                           --[[VERBOSE]] verbose:marshal(false)
end

local LuDOStream = oo.class({
	table        = serialtable,
	thread       = serialproxy,
	userdata     = serialproxy,
	["function"] = serialproxy,
}, StringStream)

function encoder(self)
	return LuDOStream(table.copy(self.names, {servants = self.context.servants}))
end

function decoder(self, stream)
	return StringStream{
		environment = table.copy(self.values, {proxies = self.context.proxies}),
		data = stream,
	}
end
