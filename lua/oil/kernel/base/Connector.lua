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

local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"

local WeakValues = class{ __mode = "v" }

local Connector = class()

function Connector:__init()
	self.cache = WeakValues()
end

function Connector:register(socket, profile)                                    --[[VERBOSE]] verbose:channels("got bidirectional channel to ",profile.host,":",profile.port)
	self.cache[tuple[profile.host][profile.port]] = socket
end

function Connector:retrieve(profile)                                            --[[VERBOSE]] verbose:channels("get channel to ",profile.host,":",profile.port)
	local dns = self.dns
	local host = dns:toip(profile.host) or profile.host
	local connid = tuple[host][profile.port]
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
		if socket then
			local port = profile.port                                                 --[[VERBOSE]] verbose:channels("create new channel to ",host,":",port)
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
		else                                                                        --[[VERBOSE]] verbose:channels("unable to create socket")
			socket, except = nil, Exception{
				"unable to create socket ($errmsg)",
				error = "badsocket",
				errmsg = except,
			}
		end
	end
	return socket, except
end

return Connector