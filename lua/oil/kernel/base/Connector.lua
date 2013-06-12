-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Factory of outgoing (client-side) channels
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local setmetatable = _G.setmetatable

local table = require "loop.table"
local copy = table.copy
local memoize = table.memoize

local tuples = require "tuple"
local tuple = tuples.index

local oo = require "oil.oo"
local class = oo.class
local rawnew = oo.rawnew

local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"

local WeakValues = class{ __mode = "v" }



local function ipaddr(a, b, c, d)
	return (tonumber(a) < 256)
	   and (tonumber(b) < 256)
	   and (tonumber(c) < 256)
	   and (tonumber(d) < 256)
end

local IpPattern = "^(%d+)%.(%d+)%.(%d+)%.(%d+)$"

local Connector = class()

function Connector:__init()
	self.cache = WeakValues()
	self.resolvedhosts = memoize(function (host)
		local a, b, c, d = host:match(IpPattern)
		if (a == nil) or not ipaddr(a, b, c, d) then
			host = self.dns:toip(host) or host
		end
		return {host = host} -- create a collectable result so the cache does not
		                     -- grows continuously.
	end, "w")
end

function Connector:register(socket, profile)                                    --[[VERBOSE]] verbose:channels(true, "got bidirectional channel to ",profile.host,":",profile.port)
	local host = self.resolvedhosts[profile.host].host                            --[[VERBOSE]] if profile.host ~= host then verbose:channels("channel registered as ",host,":",profile.port) end
	local connid = tuple[host][profile.port]
	self.cache[connid] = socket                                                   --[[VERBOSE]] verbose:channels(false)
end

function Connector:retrieve(profile)                                            --[[VERBOSE]] verbose:channels(true, "get channel to ",profile.host,":",profile.port)
	local host = self.resolvedhosts[profile.host].host
	local port = profile.port                                                     --[[VERBOSE]] if profile.host ~= host then verbose:channels("getting channel to ",host,":",port," instead") end
	local connid = tuple[host][port]
	local cache = self.cache
	local socket, except = cache[connid]
	if socket ~= nil then
		socket:settimeout(0)
		local success, except = socket:receive(0)
		if not success and except == "closed" then
			cache[connid] = nil
			socket = nil
		else
			socket:settimeout(nil)
		end
	end
	if socket == nil then
		local sockets = self.sockets
		socket, except = sockets:newsocket(self.options)
		if socket then                                                              --[[VERBOSE]] verbose:channels("create new channel to ",host,":",port)
			local success
			success, except = socket:connect(host, port)
			if success then
				cache[connid] = socket
			else                                                                      --[[VERBOSE]] verbose:channels("unable to connect to ",host,":",port," (",except,")")
				socket, except = nil, Exception{
					"unable to connect to $host:$port ($errmsg)",
					error = "badconnect",
					errmsg = except,
					host = host,
					port = port,
				}
			end
		else                                                                        --[[VERBOSE]] verbose:channels("unable to create socket (",except,")")
			socket, except = nil, Exception{
				"unable to create socket ($errmsg)",
				error = "badsocket",
				errmsg = except,
			}
		end
	end                                                                           --[[VERBOSE]] verbose:channels(false)
	return socket, except
end

return Connector