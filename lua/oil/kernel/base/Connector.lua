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

local DefaultOptions = {"all", "no_sslv2"}
local TargetVerify = {"peer", "fail_if_no_peer_cert"}
function Connector:resolveprofile(profile, configs)
	local connid, sslcontext
	local host = self.resolvedhosts[profile.host].host
	local port = profile.port
	local required = (configs ~= nil) and (configs.security == "required")
	local ssllocal = (configs ~= nil) and configs.ssl or self.sslcfg
	local sslremote = profile.ssl
	local targettrust, clienttrust = false, false
	if ssllocal ~= nil and sslremote ~= nil then                                  --[[VERBOSE]] verbose:channels("target provides secure connection support")
		required = required or sslremote.required
		targettrust = ssllocal.cafile == nil or sslremote.targettrust
		clienttrust = not sslremote.clienttrust or ssllocal.certificate ~= nil
	end
	if targettrust and clienttrust then                                           --[[VERBOSE]] verbose:channels("secure connection support matches requirements")
		if required or (configs ~= nil and configs.security == "preferred") then
			port = sslremote.port
			sslcontext = ssllocal.context
			if sslcontext == nil then
				local errmsg
				sslcontext, errmsg = self.sockets:sslcontext{
					mode = "client",
					protocol = "sslv23",
					options = DefaultOptions,
					verify = ssllocal.cafile ~= nil and TargetVerify or nil,
					key = ssllocal.key,
					certificate = ssllocal.certificate,
					cafile = ssllocal.cafile,
				}
				if not sslcontext then
					return nil, Exception{
						"unable to create SSL context for invocation ($errmsg)",
						error = "badinitialize",
						errmsg = errmsg,
					}
				end                                                                     --[[VERBOSE]] verbose:channels("establish secure connection to ",host,":",port)
				ssllocal.context = sslcontext
			end
			connid = tuple[host][port][ssllocal]
		else                                                                        --[[VERBOSE]] verbose:channels("avoiding use secure connection")
			connid = tuple[host][port]
		end
	elseif required then
		port = sslremote ~= nil and sslremote.port or port                          --[[VERBOSE]] verbose:channels("unable to establish secure connection to ",host,":",port)
		return nil, Exception{
			"unable to connect securely to $host:$port ($errmsg)",
			error = "badsecurity",
			errmsg = targettrust and "target requires authentication"
			                      or "target cannot be trusted",
			host = host,
			port = port,
		}
	else                                                                          --[[VERBOSE]] verbose:channels("use insecure connection")
		connid = tuple[host][port]
	end
	return connid, host, port, sslcontext
end

function Connector:connectto(connid, host, port, sslctx)
	if connid == nil then return nil, host end
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
				if sslctx ~= nil then
					socket, except = sockets:ssl(socket, sslctx)
				end
				if socket then
					cache[connid] = socket
					addto(self.keyindex, connid, socket)
				end
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

function Connector:register(socket, profile, configs)                           --[[VERBOSE]] verbose:channels(true, "got bidirectional channel to ",profile.host,":",profile.port)
	local connid, host, port = self:resolveprofile(profile, configs)              --[[VERBOSE]] if host ~= profile.host then verbose:channels("channel registered as ",host,":",profile.port) end
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

function Connector:retrieve(profile, configs)                                   --[[VERBOSE]] verbose:channels(true, "get channel to ",profile.host,":",profile.port)
	return self:connectto(self:resolveprofile(profile, configs))
end

return Connector