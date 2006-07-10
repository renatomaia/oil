-- $Id$
--******************************************************************************
-- Copyright 2002 Noemi Rodriquez & Roberto Ierusalimschy. All rights reserved. 
--******************************************************************************

--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua: An Object Request Broker in Lua                 --
-- Release: 0.3 alpha                                                         --
-- Title  : Internet Inter-ORB Protocol (IIOP) over sockets                   --
-- Authors: Renato Maia           <maia@inf.puc-rio.br>                       --
--          Antonio Theophilo     <theophilo@inf.puc-rio.br>                  --
--------------------------------------------------------------------------------
-- Connection interface:                                                      --
--   receive(reqid)   Returns a message ID, header and buffer with the data   --
--   send(i,h,t,d)    Sends a message with ID,header,contents types and data  --
--   close()          Closes the connection                                   --
--      
-- Port interface:                                                            --
--   profile(objid)   Returns a marshalled profile with port and object id    --
--   waitformore(t)   Wait for more messages for t to 2*t seconds             --
--   accept(orb)      Reads one request and treat it with the provided ORB    --
--   acceptall(orb)   Handles all subsequent requests with the provided ORB   --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   See section 15.7 of CORBA 3.0 specification.                             --
--   See section 13.6.10.3 of CORBA 3.0 specification for IIOP corbaloc.      --
--------------------------------------------------------------------------------

local require      = require

local oo        = require "oil.oo"

module ( "oil.Acceptor", oo.class )                                          --[[VERBOSE]] local verbose = require "oil.verbose"

local Exception          = require "oil.Exception"
local MapWithArrayOfKeys = require "loop.collection.MapWithArrayOfKeys"
local OrderedSet         = require "loop.collection.OrderedSet"
local socket             = require "oil.socket"

------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Port implementation
--------------------------------------------------------------------------------

local Empty = {}
local Port = oo.class()

function Port:__init(port)
	port.ready = OrderedSet() -- queue of ready connections
	port.connections = MapWithArrayOfKeys()
	port.connections:add(port.socket) -- first connection will always be the port
	return oo.rawnew(self, port)
end

function Port:waitformore(timeout)
	local ready = self.ready
	if self.ready:empty() then
		local connections = self.connections
		local attempts = 0 -- how many attempts to select a socket?
		local giveup = false
		repeat
			attempts = attempts + connections:size()                                  --[[VERBOSE]] verbose:listen("waiting for messages or more connections (", connections:size() - 1, ") [timeout: ", timeout, "]")
			local selected = socket:select(connections, Empty, timeout)
			local port = self.socket
			if selected[port] then                                                    --[[VERBOSE]] verbose:listen( "new connection accepted" )
				selected[port] = nil
				local conn = self.protocol:createConnection{
					pending = {},
					socket = port:accept(),
					port = self,
				}
				connections:add(conn.socket, conn)
			end
			for sock in pairs(selected) do
				if type(sock) ~= "number" then                                          --[[VERBOSE]] verbose:listen( "got new message" )
					local conn = connections[sock]
					ready:enqueue(conn)
				end
			end
			if timeout and timeout >= 0 then
				-- select has already tried to select ready sockets for timeout seconds
				if attempts > 1 or connections:size() == 1 then
					-- there were other attempts to select sockets besides
					-- the first one to select the port socket or ...
					-- no new connections were created
					giveup = true                                                         --[[VERBOSE]] else verbose:listen "repeating selection for new connections"
				end
			else
				giveup = not ready:empty()
			end
		until giveup
		return not ready:empty()
	else
		return true
	end
end

-- TODO:[nogara] Add scheduler to this part of code again after all is working
function Port:accept()
	local conn = self.ready:dequeue()
	if not conn then                                                              --[[VERBOSE]] verbose:listen(true, "no message, waiting for more")
		if self:waitformore() then
			conn = self.ready:dequeue()
		end                                                                         --[[VERBOSE]] verbose:listen(false) else verbose:listen "message already queued"
	end
	return self.protocol:handle(dispatcher, conn)
end

function Port:acceptall()
	local success, errmsg
	repeat
		success, errmsg = self:accept(dispatcher)
	until not success
	return success, errmsg
end

function createPort(self, args)
	local host = args.host or "*"
	local port = args.port
	local conn, except, reason
	-- use the protocol.listen function to create a new connection
	conn, except, reason = self:listen(host, port)
	if conn then
		conn = Port{
		  socket = conn.socket,
		  host = conn.host,
		  port = conn.port,
		  iorhost = args.iorhost,
		  iorport = args.iorport,
		  protocol = self,
		}
	else
		conn, except = nil, Exception{ "NO_RESOURCES", minor_code_value = 0,
		  message = "unable to bind to address "..host..":"..port,
		  reason = reason,
		  error = except,
		  host = host,
		  port = port,
		}
	end
	return conn, except
end

function listen(self, args)
		-- return port for given protocol 
		local channel = self.listener:getchannel(args)
		if channel then
			return Port{
				socket = conn.socket,
				host = conn.host,
				port = conn.port,
				iorhost = args.iorhost,
				iorport = args.iorport,
				protocol = self,
			}
		else
			conn, except = nil, Exception{ "NO_RESOURCES", minor_code_value = 0,
				message = "unable to bind to address "..host..":"..port,
				reason = reason,
				error = except,
				host = host,
				port = port,
			}
		end
		return conn, except

		return nil, Exception{ "NO_PROTOCOL", minor_code_value = 0,
			message = "no protocol registered for " .. protocol_type,
		} 
end
