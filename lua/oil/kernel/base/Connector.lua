-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Factory of outgoing (client-side) channels
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local setmetatable = _G.setmetatable
local tonumber = _G.tonumber

local table = require "loop.table"
local copy = table.copy
local memoize = table.memoize

local tuples = require "tuple"
local tuple = tuples.index

local CyclicSets = require "loop.collection.CyclicSets"
local addto = CyclicSets.add
local removefrom = CyclicSets.removefrom
local cyclefrom = CyclicSets.forward

local oo = require "oil.oo"
local class = oo.class
local rawnew = oo.rawnew

local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"

local WeakValues = class{ __mode = "v" }
local WeakTable = class{ __mode = "kv" }



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
	self.keyindex = WeakTable()
	self.resolvedhosts = memoize(function (host)
		local a, b, c, d = host:match(IpPattern)
		if (a == nil) or not ipaddr(a, b, c, d) then
			host = self.dns:toip(host) or host
		end
		return {host = host} -- create a collectable result so the cache does not
		                     -- grows continuously.
	end, "v")
end

function Connector:resolveprofile(profile)
	local host = self.resolvedhosts[profile.host].host
	local port = profile.port                                                     --[[VERBOSE]] if profile.host ~= host then verbose:channels("getting channel to ",host,":",port," instead") end
	return tuple[host][port], host, port
end

function Connector:connectto(connid, host, port)
	local cache = self.cache
	local socket, except = cache[connid]
	if socket ~= nil then
		local _, timeout, tmkind = socket:settimeout(0)
		local success, except = socket:receive(0)
		socket:settimeout(timeout, tmkind)
		if not success and except == "closed" then
			self:unregister(socket)
			socket = nil
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
				addto(self.keyindex, connid, socket)
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

function Connector:register(socket, profile)                                    --[[VERBOSE]] verbose:channels(true, "got bidirectional channel to ",profile.host,":",profile.port)
	local connid, host, port = self:resolveprofile(profile)                       --[[VERBOSE]] if host ~= profile.host then verbose:channels("channel registered as ",host,":",profile.port) end
	self.cache[connid] = socket
	addto(self.keyindex, connid, socket)                                          --[[VERBOSE]] verbose:channels(false)
end

function Connector:unregister(socket)
	local cache = self.cache
	local keys = self.keyindex
	local connid = keys[socket]
	if connid ~= nil then
		keys[socket] = nil
		while connid ~= socket do                                                   --[[VERBOSE]] local verbose_host, verbose_port = connid(); verbose:channels("discarding channel to ",verbose_host,":",verbose_port)
			cache[connid] = nil
			connid, keys[connid] = keys[connid], nil
		end
		return socket
	end
end

function Connector:retrieve(profile)                                            --[[VERBOSE]] verbose:channels(true, "get channel to ",profile.host,":",profile.port)
	local host = self.resolvedhosts[profile.host].host
	local port = profile.port
	return self:connectto(self:resolveprofile(profile))
end

return Connector