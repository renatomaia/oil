-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Factory of incomming (server-side) channels
-- Authors: Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"; local tostring = _G.tostring
local ipairs = _G.ipairs
local next = _G.next
local select = _G.select

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"


local function addaddr(collection, host, port)
	local ports = collection[host]
	if ports == nil then
		ports = {}
		collection[host] = ports
	end
	if ports[port] == nil then
		local index = #collection+1
		collection[index] = {host=host, port=port}
		ports[port] = index
	end
end


local AccessPoint = class{ addropts = {} }

function AccessPoint:accept(timeout)
	local poll = self.poll
	local socket, except
	repeat
		socket, except = poll:getready(timeout)
		if socket ~= nil then
			local kind = self.ports[socket]
			if kind ~= nil then
				local port = socket
				socket, except = port:accept()
				if socket ~= nil then
					local baresock = socket
					if kind == "ssl" then
						socket, except = self.sockets:ssl(socket, self.sslctx)
					end
					if socket then                                                        --[[VERBOSE]] local host,port = socket:getpeername(); verbose:channels("new ",kind," connection accepted from ",host,":",port)
						socket = self.sockets:setoptions(self.options, socket)
						poll:add(socket)
					else                                                                  --[[VERBOSE]] verbose:channels("error when securing connection (",except,")")
						baresock:close()
						except = Exception{
							"unable to establish secure connection ($errmsg)",
							error = "badsecurity",
							errmsg = except,
						}
					end
				else                                                                    --[[VERBOSE]] verbose:channels("error when accepting connection (",except,")")
					if except == "closed" then poll:remove(port) end
					except = Exception{
						"unable to accept connection ($errmsg)",
						error = "badconnect",
						errmsg = except,
					}
				end
			else
				local _, timeout, tmkind = socket:settimeout(0)
				local success, errmsg = socket:receive(0)
				socket:settimeout(timeout, tmkind)
				if not success and errmsg == "closed" then                              --[[VERBOSE]] local host,port = socket:getpeername(); verbose:channels("connection from ",host,":",port," was closed")
					poll:remove(socket)
					socket = nil                                                          --[[VERBOSE]] else local host,port = socket:getpeername(); verbose:channels("connection from ",host,":",port," is ready to be read",success and "" or " (got error '"..tostring(errmsg).."')")
				end
			end
		elseif except == "timeout" then                                             --[[VERBOSE]] verbose:channels("timeout when accepting connection")
			except = Exception{ "timeout", error = "timeout" }
		elseif except == "empty" then                                               --[[VERBOSE]] verbose:channels("accepting connection terminated")
			except = Exception{ "terminated", error = "terminated" }
		end
	until socket or except
	return socket, except
end

function AccessPoint:remove(socket)
	self.poll:remove(socket)
end

function AccessPoint:add(socket, ready)
	self.poll:add(socket, ready)
end

function AccessPoint:close()
	local poll = self.poll
	for socket in pairs(self.ports) do
		poll:remove(socket)
		socket:close()
		self.ports[socket] = nil
	end
	return poll:clear()
end

function AccessPoint:address()
	local options = self.addropts
	local ip = self.hostname
	local port = self.portno
	local sslport = self.sslportno

	local dns = self.dns
	-- find out local host name
	local hostname, dnsinfo
	if ip == "0.0.0.0" then
		local errmsg
		hostname, errmsg = dns:gethostname()
		if not hostname then return nil, errmsg end
		ip, dnsinfo = dns:toip(hostname)
	end

	-- collect addresses
	local addresses = {}
	local host
	if options.ipaddress ~= false then
		addaddr(addresses, ip, port)
		host = ip
	end
	if options.hostname ~= false then
		if hostname == nil and dnsinfo == nil then
			hostname, dnsinfo = dns:toname(ip)
			if hostname == nil then dnsinfo = nil end
		end
		if dnsinfo ~= nil then
			if options.ipaddress ~= false then
				for _, ip in ipairs(dnsinfo.ip) do
					addaddr(addresses, ip, port)
				end
			end
			addaddr(addresses, dnsinfo.name, port)
			local aliases = dnsinfo.alias
			for i = 1, #aliases do
				addaddr(addresses, aliases[i], port)
			end
		end
		host = host or hostname
	end
	host = host or ip
	local additional = options.additional
	if additional ~= nil then
		for _, address in ipairs(additional) do
			addaddr(addresses, address.host or host, address.port or port)
		end
	end

	if #addresses == 0 then
		addaddr(addresses, host, port)
	end

	return {
		host = host,
		port = port,
		sslport = sslport,
		sslcfg = self.sslcfg,
		addresses = addresses,
	}
end


local function newport(sockets, options, host, port)
	local socket, except = sockets:newsocket(options)
	if not socket then                                                            --[[VERBOSE]] verbose:channels("unable to create socket (",except,")")
		return nil, Exception{ "unable to create socket ($errmsg)",
			error = "badsocket",
			errmsg = except,
		}
	end
	local success
	success, except = socket:bind(host, port)
	if not success then                                                           --[[VERBOSE]] verbose:channels("unable to bind to ",host,":",port," (",except,")")
		socket:close()
		return nil, Exception{ "unable to bind to $host:$port ($errmsg)",
			error = "badaddress",
			errmsg = except,
			host = host,
			port = port,
		}
	end
	success, except = socket:listen(options and options.backlog)
	if not success then                                                           --[[VERBOSE]] verbose:channels("unable to listen to ",host,":",port," (",except,")")
		socket:close()
		return nil, Exception{ "unable to listen to $host:$port ($errmsg)",
			error = "badinitialize",
			errmsg = except,
			host = host,
			port = port,
		}
	end                                                                           --[[VERBOSE]] verbose:channels("new port binded to ",host,":",port)
	return socket
end


local Acceptor = class()

local DefaultOptions = {"all", "no_sslv2"}
local TargetVerify = {"peer", "fail_if_no_peer_cert"}
function Acceptor:newaccess(configs)
	local options = self.options
	local sockets = self.sockets
	local host = configs.host or "*"
	local port = configs.port or 0
	local sslport
	local socket, errmsg = newport(sockets, options, host, port)
	if socket == nil then return nil, errmsg end
	local poll = sockets:newpoll()
	if host == "*" or port == 0 then
		local sckhost, sckport = socket:getsockname()
		if sckhost == nil then                                                      --[[VERBOSE]] verbose:channels("unable to obtain the actual port orb was binded to (",sckport,")")
			return nil, Exception{ "unable to obtain the actual binded address ($errmsg)",
				error = "badinitialize",
				errmsg = sckport,
			}
		end
		if host == "*" then                                                         --[[VERBOSE]] verbose:channels("orb port binded to host ",sckhost)
			host, configs.host = sckhost, sckhost
		end
		if port == 0 then                                                           --[[VERBOSE]] verbose:channels("orb port binded to port ",sckport)
			port, configs.port = sckport, sckport
		end
	end
	local ports = {[socket] = "tcp"}
	local sslcfg, sslctx = self.sslcfg
	if sslcfg ~= nil then
		sslctx = sockets:sslcontext{
			mode = "server",
			protocol = "sslv23",
			options = DefaultOptions,
			verify = sslcfg.cafile ~= nil and TargetVerify,
			key = sslcfg.key,
			certificate = sslcfg.certificate,
			cafile = sslcfg.cafile,
		}
		sslport = configs.sslport or 0
		local sslsck, errmsg = newport(sockets, options, host, sslport)
		if sslsck == nil then return nil, errmsg end
		if sslport == 0 then
			local sckhost, sckport = sslsck:getsockname()
			if sckhost == nil then                                                    --[[VERBOSE]] verbose:channels("unable to obtain the actual secure port orb was binded to: ",sckport)
				return nil, Exception{ "unable to obtain the actual binded secure port at host '$host' ($errmsg)",
					error = "badinitialize",
					errmsg = sckport,
					host = host,
				}
			end
			sslport, configs.sslport = sckport, sckport                               --[[VERBOSE]] verbose:channels("orb secure port binded to host ",sslport)
		end
		poll:add(sslsck)
		ports[sslsck] = "ssl"
	end
	poll:add(socket)
	return AccessPoint{
		options = options,
		addropts = configs.objrefaddr,
		sslcfg = sslcfg,
		sslctx = sslctx,
		ports = ports,
		sockets = sockets,
		dns = self.dns,
		poll = poll,
		hostname = host,
		portno = port,
		sslportno = sslport,
	}
end

return Acceptor
