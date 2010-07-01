-- Project: OiL - ORB in Lua
-- Release: 0.5
-- Title  : Factory of outgoing (client-side) channels
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local setmetatable = _G.setmetatable

local tuples = require "tuple"
local tuple = tuples.index

local tabop = require "loop.table"
local copy = tabop.copy

local oo = require "oil.oo"
local class = oo.class
local rawnew = oo.rawnew

local Exception = require "oil.Exception"
local Channels = require "oil.kernel.base.Channels"                             --[[VERBOSE]] local verbose = require "oil.verbose"

module(...)

class(_M, Channels)

--------------------------------------------------------------------------------
-- connection management

LuaSocketOps = copy(Channels.LuaSocketOps)
CoSocketOps = copy(Channels.CoSocketOps)

function LuaSocketOps:close()
	local cache = self.cache[self.connid]
	cache[self.connid] = nil
	return self.__object:close()
end

CoSocketOps.close = LuaSocketOps.close


function LuaSocketOps:reset()                                                   --[[VERBOSE]] verbose:channels("resetting channel (attempt to reconnect)")
	self.__object:close()
	local sockets = self.sockets
	local result, except = sockets:tcp()
	if result then
		local socket = result
		result, except = socket:connect(self.host, self.port)
		if result then
			self.__object = socket
		end
	end
	return result, except
end

function CoSocketOps:reset()                                                    --[[VERBOSE]] verbose:channels("resetting channel (attempt to reconnect)")
	self.__object:close()
	local sockets = self.sockets
	local result, except = sockets:tcp()
	if result then
		local socket = result
		result, except = socket:connect(self.host, self.port)
		if result then
			self.__object = socket.__object
			self.readevent = socket.readevent
		end
	end
	return result, except
end

--------------------------------------------------------------------------------
-- channel cache for reuse

function __new(self, object)
	self = rawnew(self, object)
	self.cache = setmetatable({}, {__mode = "v"})
	return self
end

--------------------------------------------------------------------------------
-- channel factory

function retrieve(self, profile)                                                --[[VERBOSE]] verbose:channels("retrieve channel connected to ",profile.host,":",profile.port)
	local connid = tuple[profile.host][profile.port]
	local cache = self.cache
	local channel, except = cache[connid]
	if channel == nil then
		local sockets = self.sockets
		channel, except = sockets:tcp()
		if channel then
			local host, port = profile.host, profile.port                             --[[VERBOSE]] verbose:channels("new socket to ",host,":",port)
			local success
			success, except = channel:connect(host, port)
			if success then
				channel = self:setupsocket(channel)
				channel.sockets = sockets
				channel.cache = cache
				channel.connid = connid
				channel.host = host
				channel.port = port
				cache[connid] = channel
			else
				channel, except = nil, Exception{ "badconnect",
					message = "unable to connect to $host:$port ($error)",
					error = except,
					host = host,
					port = port,
				}
			end
		else
			channel, except = nil, Exception{ "badsocket",
				message = "unable to create socket ($error)",
				error = except,
			}
		end
	end
	return channel, except
end
