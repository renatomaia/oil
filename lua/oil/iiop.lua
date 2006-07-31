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
-- Interface:                                                                 --
--   Tag              Value of Internet IOP tag                               --
--   decodeurl(url)   Decodes an IIOP URL Object defined by corbaloc format   --
--   connect(profile) Creates a connection object to address in IIOP profile  --
--   listen(args)     Creates a listening port object                         --
--   getport(profile) Return the server port specified by the profile         --
--                                                                            --
-- Connection interface:                                                      --
--   receive(reqid)   Returns a message ID, header and buffer with the data   --
--   send(i,h,t,d)    Sends a message with ID,header,contents types and data  --
--   close()          Closes the connection                                   --
--                                                                            --
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
local next         = next
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

module "oil.iiop"                                                               --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local ObjectCache     = require "loop.collection.ObjectCache"
local OrderedSet      = require "loop.collection.OrderedSet"
local MapWithKeyArray = require "loop.collection.MapWithKeyArray"
local Exception       = require "oil.Exception"
local oo              = require "oil.oo"
local socket          = require "oil.socket"
local IDL             = require "oil.idl"
local assert          = require "oil.assert"
local cdr             = require "oil.cdr"
local ior             = require "oil.ior"
local giop            = require "oil.giop"

local Empty = {}

--------------------------------------------------------------------------------
-- Registration at supported IOP protocol list ---------------------------------

Tag = 0
giop.Protocols[Tag] = _M
ior.URLProtocols[""] = _M
ior.URLProtocols["iiop"] = _M

--------------------------------------------------------------------------------
-- GIOP structures for fast access ---------------------------------------------

local GIOPHeaderSize        = giop.GIOPHeaderSize
local GIOPMagicTag          = giop.GIOPMagicTag
local GIOPHeader_v1_        = giop.GIOPHeader_v1_
local GIOPMessageHeader_v1_ = giop.MessageHeader_v1_

local CloseConnectionID     = giop.CloseConnectionID
local MessageErrorID        = giop.MessageErrorID

--------------------------------------------------------------------------------
-- IIOP IOR profile support ----------------------------------------------------

local TaggedComponentSeq = IDL.sequence{IDL.struct{
	{name = "tag"           , type = IDL.ulong   },
	{name = "component_data", type = IDL.OctetSeq},
}}

local IIOPProfileBody_v1_ = {
	-- Note: First profile structure field is read/write directly
	[0] = IDL.struct{
		--{name = "iiop_version", type = IDL.Version },
		{name = "host"        , type = IDL.string  },
		{name = "port"        , type = IDL.ushort  },
		{name = "object_key"  , type = IDL.OctetSeq},
	},
	[1] = IDL.struct{
		--{name = "iiop_version", type = IDL.Version       },
		{name = "host"        , type = IDL.string        },
		{name = "port"        , type = IDL.ushort        },
		{name = "object_key"  , type = IDL.OctetSeq      },
		{name = "components"  , type = TaggedComponentSeq},
	},
}
IIOPProfileBody_v1_[2] = IIOPProfileBody_v1_[1] -- same as IIOP 1.1
IIOPProfileBody_v1_[3] = IIOPProfileBody_v1_[1] -- same as IIOP 1.1

local function openprofile(profile)                                             --[[VERBOSE]] verbose.connect("open IIOP IOR profile", true)
	local buffer = cdr.ReadBuffer(profile, true)
	local version = buffer:struct(IDL.Version)
	local profileidl = IIOPProfileBody_v1_[version.minor]

	if version.major ~= 1 or not profileidl then
		return nil, Exception{ "INTERNAL", minor_code_value = 0,
			message = "IIOP version not supported, got "..
			          version.major.."."..version.minor,
			reason = "version",
			protocol = "IIOP",
			major = version.major,
			minor = version.minor,
		}
	end

	profile = buffer:struct(profileidl)
	profile.iiop_version = version -- add version read directly

	return profile                                                                --[[VERBOSE]] , verbose.connect()
end

local function createprofile(profile, minor)
	if not minor then minor = 0 end
	local profileidl = IIOPProfileBody_v1_[minor]

	if not profileidl then
		return nil, Exception{ "INTERNAL", minor_code_value = 0,
			message = "IIOP version not supported, got 1."..minor,
			reason = "version",
			protocol = "IIOP",
			major = 1,
			minor = minor,
		}
	end

	if profile.host == "*" then
		profile.host = socket.dns.gethostname()
	end                                                                           --[[VERBOSE]] verbose.ior({"create IIOP IOR profile with version 1.", minor; objectkey = objectkey, host = host, port = port}, true)
	
	local buffer = cdr.WriteBuffer(true)
	buffer:struct({major=1, minor=minor}, IDL.Version)
	buffer:struct(profile, profileidl)                                            --[[VERBOSE]] verbose.ior()
	return {
		tag = Tag,
		profile_data = buffer:getdata(),
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local components = Empty
function decodeurl(data)
	local temp, objectkey = string.match(data, "^([^/]*)/(.*)$")
	if temp
		then data = temp
		else objectkey = "" -- TODO:[maia] is this correct?
	end
	local major, minor
	major, minor, temp = string.match(data, "^(%d+).(%d+)@(.+)$")
	if major and major ~= "1" then
		return nil, Exception{ "INTERNAL", minor_code_value = 0,
			message = "IIOP version not supported, got "..major.."."..minor,
			reason = "version",
			protocol = "IIOP",
			major = major,
			minor = minor,
		}
	end
	if temp then data = temp end
	local host, port = string.match(data, "^([^:]+):(%d*)$")
	if port then
		port = tonumber(port)
	else
		port = 2809
		if data == ""
			then host = "*"
			else host = data
		end
	end                                                                           --[[VERBOSE]] verbose.ior{"got host ", host, ":", port, " and object key '", objectkey, "'"}
	return createprofile({
			host = host,
			port = port,
			object_key = objectkey,
			components = components,
		},
		tonumber(minor)
	)
end

--------------------------------------------------------------------------------
-- Client connection management ------------------------------------------------

local function newsocket(host, port)
	local conn, except = socket.tcp()                                             --[[VERBOSE]] verbose.connect "new socket for connection"
	if conn then
		local success
		success, except = conn:connect(host, port)                                  --[[VERBOSE]] verbose.connect{"connect socket to ", host, ":", port, ", error: ", except, "]"}
		if not success then
			conn, except = nil, Exception{ "COMM_FAILURE", minor_code_value = 0,
				message = "unable to connect to "..host..":"..port,
				reason = "connect",
				error = except,
				host = host, 
				port = port,
			}
		end
	else
		except = Exception{ "NO_RESOURCES", minor_code_value = 0,
			message = "unable to create new socket",
			reason = "socket",
			error = except,
		}
	end                                                                       
	return conn, except
end

--------------------------------------------------------------------------------

local ConnectionCache = ObjectCache{}
function ConnectionCache:retrieve()
	return setmetatable({}, {__mode = "v"})
end

local Connection = oo.class()

function Connection:__init(conn)
	conn.replies = {}
	conn.receivers = {}
	conn.senders = OrderedSet()
	return oo.rawnew(self, conn)
end

function Connection:close()
	self.socket:close()                                                           --[[VERBOSE]] verbose.close "connection socket closed"
end

function connect(profile)                                                       --[[VERBOSE]] verbose.connect("attempt to create new connection", true)
	local profile = openprofile(profile)
	local host, port = profile.host, profile.port
	local conn, except = ConnectionCache[host][port]
	if not conn then                                                              --[[VERBOSE]] verbose.connect{"creating new connection to ", host, ":", port}
		conn, except = newsocket(host, port)
		if conn then
			conn = Connection{
				socket = conn,
				host   = host,
				port   = port,
			}
			ConnectionCache[host][port] = conn
		end
	end                                                                           --[[VERBOSE]] verbose.connect()
	return conn, except or profile.object_key
end

--------------------------------------------------------------------------------
-- Transport layer -------------------------------------------------------------

local function receivefrom(self, object)
	local socket = self.socket
	
	local stream, except = socket:receive(GIOPHeaderSize)                         --[[VERBOSE]] verbose.receive({"read GIOP header from socket [error: ", except, "]"}, true)
	if not stream then
		if except == "closed" then self:close() end         
		return nil, Exception{ "COMM_FAILURE", minor_code_value = 0,
			message = "unable to read from socket",
			reason = except,
			socket = socket,
		}                                                                           --[[VERBOSE]] , verbose.gotMsg()
	end
	
	local buffer = cdr.ReadBuffer(stream, false, object)
	
	--
	-- Read GIOP message header
	--
	local header = GIOPHeader_v1_[0] -- use GIOP 1.0 by default
	
	local magic = buffer:array(header[1].type)
	if magic ~= GIOPMagicTag then
		-- TODO:[maia] raise MARSHAL exception with minor code 8
		return nil, Exception{ "MARSHALL", minor_code_value = 8,
			message = "ilegal GIOP message, magic number is "..magic,
			reason = "magictag",
			tag = magic,
		}                                                                           --[[VERBOSE]] , verbose.gotMsg(magic, nil, nil, nil, nil, stream)
	end
	
	local version = buffer:struct(header[2].type)
	local major, minor = version.major, version.minor
	header = GIOPMessageHeader_v1_[minor]
	if major ~= 1 or not header then
		return nil, Exception{ "INTERNAL", minor_code_value = 0,
			message = "GIOP version not supported, got "..major.."."..minor,
			reason = "version",
			procotol = "GIOP",
			major = major,
			minor = minor,
		}                                                                           --[[VERBOSE]] , verbose.gotMsg(magic, version, nil, nil, nil, stream)
	end
	
	local order
	if minor == 0
		then order = buffer:boolean()
		else assert.error "Oops! Missing code ;-)" -- TODO:[maia] handle flags of GIOP 1.1
	end
	buffer:order(order)
	
	local type = buffer:octet()
	local size = buffer:ulong()
	
	--
	-- Read GIOP message body
	--
	header = GIOPMessageHeader_v1_[minor][type]
	if header == nil then
		return nil, Exception{ "INTERNAL", minor_code_value = 0,
			message = "GIOP 1."..minor.." message type not supported, got "..type,
			reason = "messageid",
			major = major,
			minor = minor,
			messageid = type,
		}                                                                           --[[VERBOSE]] , verbose.gotMsg(magic, version, order, type, size, stream)
	end
	
	if header then                                                                --[[VERBOSE]] verbose.receive()
		stream, except = socket:receive(size)                                       --[[VERBOSE]] verbose.receive({"read GIOP body from socket [error: ", except, "]"}, true)
		if not stream then
			if except == "closed" then self:close() end
			return nil, Exception{ "COMM_FAILURE", minor_code_value = 0,
				message = "unable to read from socket",
				reason = except,
				socket = socket,
			}                                                                         --[[VERBOSE]] , verbose.gotMsg(magic, version, order, type, size, stream)
		end
		
		buffer.data = buffer.data..stream
		
		header = buffer:struct(header)
	end
	
	return type, header, buffer                                                   --[[VERBOSE]] , verbose.gotMsg(magic, version, order, type, size, stream)
end

function Connection:receive(object, request_id)
	local replies = self.replies
	
	local reply = replies[request_id]
	if reply then                                                                 --[[VERBOSE]] verbose.receive "returning stored reply"
		replies[request_id] = nil
		return unpack(reply)
	end

	local message, header, buffer

	if self.receiving then                                                        --[[VERBOSE]] verbose.receive("connection already being read, waiting notification", true)
		self.receivers[request_id] = scheduler.current()
		message, header, buffer = scheduler.sleep()                                 --[[VERBOSE]] verbose.receive "notification received"
		self.receivers[request_id] = nil
		if message then                                                             --[[VERBOSE]] verbose.receive "got reply from notification, returning message"
			return message, header, buffer                                            --[[VERBOSE]] , verbose.receive() else verbose.receive()
		end
	else                                                                          --[[VERBOSE]] verbose.receive "connection free for reading"
		self.receiving = true
	end
	
	repeat                                                                        --[[VERBOSE]] verbose.receive("reading message from socket", true)
		message, header, buffer = receivefrom(self, object)                         --[[VERBOSE]] verbose.receive()

		if
			message == nil or
			message == MessageErrorID or
			message == CloseConnectionID
		then                                                                        --[[VERBOSE]] verbose.receive("not received a reply", true)
			local package = { message, header, buffer, n=3 }
			local routine
			local receivers = self.receivers
			while next(receivers) do                                                  --[[VERBOSE]] verbose.receive "notifying other handlers of the received data"
				request_id, routine = next(receivers)
				replies[request_id] = package
				receivers[request_id] = nil
				scheduler.wake(routine)
			end
			self:close()                                                              --[[VERBOSE]] verbose.receive()
			break
		end

		if header.request_id ~= request_id then                                     --[[VERBOSE]] verbose.receive "got reply for another request"
			local routine = self.receivers[header.request_id]
			if routine then                                                           --[[VERBOSE]] verbose.receive("waking thread registed for the reply", true)
				scheduler.wake(routine)                                                 --[[VERBOSE]] verbose.receive()
				coroutine.yield(message, header, buffer)
			else                                                                      --[[VERBOSE]] verbose.receive "storing reply for other threads"
				replies[header.request_id] = { message, header, buffer, n=3 }
			end
			message, header, buffer = nil, nil, nil
		end
	until message
	
	request_id, reply = next(self.receivers)
	if reply
		then scheduler.wake(reply)                                                  --[[VERBOSE]] verbose.receive "thread waken for reading from socket"
		else self.receiving = false                                                 --[[VERBOSE]] verbose.receive "freeing socket for other threads"
	end
	
	return message, header, buffer
end

--------------------------------------------------------------------------------

local DefaultGIOPHeader = {
	magic        = GIOPMagicTag,
	GIOP_version = {major=1, minor=0},
	byte_order   = cdr.NativeEndianess,
	message_type = 0, -- Request message
	message_size = 0,
}

function Connection:send(object, message, header, bodyidl, body, orb)           --[[VERBOSE]] local VERBOSE_header, VERBOSE_body = header, body
	local minor = 0 -- default GIOP version for sending messages
	
	--
	-- Create GIOP message body
	--
	local headeridl = GIOPMessageHeader_v1_[minor or 0][message]                  --[[VERBOSE]] verbose.newMsg(message, minor)

	local buffer = cdr.WriteBuffer(false, object)
	buffer:shift(GIOPHeaderSize) -- alignment accordingly to GIOP header size
	
	if headeridl then buffer:put(header, headeridl) end
	if bodyidl then
		buffer.orb = orb
		for index, idltype in ipairs(bodyidl) do
			buffer:put(body[index], idltype)
		end
	end
	
	body = buffer:getdata()                                                       --[[VERBOSE]] verbose.send()
	
	--
	-- Create GIOP message header
	--
	DefaultGIOPHeader.GIOP_version.minor = minor
	DefaultGIOPHeader.message_size = string.len(body)
	DefaultGIOPHeader.message_type = message
	buffer = cdr.WriteBuffer()                                                    --[[VERBOSE]] verbose.newHead(DefaultGIOPHeader, VERBOSE_header, VERBOSE_body)
	buffer:struct(DefaultGIOPHeader, GIOPHeader_v1_[minor])
	header = buffer:getdata()                                                     --[[VERBOSE]] verbose.send()
	
	body = header..body
	
	--
	-- Test for mutual exclusion on socket access
	--
	if self.sending then                                                          --[[VERBOSE]] verbose.send("connection already being written, waiting notification", true)
		self.senders:enqueue(scheduler:current())
		scheduler.sleep()                                                           --[[VERBOSE]] verbose.send "notification received" verbose.send()
	else                                                                          --[[VERBOSE]] verbose.send "connection free for writting"
		self.sending = true
	end
	
	--
	-- Send data stream over the socket
	--
	local failures, success, except = 0                                           --[[VERBOSE]] verbose.send("writing message into socket", true)
	repeat
		success, except = self.socket:send(body)                                    --[[VERBOSE]] verbose.send{"write GIOP message into socket [error: ", except, "]"}
		if not success then
			if except == "closed" and self.host and failures < 1 then                 --[[VERBOSE]] verbose.send({"attempt to reconnect to ", self.host, ":", self.port}, true)
				failures = failures + 1
				success, except = newsocket(self.host, self.port)
				if success
					then success, self.socket = false, success
					else self:close()
				end                                                                     --[[VERBOSE]] verbose.send()
			else
				except = Exception{ "COMM_FAILURE", minor_code_value = 0,
					message = "unable to write into socket",
					reason = except,
					socket = socket,
				}
			end
		end
	until success or except                                                       --[[VERBOSE]] verbose.send()

	--
	-- Wake blocked threads
	--
	if self.senders:empty()
		then self.sending = false                                                   --[[VERBOSE]] verbose.send "freeing socket for other threads"
		else scheduler.wake(self.senders:dequeue())                                 --[[VERBOSE]] verbose.send "thread waken for writting into socket"
	end
	
	return success, except
end

--------------------------------------------------------------------------------
-- Server connection management ------------------------------------------------

local PortConnection = oo.class({}, Connection)

function PortConnection:__init(conn)
	conn.senders = OrderedSet()
	return oo.rawnew(self, conn)
end

function PortConnection:close()
	-- test whether still active
	if self.port.connections:remove(self.socket) then                             --[[VERBOSE]] verbose.close "connection unregistered" verbose.close("send close connection message", true)
		return self:send(CloseConnectionID)                                         --[[VERBOSE]] , verbose.close()
	end
end

PortConnection.receive = receivefrom

--------------------------------------------------------------------------------

local Port = oo.class()
local PortCache = ObjectCache{ retrieve = ConnectionCache.retrieve }

local PortLowerBound = 2809 -- inclusive (never at first attempt)
local PortUpperBound = 9999 -- inclusive

local function bind(host, port)
	local sock, err = socket.tcp()                                                --[[VERBOSE]] verbose.listen{"new socket for port, error: ", err}
	if not sock then return nil, err, "socket" end
	local res, err = sock:bind(host, port)                                        --[[VERBOSE]] verbose.listen{"bind to address ", host, ":", port, ", error: ", err}
	if not res then return nil, err, "address" end
	res, err = sock:listen()                                                      --[[VERBOSE]] verbose.listen{"listen to address ", host, ":", port, ", error: ", err}
	if not res then return nil, err, "address" end
	return sock
end

math.randomseed(socket.gettime() * 1000)
function listen(args)
	local host = args.host or "*"
	local port = args.port
	local conn, except, reason
	if not port then
		local start = PortLowerBound + math.random(PortUpperBound - PortLowerBound)
		port = start
		repeat
			conn, except, reason = bind(host, port)
			if conn then break end
			if port >= PortUpperBound
				then port = PortLowerBound
				else port = port + 1
			end
		until port == start
	else
		conn, except, reason = bind(host, port)
	end
	if conn then
		conn = Port{
			socket = conn,
			host = host,
			port = port,
			iorhost = args.iorhost,
			iorport = args.iorport,
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

function Port:__init(port)
	port.ready = OrderedSet() -- queue of ready connections
	port.connections = MapWithKeyArray()
	port.connections:add(port.socket) -- first connection will always be the port

	PortCache[port.host][port.port] = port
	if port.iorhost or port.iorport then
		PortCache[port.iorhost or port.host][port.iorport or port.port] = port
	end
	return oo.rawnew(self, port)
end

function Port:waitformore(timeout)
	local ready = self.ready
	if self.ready:empty() then
		local connections = self.connections
		local attempts = 0 -- how much attempts to select a socket?
		local giveup = false
		repeat
			attempts = attempts + connections:size()                                  --[[VERBOSE]] verbose.listen{"waiting messages or more connections (", connections:size() - 1, ") [timeout: ", timeout, "]"}
			local selected = socket.select(connections, Empty, timeout)
			local port = self.socket
			if selected[port] then                                                    --[[VERBOSE]] verbose.listen "new connection accepted"
				selected[port] = nil
				local conn = PortConnection{
					pending = {},
					socket = port:accept(),
					port = self,
				}
				connections:add(conn.socket, conn)
			end
			for sock in pairs(selected) do
				if type(sock) ~= "number" then                                          --[[VERBOSE]] verbose.listen "got new message"
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
					giveup = true                                                         --[[VERBOSE]] else verbose.listen "repeating selection for new connections"
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

--------------------------------------------------------------------------------

if scheduler then
	
	local FreeHandlers = {}
	
	local function cohandler(broker, conn, message, header, buffer)
		local success, except
		repeat                                                                      --[[VERBOSE]] verbose.receive("starting handling of received request", true)
			success, except = broker:handle(conn, message, header, buffer)            --[[VERBOSE]] verbose.receive()
			if not success then                                                       --[[VERBOSE]] verbose.receive "error in handling of received request"
				io.stderr:write(tostring(except), "\n")
			end                                                                       --[[VERBOSE]] verbose.receive "handler free for other requests"
			table.insert(FreeHandlers, scheduler.current())
			broker, conn, message, header, buffer = scheduler.sleep()
		until not conn
		return success, except
	end
	
	local function reader(broker, conn)
		local message, header, buffer, thread
		repeat                                                                      --[[VERBOSE]] verbose.receive("receive new request", true)
			message, header, buffer = conn:receive(broker)                            --[[VERBOSE]] verbose.receive()
			thread = table.remove(FreeHandlers)
			if not thread then                                                        --[[VERBOSE]] verbose.receive "creating new concurrent handler for the request"
				scheduler.new(cohandler, broker, conn, message, header, buffer)
			else                                                                      --[[VERBOSE]] verbose.receive "reusing concurrent handler for the request"
				scheduler.wake(thread)
				coroutine.yield(broker, conn, message, header, buffer)
			end
		until not message
	end
	
	function Port:accept(broker)
		local conn = self.ready:dequeue()
		if not conn then                                                            --[[VERBOSE]] verbose.listen("no message, waiting for more", true)
			if self:waitformore() then
				conn = self.ready:dequeue()
			end                                                                       --[[VERBOSE]] verbose.listen() else verbose.listen "message already queued"
		end                                                                         --[[VERBOSE]] verbose.receive("receive new request", true)
		scheduler.new(broker.handle, broker, conn, conn:receive(broker))            --[[VERBOSE]] verbose.receive()
	end

	function Port:acceptall(broker)
		while not self.ready:empty() do
			scheduler.new(reader, broker, self.ready:dequeue())
		end
		repeat
			conn = PortConnection{
				pending = {},
				socket = self.socket:accept(),
				port = self,
			}
		until not scheduler.new(reader, broker, conn)
	end

else

	function Port:accept(broker)
		local conn = self.ready:dequeue()
		if not conn then                                                            --[[VERBOSE]] verbose.listen("no message, waiting for more", true)
			if self:waitformore() then
				conn = self.ready:dequeue()
			end                                                                       --[[VERBOSE]] verbose.listen() else verbose.listen "message already queued"
		end
		return broker:handle(conn, conn:receive(broker))
	end

	function Port:acceptall(broker)
		local success, errmsg
		repeat
			success, errmsg = self:accept(broker)
		until not success
		return success, errmsg
	end
	
end

--------------------------------------------------------------------------------

function Port:profile(objectkey)
	return createprofile{
		host = self.iorhost or self.host,
		port = self.iorport or self.port,
		object_key = objectkey,
	}
end

function getport(profile)
	profile = openprofile(profile)
	local ports = rawget(PortCache, profile.host) or rawget(PortCache, "*")
	if ports then
		return ports[profile.port], profile.object_key
	end
end
