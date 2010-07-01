-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Factory of incomming (server-side) channels
-- Authors: Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"
local ipairs = _G.ipairs
local select = _G.select

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"

module(...); local _ENV = _M


AccessPoint = class()

function AccessPoint:accept(timeout)
	local poll = self.poll
	local socket, except
	repeat
		socket, except = poll:getready(timeout)
		if socket == self.socket then
			socket, except = socket:accept()
			if socket then
				socket = self.sockets:setoptions(self.options, socket)
				poll:add(socket)
			else                                                                      --[[VERBOSE]] verbose:channels("error when accepting connection (",except,")")
				except = Exception{
					error = "badconnect",
					message = "unable to accept connection ($errmsg)",
					errmsg = except,
				}                                                                       --[[VERBOSE]] else verbose:channels "new connection accepted"
			end
		elseif socket then
			socket:settimeout(0)
			if select(2, socket:receive(0)) == "closed" then
				poll:remove(socket)
				socket = nil
			else
				socket:settimeout(nil)
			end
		elseif except == "timeout" then
			except = Exception.Timeout
		elseif except == "empty" then
			except = Exception.Terminated
		end
	until socket or except
	return socket, except
end

function AccessPoint:remove(socket)
	self.poll:remove(socket)
end

function AccessPoint:add(socket)
	self.poll:remove(socket)
end

function AccessPoint:close()
	local poll = self.poll
	local socket = self.socket
	if socket then
		poll:remove(socket)
		socket:close()
		self.socket = nil
	end
	return poll:clear()
end

function AccessPoint:address()
	local socket = self.socket
	local host, port = socket:getsockname()
	if not host then return nil, port end
	
	local dns = self.dns
	
	-- find out local host name
	if host == "0.0.0.0" then
		local error
		host = dns:gethostname()
		if not host then return nil, error end
	end
	
	-- collect addresses
	local addr
	local ip, extra = dns:toip(host)
	if ip then
		host = ip
		addr = extra.ip
		addr[#addr+1] = extra.name
		local aliases = extra.alias
		for i = 1, #aliases do
			addr[#addr+1] = aliases[i]
		end
	else
		addr = {host}
	end
	
	for i = 1, #addr do
		addr[ addr[i] ] = i
	end
	
	return host, port, addr
end


class(_ENV)

function _ENV:newaccess(configs)
	local options = self.options
	local sockets = self.sockets
	local socket, except = sockets:newsocket(options)
	if not socket then                                                            --[[VERBOSE]] verbose:channels("unable to create socket (",except,")")
		return nil, Exception{
			error = "badsocket",
			message = "unable to create socket ($errmsg)",
			errmsg = except,
		}
	end
	local host = configs.host or "*"
	local port = configs.port or 0
	local success
	success, except = socket:bind(host, port)
	if not success then                                                           --[[VERBOSE]] verbose:channels("unable to bind to ",host,":",port," (",except,")")
		socket:close()
		return nil, Exception{
			error = "badaddress",
			message = "unable to bind to $host:$port ($errmsg)",
			errmsg = except,
			host = host,
			port = port,
		}
	end
	success, except = socket:listen(options and options.backlog)
	if not success then                                                           --[[VERBOSE]] verbose:channels("unable to listen to ",host,":",port," (",except,")")
		socket:close()
		return nil, Exception{
			error = "badinitialize",
			message = "unable to listen to $host:$port ($error)",
			errmsg = except,
			host = host,
			port = port,
		}
	end                                                                           --[[VERBOSE]] verbose:channels("new port binded to ",host,":",port)
	return AccessPoint{
		options = options,
		socket = socket,
		sockets = sockets,
		dns = self.dns,
		poll = sockets.newpoll(),
	}
end
