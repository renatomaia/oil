-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Factory of incomming (server-side) channels
-- Authors: Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"; local tostring = _G.tostring
local ipairs = _G.ipairs
local select = _G.select

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"


local function addaddr(collection, host, port)
	if collection[host] == nil then
		local index = #collection+1
		collection[index] = {host=host, port=port}
		collection[host] = index
	end
end


local AccessPoint = class{ addropts = {} }

function AccessPoint:accept(timeout)
	local poll = self.poll
	local socket, except
	repeat
		socket, except = poll:getready(timeout)
		if socket ~= nil then
			if socket == self.socket then
				local port = socket
				socket, except = port:accept()
				if socket ~= nil then                                                   --[[VERBOSE]] local host,port = socket:getpeername(); verbose:channels("new connection accepted from ",host,":",port)
					socket = self.sockets:setoptions(self.options, socket)
					poll:add(socket)
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
	local socket = self.socket
	if socket ~= nil then
		poll:remove(socket)
		socket:close()
		self.socket = nil
	end
	return poll:clear()
end

function AccessPoint:address()
	local options = self.addropts
	local socket = self.socket
	local ip, port = socket:getsockname()
	if not ip then return nil, port end
	
	local dns = self.dns
	
	-- find out local host name
	local host, dnsinfo
	if ip == "0.0.0.0" then
		local errmsg
		host, errmsg = dns:gethostname()
		if not host then return nil, errmsg end
		ip, dnsinfo = dns:toip(host)
	else
		host = ip
	end
	-- collect addresses
	local addresses = {}
	if options.ipaddr ~= false then
		addaddr(addresses, ip, port)
	end
	if options.usedns ~= false then
		if host == ip then
			host, dnsinfo = dns:toname(host)
			if host == nil then
				host, dnsinfo = ip
			end
		end
		if dnsinfo ~= nil then
			if options.ipaddr ~= false then
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
	end
	local additional = options.additional
	if additional ~= nil then
		for _, address in ipairs(additional) do
			addaddr(addresses, address.host, address.port)
		end
	end
	if #addresses == 0 then
		addaddr(addresses, host, port)
	end

	return {
		host = host,
		port = port,
		addresses = addresses,
	}
end


local Acceptor = class()

function Acceptor:newaccess(configs)
	local options = self.options
	local sockets = self.sockets
	local socket, except = sockets:newsocket(options)
	if not socket then                                                            --[[VERBOSE]] verbose:channels("unable to create socket (",except,")")
		return nil, Exception{ "unable to create socket ($errmsg)",
			error = "badsocket",
			errmsg = except,
		}
	end
	local host = configs.host or "*"
	local port = configs.port or 0
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
		return nil, Exception{ "unable to listen to $host:$port ($error)",
			error = "badinitialize",
			errmsg = except,
			host = host,
			port = port,
		}
	end                                                                           --[[VERBOSE]] verbose:channels("new port binded to ",host,":",port)
	local poll = sockets:newpoll()
	poll:add(socket)
	return AccessPoint{
		options = options,
		addropts = configs.objrefaddr,
		socket = socket,
		sockets = sockets,
		dns = self.dns,
		poll = poll,
	}
end

return Acceptor
