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

module(...); local _ENV = _M

local WeakValues = class{ __mode = "v" }

class(_ENV)

--------------------------------------------------------------------------------
-- channel cache for reuse

function __new(self, object)
	self = rawnew(self, object)
	self.cache = WeakValues()
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
		channel, except = sockets:newsocket(self.options)
		if channel then
			local host, port = profile.host, profile.port                             --[[VERBOSE]] verbose:channels("new socket to ",host,":",port)
			local success
			success, except = channel:connect(host, port)
			if success then
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
