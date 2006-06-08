
local require     = require
local rawget      = rawget
local rawset      = rawset
local ipairs      = ipairs
local select      = select
local scheduler   = scheduler
local print       = print
local tostring    = tostring
local string      = string
local pairs       = pairs
local unpack      = unpack

local table = require "table"
local oo        = require "oil.oo"

module ("oil.dummy.Protocol", oo.class)                                         

local Exception = require "oil.Exception"
local MapWithArrayOfKeys = require "loop.collection.MapWithArrayOfKeys"
local OrderedSet         = require "loop.collection.OrderedSet"

local Empty = {}

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
	local msg, except = self.socket:receive("*a")                                 --[[VERBOSE]] verbose:receive(true, "read GIOP header from socket [error: ", except, "]")
	return msg, except                                                   
end

function Connection:send(stream)           
	local	success, except = self.socket:send(stream)                              --[[VERBOSE]] verbose:send("write GIOP message into socket [error: ", except, "]")
	return success, except
end

--------------------------------------------------------------------------------
-- Client helper functions
--------------------------------------------------------------------------------

local Request = {
	object_key           = nil, -- defined later
	operation            = nil, -- defined later
}

local DefaultHeader = {
	message_type = 0, -- Request message
	message_size = 0,
}

local function createMessage(self, message,  ...)
	local buffer = self.codec:newEncoder(false, self)
		
	if headeridl then buffer:put(header, headeridl) end
	body = buffer:getdata()                                                       
	
	--
	-- Create message header
	--
	DefaultHeader.message_type = message
	buffer = self.codec:newEncoder()                                              
	header = buffer:getdata()                                                     
	
	return body

end

--------------------------------------------------------------------------------
-- Client functions
--------------------------------------------------------------------------------

function call(self, reference, operation, ...)
	conn, except = connect(reference)

	if conn then
		Request.object_key        = except 
		Request.operation         = operation
		
		local stream = createMessage(self, Request, params, ... )

		expected, except = conn:send( stream )

		msgtype, header, buffer = conn:receive()                                  
				
		return response
	end -- connection test
	return handleexception(self, except, operation, ...)
end

--------------------------------------------------------------------------------
-- Server functions
--------------------------------------------------------------------------------

local Reply = {
	request_id      = nil, -- defined later
	reply_status    = "NO_EXCEPTION",
}

function handle(self, dispatcher, conn)
	local except
	local msg_buffer = conn:receive()
	if msgtype == RequestID then
    local object = dispatcher:getobject(header.object_key)
    local iface = object._iface
    local servant = object._servant
    if iface then 
      local success, result = dispatcher:handle(header.object_key, header.operation, params )
      Reply.request_id = requestid
      Reply.reply_status = "NO_EXCEPTION"
      local stream = createMessage(self, ReplyID, Reply,
                            member.outputs, unpack(result))
      _, except = conn:send(stream)                   
    else 
    end
    conn.pending[requestid] = nil
	else
		if header.reason ~= "closed" then
			except = header                                                           
		end
		conn:close()
	end
	return except == nil, except
end


local PortLowerBound = 3000 -- inclusive (never at first attempt)
local PortUpperBound = 9999 -- inclusive

function listen(self, args)
	local host = args.host or "*"
	local port = args.port
	local conn, except, reason
	if not port then
		local start = PortLowerBound
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
	return self.iop:createConnection(...)
end

function connect(self, reference)                                               
	local socket, except = self.channelFactory:connect(reference)
	-- if conn is not null, second return parameter is the object key of 
	--   the reference
	local conn = Connection{}
	conn.socket = socket
	return conn, except 
end

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

function Port:accept(dispatcher)
	local conn = self.ready:dequeue()
	if not conn then                                                              --[[VERBOSE]] verbose:listen(true, "no message, waiting for more")
		if self:waitformore() then
			conn = self.ready:dequeue()
		end                                                                         --[[VERBOSE]] verbose:listen(false) else verbose:listen "message already queued"
	end
	return self.protocol:handle(dispatcher, conn)
end

function Port:acceptall(dispatcher)
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
