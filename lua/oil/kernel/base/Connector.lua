-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Factory of outgoing (client-side) channels
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local setmetatable = _G.setmetatable
local tonumber = _G.tonumber

local table = require "loop.table"
local memoize = table.memoize

local tuples = require "tuple"
local tuple = tuples.index

local CyclicSets = require "loop.collection.CyclicSets"
local addto = CyclicSets.add

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

local DefaultOptions = {"all", "no_sslv2"}
local TargetVerify = {"peer", "fail_if_no_peer_cert"}

local function registerchannel(self, channel, connid)
	local cache = self.cache
	local current = cache[connid]
	if channel ~= current then
		if current ~= nil then current:close("outgoing") end
		assert(cache[connid] == nil)
		cache[connid] = channel
		addto(self.keyindex, connid, channel)
		channel.connector = self
	end
end

local function resolveprofile(self, profile, configs)
	local connid, sslcontext
	local host = self.resolvedhosts[profile.host].host
	local port = profile.port
	local required = (configs ~= nil) and (configs.security == "required")
	local ssllocal = (configs ~= nil) and configs.ssl or self.sslcfg
	local sslremote = profile.ssl
	local targettrust, clienttrust = false, false
	if ssllocal ~= nil and sslremote ~= nil then                                  --[[VERBOSE]] verbose:channels("target provides secure connection support")
		local noca = (ssllocal.cafile == nil and ssllocal.capath == nil)
		required = required or sslremote.required
		targettrust = noca or sslremote.targettrust
		clienttrust = not sslremote.clienttrust or ssllocal.certificate ~= nil
	end
	if targettrust and clienttrust then                                           --[[VERBOSE]] verbose:channels("secure connection support matches requirements")
		if required or (configs ~= nil and configs.security == "preferred") then
			port = sslremote.port
			sslcontext = ssllocal.context
			if sslcontext == nil then
				local hasca = (ssllocal.cafile ~= nil or ssllocal.cafile ~= nil)
				local errmsg
				sslcontext, errmsg = self.sockets:sslcontext{
					mode = "client",
					protocol = ssllocal.protocol or "sslv23",
					options = ssllocal.options or DefaultOptions,
					verify = hasca and TargetVerify or nil,
					key = ssllocal.key,
					certificate = ssllocal.certificate,
					cafile = ssllocal.cafile,
					capath = ssllocal.capath,
				}
				if not sslcontext then
					return nil, Exception{
						"unable to create SSL context for invocation ($errmsg)",
						error = "badinitialize",
						errmsg = errmsg,
					}
				end
				ssllocal.context = sslcontext
			end                                                                       --[[VERBOSE]] verbose:channels("establish secure connection to ",host,":",port)
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

local function getconnection(self, connid, host, port, sslctx)
	if connid == nil then return nil, host end
	local sockets = self.sockets
	local cache = self.cache
	local reserved, socket, connected
	local channel, except
	repeat
		channel, except = cache[connid]
		if channel == nil then
			if reserved == nil then
				reserved, except = self.limiter:reserve() -- implicit yield!
				if reserved ~= nil then
					socket, except = sockets:newsocket(self.options)
					if socket == nil then                                                 --[[VERBOSE]] verbose:channels("unable to create socket (",except,")")
						except = Exception{
							"unable to create socket ($errmsg)",
							error = "badsocket",
							errmsg = except,
						}
						reserved:cancel()
						reserved = nil                                                      --[[VERBOSE]] else verbose:channels("create new channel to ",host,":",port)
					end
				end
			elseif not connected then
				connected, except = socket:connect(host, port) -- implicit yield!
				if not connected then                                                   --[[VERBOSE]] verbose:channels("unable to connect to ",host,":",port)
					except = Exception{
						"unable to connect to $host:$port ($errmsg)",
						error = (except=="timeout") and "timeout" or "badconnect",
						errmsg = except,
						host = host,
						port = port,
					}
					socket:close()
					reserved:cancel()
				end
			else
				local baresock = socket
				if sslctx ~= nil then
					socket, except = sockets:ssl(socket, sslctx)
				end
				if socket ~= nil then                                                   --[[VERBOSE]] verbose:channels("new connection ",host,":",port," registered")
					channel = self.channels:create(socket)
					reserved:set(channel)
					registerchannel(self, channel, connid)
				else                                                                    --[[VERBOSE]] verbose:channels("error when securing connection (",except,")")
					baresock:close()
					except = Exception{
						"unable to create secure connection ($errmsg)",
						error = "badsecurity",
						errmsg = except,
					}
				end
			end
		elseif channel:broken() then                                                --[[VERBOSE]] verbose:channels("current channel is closed and will be discarded")
			self:unregister(channel)
			channel = nil
		elseif reserve ~= nil then                                                  --[[VERBOSE]] verbose:channels("other channel already registered, discarding the one being created")
			socket:close()
			reserve:cancel()
		end
	until channel ~= nil or except ~= nil                                         --[[VERBOSE]] verbose:channels(false)
	return channel, except
end



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

function Connector:register(channel, profile, configs)                          --[[VERBOSE]] verbose:channels(true, "got bidirectional channel to ",profile.host,":",profile.port)
	local connid, host, port = resolveprofile(self, profile, configs)             --[[VERBOSE]] if host ~= profile.host then verbose:channels("channel registered as ",host,":",profile.port) end
	registerchannel(self, channel, connid)                                        --[[VERBOSE]] verbose:channels(false)
end

function Connector:unregister(channel)
	local cache = self.cache
	local keys = self.keyindex
	local connid = keys[channel]
	if connid ~= nil then
		keys[channel] = nil
		while connid ~= channel do                                                  --[[VERBOSE]] local verbose_host, verbose_port = connid(); verbose:channels("discarding channel to ",verbose_host,":",verbose_port)
			cache[connid] = nil
			connid, keys[connid] = keys[connid], nil
		end
		channel.connector = nil
		return channel
	end
end

function Connector:retrieve(profile, configs)                                   --[[VERBOSE]] verbose:channels(true, "get channel to ",profile.host,":",profile.port)
	return getconnection(self, resolveprofile(self, profile, configs))
end

function Connector:iterate()
	return pairs(self.cache)
end

return Connector
