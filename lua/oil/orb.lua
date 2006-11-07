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
-- Title  : Object Request Broker (ORB) basic functions                       --
-- Authors: Renato Maia           <maia@inf.puc-rio.br>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   init(configs)         Creates an ORB object with configs values          --
--                                                                            --
-- ORB interface:                                                             --
--   object(serv,iface,id) Returns the CORBA object implemented by serv object--
--   workpending()         Checks if there is work pending to be processed    --
--   performwork()         Process one request to the ORB                     --
--   run()                 Start processing of all requests to the ORB        --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--------------------------------------------------------------------------------

local type         = type
local ipairs       = ipairs
local rawset       = rawset
local tostring     = tostring
local require      = require
local unpack       = unpack
local rawget       = rawget
local getmetatable = getmetatable

local string = require "string"
local table  = require "table"

local pcall = scheduler and scheduler.pcall or pcall

module "oil.orb"                                                                --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local ObjectCache = require "loop.collection.ObjectCache"
local Exception   = require "oil.Exception"
local oo          = require "oil.oo"
local assert      = require "oil.assert"
local IDL         = require "oil.idl"
local ior         = require "oil.ior"
local giop        = require "oil.giop"

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
--------------------------------------------------------------------------------

local function isbaseof(baseid, iface)
	if iface.is_a then                                                            --[[VERBOSE]] verbose.servant("executing interface is_a operation", true)
		return iface:is_a(baseid)                                                   --[[VERBOSE]] , verbose.servant()
	end                                                                           --[[VERBOSE]] verbose.servant({"checking if ", baseid, " is base of ", iface.repID}, true)
	
	local data = { iface }
	while table.getn(data) > 0 do
		iface = table.remove(data)
		if not data[iface] then                                                     --[[VERBOSE]] verbose.servant{"reached interface ", iface.repID}
			data[iface] = true
			if iface.repID == baseid then
				return true                                                             --[[VERBOSE]] , verbose.servant()
			end
			for _, base in ipairs(iface.base_interfaces) do
				table.insert(data, base)
			end
		end
	end                                                                           --[[VERBOSE]] verbose.servant()
	
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local ObjectOps = giop.ObjectOperations

Object = oo.class()

-- TODO:[maia] add basic operations for servants

function Object:_ior()                                                          --[[VERBOSE]] verbose.servant("getting servant IOR", true)
	return ior.encode(self)                                                       --[[VERBOSE]] , verbose.servant()
end

function Object:_is_a(repID)                                                    --[[VERBOSE]] verbose.servant({"verifying if object interface ", self._iface.repID, " is a ", repID}, true)
	return isbaseof(repID, self._iface)                                           --[[VERBOSE]] , verbose.servant()
end

function Object:_interface()                                                    --[[VERBOSE]] verbose.servant "retrieveing object interface"
	local iface = self._iface
	if getmetatable(iface)
		then return iface
		else assert.raise{ "INTF_REPOS", minor_code_value = 1,
			reason = "interface",
			iface = iface,
		}
	end
end

function Object:_component()                                                    --[[VERBOSE]] verbose.servant "retrieveing component the object belongs to"
	return nil
end

function Object:_non_existent()                                                 --[[VERBOSE]] verbose.servant "probing for object existency, returning false"
	return false
end

function Object:_deactivate()
	if self._orb then
		self._orb.map[self._objectid] = nil
		self._objectid = nil
		self._orb = nil
	else
		assert.raise{ "ObjectNotActive",
			reason = "deactivate",
			servant = self._servant,
			object = self,
		}
	end
end

function Object:__index(field)
	local value = self._servant[field]
	if value == nil then value = Object[field] end
	return value
end

function Object:__newindex(field, value)
	self._servant[field] = value
end

--------------------------------------------------------------------------------
-- Broker initialization -------------------------------------------------------

local Broker = oo.class()

function Broker:__init(port, manager)
	local broker = {
		map = {},
		port = port,
		manager = manager,
	}
	broker._manager = broker
	broker._orb = broker
	return oo.rawnew(self, broker)
end

--------------------------------------------------------------------------------
-- Servant management ----------------------------------------------------------

local function getobjectid(object)
	local meta = getmetatable(object)
	local backup
	if meta then
		backup = rawget(meta, "__tostring")
		if backup ~= nil then rawset(meta, "__tostring", nil) end
	end
	local id = string.match(tostring(object), "%l+: (%w+)")
	if meta then
		if backup ~= nil then rawset(meta, "__tostring", backup) end
	end
	return id
end

function Broker:object(servant, interface, objid)
	if self.manager then
		if type(interface) == "string" then
			local iface = self.manager:getiface(interface)
			if iface
				then interface = iface
				else assert.ilegal(interface, "interface, unable to get definition")
			end
		else
			interface = self.manager:putiface(interface)
		end
	else
		assert.type(interface, "idlinterface", "object interface")
	end
	if objid == nil
		then objid = getobjectid(servant)
		else assert.type(objid, "string", "object ID")
	end
	local object = self.map[objid]
	if object then                                                                --[[VERBOSE]] verbose.servant("servant already is registered", true)
		-- TODO:[maia] is it really good to allow an object to change its interface
		--             to a more especialized one? This was used to allow implicit
		--             created servants previously exported with a base interface to
		--             change to the actual interface. However this is now resolved
		--             by the '__idltype' meta-field.
		if object._type_id ~= interface.repID then
			if isbaseof(object._type_id, interface) then                              --[[VERBOSE]] verbose.servant "changing actual object interface to a narrowed interface"
				object._iface = interface
				object._type_id = interface.repID
			elseif not isbaseof(interface.repID, object._iface) then
				assert.ilegal(interface.repID, "attempt to change object interface")    --[[VERBOSE]] else verbose.servant "attempt to change object interface for a broader interface, no action done"
			end                                                                       --[[VERBOSE]] else verbose.servant "object is exported with same interface as before"
		end                                                                         --[[VERBOSE]] verbose.servant()
	else                                                                          --[[VERBOSE]] verbose.servant({"new object with id ", objid, " [iface: ", interface.repID, "]"}, true)
		object = Object{
			_orb = self,
			_servant = servant,
			_iface = interface,
			_objectid = objid,
			-- IOR
			_type_id = interface.repID,
			_profiles = {self.port:profile(objid)},
		}
		self.map[objid] = object                                                    --[[VERBOSE]] verbose.servant()
	end
	return object
end

function Broker:resolve(ior, iface)                                             --[[VERBOSE]] verbose.servant("resolving IOR to servant", true)
	for tag, profile in ipairs(ior._profiles) do
		local port, key = Protocols[profile.tag]
		if port then
			port, key = port.getport(profile.profile_data)
			if port then
				if port == self.port then                                               --[[VERBOSE]] verbose.servant "servant colocated at same ORB"
					return self.map[key]._servant                                         --[[VERBOSE]] , verbose.servant()
				end                                                                     --[[VERBOSE]] verbose.servant "servant colocated at other ORB"
				break
			end
		end
	end                                                                           --[[VERBOSE]] verbose.servant()
	if self.manager then
		local object = self.manager:resolve(ior, iface)
		object._orb = self
		return object
	else
		return ior
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local COMPLETED_YES   = 0
local COMPLETED_NO    = 1
local COMPLETED_MAYBE = 2

local Reply = {
	service_context = Empty,
	request_id      = nil, -- defined later
	reply_status    = "NO_EXCEPTION",
}
local LocateReply = {
	request_id      = nil, -- defined later
	locate_status   = "OBJECT_HERE",
}
local SystemExceptionReply = {
	service_context = Empty,
	request_id      = nil, -- defined later
	reply_status    = "SYSTEM_EXCEPTION",
}

local function packpcall(success, ...)
	if success
		then return success, arg
		else return success, arg[1]
	end
end

local function dispatch(servant, method, params)
	return packpcall(pcall(method, servant, unpack(params)))
end

function Broker:sendsysex(conn, requestid, body)                                --[[VERBOSE]] verbose.broker({"send System Exception ", body[1],  " for request ", requestid}, true)
	SystemExceptionReply.request_id = requestid
	body.exception_id = giop.SystemExceptionIDs[ body[1] ]
	return conn:send(self, ReplyID, SystemExceptionReply,
	                 {SystemExceptionIDL}, {body})
end

local ReturnTrue = { true }
function Broker:handle(conn, msgid, header, buffer)
	local except
	if msgid == RequestID then
		local requestid = header.request_id                                         --[[VERBOSE]] verbose.broker{"got request with ID ", requestid, " for object ", header.object_key }
		if conn.pending[requestid] == nil then
			conn.pending[requestid] = true
			local object = self.map[header.object_key]
			if object then
				local operation = header.operation                                      --[[VERBOSE]] verbose.broker{"object found, invoking operation ", operation}
				local servant = object._servant
				local member = object._iface.members[operation]
				if not member and ObjectOps[operation] then                             --[[VERBOSE]] verbose.broker{"object basic operation ", operation, " called"}
					member, servant = ObjectOps[operation], object
				end
				if member then                                                          --[[VERBOSE]] verbose.broker{"operation definition found [name: ", operation, "]"}
					local method = servant[operation]
					if method then                                                        --[[VERBOSE]] verbose.broker{"operation implementation found [name: ", operation, "]"} verbose.broker("get parameter values", true)
						local params = { n = table.getn(member.inputs) }
						for index, input in ipairs(member.inputs) do
							params[index] = buffer:get(input)
						end                                                                 --[[VERBOSE]] verbose.broker() verbose.broker({"dispach operation ", operation}, true)
						local success, result = dispatch(servant, method, params)           --[[VERBOSE]] verbose.broker()
						if conn.pending[requestid] and header.response_expected then
							if success then                                                   --[[VERBOSE]] verbose.broker({"send reply for request ", requestid}, true)
								Reply.request_id = requestid
								Reply.reply_status = "NO_EXCEPTION"
								_, except = conn:send(self, ReplyID, Reply,
								                      member.outputs, result)                   --[[VERBOSE]] verbose.broker()
							elseif type(result) == "table" then
								local excepttype = member.exceptions[ result[1] ]
								if excepttype then                                              --[[VERBOSE]] verbose.broker({"send raised exception ", result.repID}, true)
									Reply.request_id = requestid
									Reply.reply_status = "USER_EXCEPTION"
									_, except = conn:send(self, ReplyID, Reply,
									                     {IDL.string, excepttype},
									                     {result[1], result})                     --[[VERBOSE]] verbose.broker()
								elseif giop.SystemExceptionIDs[ result[1] ] then
									result.completion_status = COMPLETED_MAYBE
									_, except = self:sendsysex(conn, requestid, result)           --[[VERBOSE]] verbose.broker()
								else                                                            --[[VERBOSE]] verbose.broker{"unexcepted exception rep. id: ", result[1]}
									except = Exception{ "UNKNOWN", minor_code_value = 0,
										completion_status = COMPLETED_MAYBE,
										message = "unexpected exception raised",
										reason = "exceptionid",
										exception = result,
									}
									self:sendsysex(conn, requestid, except)
								end
							elseif type(result) == "string" then                              --[[VERBOSE]] verbose.broker{"unknown error in dispach, got ", result}
								except = Exception{ "UNKNOWN", minor_code_value = 0,
									completion_status = COMPLETED_MAYBE,
									message = "servant error: "..result,
									reason = "servant",
									operation = operation,
									servant = servant,
									error = result,
								}
								self:sendsysex(conn, requestid, except)
							else                                                              --[[VERBOSE]] verbose.broker{"ilegal error type, got ", type(result)}
								except = Exception{ "UNKNOWN", minor_code_value = 0,
									completion_status = COMPLETED_MAYBE,
									message = "invalid exception, got "..type(result),
									reason = "exception",
									exception = result,
								}
								self:sendsysex(conn, requestid, except)
							end                                                               --[[VERBOSE]] else verbose.broker{"no reply expected or canceled for request ", requestid}
						end
					elseif member.attribute then                                          --[[VERBOSE]] verbose.broker({"got request for attribute ", member.attribute}, true)
						local result
						if member.inputs[1] 
							then servant[member.attribute] = buffer:get(member.inputs[1])     --[[VERBOSE]] verbose.broker{"changed the value of ", member.attribute}
							else result = servant[member.attribute]                           --[[VERBOSE]] verbose.broker{"the value of ", member.attribute, " is ", result}
						end                                                                 --[[VERBOSE]] verbose.broker()
						if conn.pending[requestid] and header.response_expected then
							Reply.request_id = requestid                                      --[[VERBOSE]] verbose.broker({"send reply for request ", requestid}, true)
							Reply.reply_status = "NO_EXCEPTION"
							_, except = conn:send(self, ReplyID, Reply,
							                      member.outputs, {result})                   --[[VERBOSE]] verbose.broker() else verbose.broker{"no reply expected or canceled for request ", requestid}
						end
					else
						_, except = self:sendsysex(conn, requestid, { "NO_IMPLEMENT",
							minor_code_value  = 1, -- TODO:[maia] Which value?
							completion_status = COMPLETED_NO,
						})                                                                  --[[VERBOSE]] verbose.broker()
					end
				else
					_, except = self:sendsysex(conn, requestid, { "BAD_OPERATION",
						minor_code_value  = 1, -- TODO:[maia] Which value?
						completion_status = COMPLETED_NO,
					})                                                                    --[[VERBOSE]] verbose.broker()
				end
			else
				if
					header.operation == "_non_existent" or
					header.operation == "_not_existent"
				then                                                                    --[[VERBOSE]] verbose.broker "non_existent basic operation"
					Reply.request_id = requestid                                          --[[VERBOSE]] verbose.broker({"send reply for request ", requestid}, true)
					Reply.reply_status = "NO_EXCEPTION"
					_, except = conn:send(self, ReplyID, Reply,
					                      ObjectOps._non_existent.outputs, ReturnTrue)
				else                                                                    --[[VERBOSE]] verbose.broker{"object does not exist [key: ", header.object_key, "]"}
					_, except = self:sendsysex(conn, requestid, { "OBJECT_NOT_EXIST",
						minor_code_value  = 1, -- TODO:[maia] Which value?
						completion_status = COMPLETED_NO,
					})
				end                                                                     --[[VERBOSE]] verbose.broker()
			end
			conn.pending[requestid] = nil
		else                                                                        --[[VERBOSE]] verbose.broker{"got duplicated request ID: ", requestid}
			except = Exception{ "INTERNAL", minor_code_value = 0,
				completion_status = COMPLETED_NO,
				message = "duplicated request ID received",
				reason = "requestid",
				requestid = requestid,
			}
			self:sendsysex(conn, requestid, except)
		end
	elseif msgid == CancelRequestID then                                          --[[VERBOSE]] verbose.broker{"message to cancel request ", header.request_id}
		conn.pending[header.request_id] = nil
	elseif msgid == LocateRequestID then                                          --[[VERBOSE]] verbose.broker("message requesting location", true)
		LocateReply.request_id = header.request_id
		conn:send(self, LocateReplyID, LocateReply)                                 --[[VERBOSE]] verbose.broker()
	elseif msgid == MessageErrorID then                                           --[[VERBOSE]] verbose.broker "message error notice"
		conn:close()
	elseif msgid then
		except = Except{ "INTERNAL",
			completion_status = COMPLETED_NO,
			message = "unexpected GIOP message, got "..MessageType[msgid],
			reason = "unexpected",
			messageid = msgid,
		}
		self:sendsysex(conn, requestid, except)
	else
		if header.reason ~= "closed" then
			except = header                                                           --[[VERBOSE]] else verbose.receive "client closed the connection"
		end
		conn:close()
	end
	return except == nil, except
end

--------------------------------------------------------------------------------

function Broker:workpending(timeout)
	return self.port:waitformore(timeout or 0)
end

function Broker:performwork()
	return self.port:accept(self)
end

function Broker:run()
	return self.port:acceptall(self)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function init(args)
	if not args then args = {} end
	local tag = args.protocoltag or 0
	local protocol = Protocols[tag]
	if protocol then                                                              --[[VERBOSE]] verbose.broker({"initiating new ORB instance with protocol ", protocol.Tag}, true)
		local port, except = protocol.listen(args)
		if port
			then return Broker(port, args.manager)                                    --[[VERBOSE]] , verbose.broker()
			else return nil, except                                                   --[[VERBOSE]] , verbose.broker()
		end
	else
		assert.raise{ "INTERNAL",
			message = "protocol with tag "..tag.." is not supported",
			reason = "protocol",
			tag = tag,
		}
	end
end
