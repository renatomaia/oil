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
-- Notes:                                                                     --
--   See section 15.7 of CORBA 3.0 specification.                             --
--   See section 13.6.10.3 of CORBA 3.0 specification for IIOP corbaloc.      --
--------------------------------------------------------------------------------
-- channels:Facet
-- 	channel:object retieve(configs:table, [probe:boolean])
-- 
-- sockets:Receptacle
-- 	socket:object tcp()
-- 	input:table, output:table select([input:table], [output:table], [timeout:number])
--------------------------------------------------------------------------------

local next         = next
local pairs        = pairs
local setmetatable = setmetatable
local type         = type

local tabop = require "loop.table"

local Wrapper  = require "loop.object.Wrapper"
local Channels = require "oil.kernel.base.Channels"

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.kernel.base.Connector"

oo.class(_M, Channels)

--------------------------------------------------------------------------------
-- connection management

LuaSocketOps = tabop.copy(Channels.LuaSocketOps)
CoSocketOps = tabop.copy(Channels.CoSocketOps)

function LuaSocketOps:close()
	local cache = self.cache[self.connid]
	cache[self.connid] = nil
	return self.__object:close()
end

CoSocketOps.close = LuaSocketOps.close

function LuaSocketOps:reset()                                                   --[[VERBOSE]] verbose:channels("resetting channel (attempt to reconnect)")
	self.__object:close()
	local sockets = self.sockets
	local result, errmsg = sockets:tcp()
	if result then
		local socket = result
		result, errmsg = socket:connect(self.host, self.port)
		if result then
			self.__object = socket
		end
	end
	return result, errmsg
end
function CoSocketOps:reset()                                                    --[[VERBOSE]] verbose:channels("resetting channel (attempt to reconnect)")
	self.__object:close()
	local sockets = self.sockets
	local result, errmsg = sockets:tcp()
	if result then
		local socket = result
		result, errmsg = socket:connect(self.host, self.port)
		if result then
			self.__object = socket.__object
			self.readevent = socket.readevent
		end
	end
	return result, errmsg
end

local list = {}
function LuaSocketOps:probe()
	list[1] = self.__object
	return self.sockets:select(list, nil, 0)[1] == list[1]
end
function CoSocketOps:probe()
	local list = { self }
	local res = self.sockets:select(list, nil, 0)[1]
	if res ~= nil then
		return res.__object == list[1].__object
	end
	return false
end

--------------------------------------------------------------------------------
-- channel cache for reuse

function __new(self, object)
	self = oo.rawnew(self, object)
	self.cache = setmetatable({}, {__mode = "v"})
	return self
end

--------------------------------------------------------------------------------
-- channel factory

function retrieve(self, profile)                                                --[[VERBOSE]] verbose:channels("retrieve channel connected to ",profile.host,":",profile.port)
	local connid = profile.connid
	if not connid then
		connid = profile.host..":"..profile.port
		profile.connid = connid
	end
	local cache = self.cache
	local channel, errkind, errmsg = cache[connid]
	if channel == nil then
		local sockets = self.sockets
		channel, errmsg = sockets:tcp()
		if channel then
			local host, port = profile.host, profile.port                             --[[VERBOSE]] verbose:channels("new socket to ",host,":",port)
			local success
			success, errmsg = channel:connect(host, port)
			if success then
				channel = self:setupsocket(channel)
				channel.sockets = sockets
				channel.cache = cache
				channel.connid = connid
				channel.host = host
				channel.port = port
				self.cache[connid] = channel
			else
				errkind = "channel connection failed"
				channel = nil
			end
		else
			errkind = "channel creation failed"
		end
	end
	return channel, errkind, errmsg
end
