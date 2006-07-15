
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

module "oil.dummy.Protocol"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"

local Exception = require "oil.Exception"
local MapWithArrayOfKeys = require "loop.collection.MapWithArrayOfKeys"
local OrderedSet         = require "loop.collection.OrderedSet"

local Empty = {}

local Connection = oo.class()

function Connection:__init(socket)
	self.replies = {}
	self.receivers = {}
	self.senders = OrderedSet()
	self.socket = socket
	return oo.rawnew(self)
end

function Connection:close()
	self.socket:close()                                                           --[[VERBOSE]] verbose:close "connection socket closed"
end

function Connection:receive()
	local msg, except = self.socket:receive("*a")                                 --[[VERBOSE]] verbose:receive(true, "read message from socket [error: ", except, "]")
	return msg, except                                                   
end

function Connection:send(stream)           
	local	success, except = self.socket:send(stream)                              --[[VERBOSE]] verbose:send("write message into socket [error: ", except, "]")
	return success, except
end

--------------------------------------------------------------------------------
-- Client helper functions
--------------------------------------------------------------------------------

local DefaultHeader = {
	message_type = 0, -- Request message
	message_size = 0,
}

local function createMessage(self, object_key, operation,  ...)
	local buffer = self.codec:newEncoder()

	buffer:put(object_key)
	buffer:put(operation)
  for i, param in ipairs(arg) do
		buffer:put(param)
	end

	return buffer:getdata()
end

local function openMessage(self, msgstr)
  local msg
	return msg
end
--------------------------------------------------------------------------------
-- Reply object implementation
--------------------------------------------------------------------------------

ReplyObject = oo.class{}

--------------------------------------------------------------------------------
-- Client functions
--------------------------------------------------------------------------------

InvokeProtocol = oo.class{}

function InvokeProtocol:sendrequest(reference, operation, ...)
	local socket, except = self.channels:create(reference.host, reference.port)
  local conn = Connection(socket)
	if conn then
		
		local stream = createMessage(self, reference.object_key, operation, ... )
		print(stream)
		expected, except = conn:send( stream )
    local reply_object = ReplyObject { result = function()

			local msgtype, header, buffer = conn:receive()                                  
		 	return msgtype, header, buffer
		 end }
		return response
	end -- connection test
	return handleexception(self, except, operation, ...)
end

--------------------------------------------------------------------------------
-- Server functions
--------------------------------------------------------------------------------

ListenProtocol = oo.class{}

local Reply = {
	request_id      = nil, -- defined later
	reply_status    = "NO_EXCEPTION",
}

ResultObject = oo.class{}
function ResultObject:__init(object_key, operation, params)
	self.object_key = object_key
	self.operation = operation
	self.params = params
  return oo.rawnew(self)
end

function ListenProtocol:getrequest(conn)
	local except
	local msg = conn:receive()
	if msg then
		print(msg)
		local resultObject = ResultObject(msg.object_key, msg.operation, msg.params)
		resultObject.result = function(success, result)
    	if success then
      	local stream = createMessage(self, result)
				_,except = conn:send(stream)
			end
		end
    return resultObject
	end
end

local PortLowerBound = 3000 -- inclusive (never at first attempt)
local PortUpperBound = 9999 -- inclusive

function ListenProtocol:getchannel(args)
	local host, port
	host = "*"
	port = args.port
	local conn, except
	if not port then
		local start = PortLowerBound
		port = start
		repeat
			conn, except = self.channels:create(host, port)
			if conn then break end
			if port >= PortUpperBound
				then port = PortLowerBound
				else port = port + 1
			end
		until port == start
	else
		conn, except = self.channels:create(host, port)
	end
	--args.host = conn.host
	--args.port = port
	local portConnection = Connection(conn)
	if not except then
		
	else 
		-- TODO:[nogara] treat this exception, in case the listen didn't went through
	end

	return portConnection, except
end

