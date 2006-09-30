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
-- Title  : Method invocation implementation                                  --
-- Authors: Renato Maia           <maia@inf.puc-rio.br>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   call(ref, op, arg)  Performs an operation call on a reference            --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--------------------------------------------------------------------------------

local require = require
local rawget  = rawget
local rawset  = rawset
local ipairs  = ipairs

local table = require "table"

module "oil.invoke"                                                             --[[VERBOSE]] local verbose = require "oil.verbose"

local Exception = require "oil.Exception"
local giop      = require "oil.giop"

--------------------------------------------------------------------------------
-- Local module variables ------------------------------------------------------

local Protocols          = giop.Protocols
local RequestID          = giop.RequestID
local ReplyID            = giop.ReplyID
local LocateReplyID      = giop.ReplyID
local CancelRequestID    = giop.CancelRequestID
local LocateRequestID    = giop.LocateRequestID
local MessageErrorID     = giop.MessageErrorID
local MessageType        = giop.MessageType
local SystemExceptionIDL = giop.SystemExceptionIDL

local Empty = {}

--------------------------------------------------------------------------------
-- Connection management -------------------------------------------------------

local function connect(self)
	local conn, except = rawget(self, "_conn"), rawget(self, "_key")
	if not conn then                                                              --[[VERBOSE]] verbose.invoke "no connection for IOR"
		except = Exception{ "NO_IMPLEMENT", minor_code_value = 0,
			minor_code_value = 3,
			message = "no supported Inter-ORB Protocol profile found",
			reason = "protocol",
		}
		for _, profile in ipairs(self._profiles) do                                 --[[VERBOSE]] verbose.invoke{"got profile with tag ", profile.tag}
			if Protocols[profile.tag] then
				conn = Protocols[profile.tag]                                           --[[VERBOSE]] verbose.invoke({"connect using protocol ", profile.tag}, true)
				conn, except = conn.connect(profile.profile_data)                       --[[VERBOSE]] verbose.invoke()
				if conn then -- was there any errors on connection?
					rawset(self, "_conn", conn)
					rawset(self, "_key", except)
					break
				end                                                                     --[[VERBOSE]] else verbose.invoke{"protocol tag ", profile.tag, " is not supported"}
			end
		end                                                                         --[[VERBOSE]] else verbose.invoke "IOR already provides a connection"
	end  
	return conn, except
end

--------------------------------------------------------------------------------
-- Exception handling ----------------------------------------------------------

local function handleexception(self, exception, operation, args)                --[[VERBOSE]] verbose.invoke{"handling exception ", exception[1]}
	local handler = self._handlers
	if handler then
		handler = handler[ exception[1] ]
		if handler then
			return handler(self, exception, operation, args) -- handle exception
		end
	end
	return nil, Exception(exception) -- raise exception
end

--------------------------------------------------------------------------------
-- Operation call protocol -----------------------------------------------------

local Request = {
	service_context      = Empty,
	request_id           = 0,
	response_expected    = nil, -- defined later
	object_key           = nil, -- defined later
	operation            = nil, -- defined later
	requesting_principal = {},
	-- only GIOP 1.2 and 1.3
	reserved             = "\0\0\0",
}

local function requestid(conn) -- TODO:[maia] avoid overflow. Lua
	local id = conn.newid or 0   --             numbers may not be 
	conn.newid = id + 1          --             problem, but CORBA 
	return id                    --             unsigned long may. 
end

function call(self, operation, args)
	local params = operation.inputs
	local expected = table.getn(params)
	if expected > 0 then
		if table.getn(args) < expected then
			return false, "expected "..expected.." arguments, but got "..
			              table.getn(args)
		end
	end
	local conn, except = connect(self)
	if conn then
		local request_id = requestid(conn)
		Request.request_id        = request_id
		Request.object_key        = except -- object_key at self._profiles
		Request.operation         = operation.name
		Request.response_expected = not operation.oneway                            --[[VERBOSE]] verbose.invoke({"invoke ", operation.name, " [req id: ", Request.request_id, "]"}, true)
		expected, except = conn:send(self, RequestID, Request, params, args)
		if expected then
			if operation.oneway then                                                  --[[VERBOSE]] verbose.invoke "no response expected"
				return Empty                                                            --[[VERBOSE]] , verbose.invoke()
			else
				-- TODO:[maia] add proper support for colaborative multi-threading.
				--             Caution! Avoid any sort of race conditions on the use
				--             of sockets since collaborative multi-threading is used.
				local msgid, header, buffer = conn:receive(self, request_id)            --[[VERBOSE]] verbose.invoke()
				if msgid == ReplyID then                                                --[[VERBOSE]] verbose.invoke "got a reply message"
					local status = header.reply_status
					if status == "NO_EXCEPTION" then                                      --[[VERBOSE]] verbose.invoke({"successfull invokation, return results"}, true)
						expected = { n = table.getn(operation.outputs) }
						for index, output in ipairs(operation.outputs) do
							expected[index] = buffer:get(output)
						end                                                                 --[[VERBOSE]] verbose.invoke()
						return expected
					elseif status == "USER_EXCEPTION" then                                --[[VERBOSE]] verbose.invoke("got use-defined exception", true)
						local repId = buffer:string()                                       --[[VERBOSE]] verbose.invoke()
						local exception = operation.exceptions[repId]
						if exception then
							except = Exception(buffer:except(exception))
						else
							except = Exception{ "UNKNOWN", minor_code_value = 0,
								message = "unexpected user-defined exception, got "..repId,
								reason = "exception",
								exception = exception,
							}
						end
					elseif status == "SYSTEM_EXCEPTION" then                              --[[VERBOSE]] verbose.invoke("got system exception", true)
						local exception = buffer:struct(SystemExceptionIDL)                 --[[VERBOSE]] verbose.invoke()
						-- TODO:[maia] set its type to the proper SystemExcep.
						exception[1] = exception.exception_id
						except = Exception(exception)
					elseif status == "LOCATION_FORWARD" then                              --[[VERBOSE]] verbose.invoke "got location forward notice"
						local ior = buffer:IOR()
						ior._manager = self._manager
						ior._orb = self._orb
						return call(ior, operation, args)
					else
						--TODO:[maia] handle GIOP 1.2 reply status
						except = Exception{ "INTERNAL", minor_code_value = 0,
							message = "unsupported reply status, got "..status,
							reason = "replystatus",
							status = status,
						}
					end
				elseif msgid == CloseConnectionID then                                  --[[VERBOSE]] verbose.invoke "got request to close connection"
					conn:close() -- TODO:[maia] only reissue if not reached some timeout
					return call(self, operation, args)
				elseif msgid == MessageErrorID then                                     --[[VERBOSE]] verbose.invoke "got erro message notice"
					except = Exception{ "COMM_FAILURE", minor_code_value = 0,
						message = "error in server message processing",
						reason = "server",
					}
				elseif MessageType[msgid] then                                          --[[VERBOSE]] verbose.invoke{"got an unexcpected ", MessageType[msgid], " message"}
					except = Exception{ "INTERNAL", minor_code_value = 0,
						message = "unexpected GIOP message, got "..MessageType[msgid],
						reason = "unexpected",
						messageid = msgid,
					}
				else
					except = header
					conn:close()
				end
			end --[[ oneway test ]]                                                   --[[VERBOSE]] else verbose.invoke()
		end -- request sending
	end -- connection test
	return handleexception(self, except, operation, args)
end
