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

local type         = type
local pairs        = pairs
local ipairs       = ipairs
local tonumber     = tonumber
local tostring     = tostring
local unpack       = unpack
local setmetatable = setmetatable
local require      = require
local rawget       = rawget
local scheduler    = scheduler

local print = print

local io        = require "io"
local string    = require "string"
local table     = require "table"
local math      = require "math"
local coroutine = require "coroutine"
local oo        = require "oil.oo"

module ("oil.corba.InternetIOP", oo.class)                                    --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local OrderedSet      = require "loop.collection.OrderedSet"
local Exception       = require "oil.Exception"
local assert          = require "oil.assert"
local giop            = require "oil.corba.giop"

local Empty = {}

-- protocol IIOP tag
Tag = 0

local Connection = oo.class()

function Connection:__init()
	self.replies = {}
	self.receivers = {}
	self.senders = OrderedSet()
	return oo.rawnew(self)
end

function Connection:close()
	self.socket:close()                                                           --[[VERBOSE]] verbose:close "connection socket closed"
end

function Connection:receive()

	local socket = self.socket
	local header, except = socket:receive(self.protocolHelper.HeaderSize)         --[[VERBOSE]] verbose:receive(true, "read GIOP header from socket [error: ", except, "]")
	if not header then
		if except == "closed" then self:close() end         
		return nil, Exception{ "COMM_FAILURE", minor_code_value = 0,
			message = "unable to read from socket",
			reason = except,
			socket = socket,
		}                                                                           --[[VERBOSE]] , verbose:receive(false)
	end
	
	-- overwrite header with the structure unmarshalled
	local size, type, buffer
	size, type, header, buffer = self.protocolHelper:unmarshallHeader(header)
	
	local stream
	if size then                                                                  --[[VERBOSE]] verbose:receive(false)
		stream, except = socket:receive(size)                                       --[[VERBOSE]] verbose:receive("read GIOP body from socket [error: ", except, "]")
		if not stream then
			if except == "closed" then self:close() end
			return nil, Exception{ "COMM_FAILURE", minor_code_value = 0,
				message = "unable to read from socket",
				reason = except,
				socket = socket,
			}                                                                         
		end
	end
	buffer.data = buffer.data..stream -- for alignment (Giop)
	header = buffer:struct(header)
	return type, header, buffer                                                   
end

function Connection:send(stream)           
	--
	-- Send data stream over the socket
	--
	local failures, success, except = 0                                           --[[VERBOSE]] verbose:send(true, "writing message into socket")
	repeat
		success, except = self.socket:send(stream)                                  --[[VERBOSE]] verbose:send("write GIOP message into socket [error: ", except, "]")
		if not success then
			if except == "closed" and self.host and failures < 1 then                 --[[VERBOSE]] verbose:send(true, "attempt to reconnect to ", self.host, ":", self.port)
				failures = failures + 1
				success, except = newsocket(self.host, self.port)
				if success
					then success, self.socket = false, success
					else self:close()
				end                                                                     --[[VERBOSE]] verbose:send(false)
			else
				except = Exception{ "COMM_FAILURE", minor_code_value = 0,
					message = "unable to write into socket",
					reason = except,
					socket = socket,
				}
			end
		end
	until success or except                                                       --[[VERBOSE]] verbose:send(false)
	
	return success, except
end

--------------------------------------------------------------------------------
-- Server connection management ------------------------------------------------

local PortConnection = oo.class({}, Connection)

function PortConnection:__init()
	self.senders = OrderedSet()
end

function PortConnection:close()
	-- test whether still active
	if self.port.connections:remove(self.socket) then                             --[[VERBOSE]] verbose:close "connection unregistered" verbose:close(true, "send close connection message")
		return self:send(self.protocolHelper.CloseConnectionID)                                         --[[VERBOSE]] , verbose:close(false)
	end
end


--------------------------------------------------------------------------------
-- Component class 
--------------------------------------------------------------------------------

function connect(self, reference)                                               
	local socket, except = self.channelFactory:connect(reference)
	-- if conn is not null, second return parameter is the object key of 
	--   the reference
	local conn = Connection{}
	conn.socket = socket
	conn.protocolHelper = self.protocolHelper                                     
	return conn, except or reference.object_key -- TODO[nogara]: what is object_key now?
end

local PortLowerBound = 2809 -- inclusive (never at first attempt)
local PortUpperBound = 9999 -- inclusive

function listen(self, host, port)
	local host = host or "*"
	local port = port
	local conn, except, reason
	if not port then
		local start = PortLowerBound -- + math.random(PortUpperBound - PortLowerBound)
		port = start
		repeat
			conn, except, reason = self.channelFactory:bind(host, port)
			if conn then break end
			if port >= PortUpperBound
				then port = PortLowerBound
				else port = port + 1
			end
		until port == start
	else
		conn, except, reason = self.channelFactory:bind(host, port)
	end
	if conn then 
		local newConn = {}
		newConn.socket = conn
		newConn.host = except -- the real host (if using "*" as host)
		newConn.port = port -- in case the port received as parameter is nil
		newConn.protocolHelper = self.protocolHelper
		return newConn, except
	end
end

function createConnection(self, ...)
	local tbl = arg[1]
	tbl.protocolHelper = self.protocolHelper
	return oo.rawnew(PortConnection, tbl)
end
