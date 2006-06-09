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
local print        = print
local pairs        = pairs
local unpack       = unpack

local string = require "string"
local table  = require "table"
local oo     = require "oil.oo"

local pcall = scheduler and scheduler.pcall or pcall

module ("oil.orb", oo.class )                                                   --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local ObjectCache = require "loop.collection.ObjectCache"
local Exception   = require "oil.Exception"
local assert      = require "oil.assert"
local IDL         = require "oil.idl"
local giop        = require "oil.corba.giop"

--------------------------------------------------------------------------------
-- Local module variables ------------------------------------------------------

local Protocols          = giop.Protocols

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function isbaseof(baseid, iface)
	if iface.is_a then                                                            --[[VERBOSE]] verbose:servant(true, "executing interface is_a operation")
		return iface:is_a(baseid)                                                   --[[VERBOSE]] , verbose:servant(false)
	end                                                                           --[[VERBOSE]] verbose:servant(true, "checking if ", baseid, " is base of ", iface.repID)
	
	local data = { iface }
	while table.getn(data) > 0 do
		iface = table.remove(data)
		if not data[iface] then                                                     --[[VERBOSE]] verbose:servant("reached interface ", iface.repID)
			data[iface] = true
			if iface.repID == baseid then
				return true                                                             --[[VERBOSE]] , verbose:servant(false)
			end
			for _, base in ipairs(iface.base_interfaces) do
				table.insert(data, base)
			end
		end
	end                                                                           --[[VERBOSE]] verbose:servant(false)
	
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local ObjectOps = giop.ObjectOperations

Object = oo.class()

-- TODO:[maia] add basic operations for servants

function Object:_is_a(repID)                                                    --[[VERBOSE]] verbose:servant(true, "verifying if object interface ", self._iface.repID, " is a ", repIDtrue )
	return isbaseof(repID, self._iface)                                           --[[VERBOSE]] , verbose:servant(false)
end

function Object:_interface()                                                    --[[VERBOSE]] verbose:servant "retrieveing object interface"
	local iface = self._iface
	if getmetatable(iface)
		then return iface
		else assert.raise{ "INTF_REPOS", minor_code_value = 1,
			reason = "interface",
			iface = iface,
		}
	end
end

function Object:_non_existent()                                                 --[[VERBOSE]] verbose:servant "probing for object existency, returning false"
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
-- Dispatcher initialization -------------------------------------------------------

local Dispatcher = oo.class()

function Dispatcher:__init(orb, port, manager)
	local dispatcher = {
		map = {},
		port = port,
		manager = manager,
		reference_resolver = orb.reference_resolver,
	}
	dispatcher._manager = dispatcher
	dispatcher._orb = broker
	return oo.rawnew(self, dispatcher)
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

function Dispatcher:object(servant, interface, objid)
	if objid == nil then 
		objid = getobjectid(servant)
	else 
		assert.type(objid, "string", "object ID")
	end
	local object = self.map[objid]
	if object then                                                                --[[VERBOSE]] verbose:servant(true, "servant already is registered")
		if interface and object._type_id ~= interface.repID then
			if isbaseof(object._type_id, interface) then                              --[[VERBOSE]] verbose:servant "changing actual object interface to a narrowed interface"
				object._iface = interface
				object._type_id = interface.repID
			elseif not isbaseof(interface.repID, object._iface) then
				assert.illegal(interface.repID, "attempt to change object interface")   --[[VERBOSE]] else verbose:servant "attempt to change object interface for a broader interface, no action done"
			end                                                                       --[[VERBOSE]] else verbose:servant "object is exported with same interface as before"
		end                                                                         --[[VERBOSE]] verbose:servant(false)
	else
		local profile = self.reference_resolver:encode_profile(self.port.host, 
		                                                      self.port.port, 
																													objid)                --[[VERBOSE]] verbose:servant(true, "new object with id ", objid, " [iface: ", interface.repID, "]")
		object = Object{
			_orb = self,
			_servant = servant,
			_iface = interface,
			_objectid = objid,
			-- IOR
			_type_id = interface.repID,
			_profiles = {profile},
		}
		self.map[objid] = object                                                    --[[VERBOSE]] verbose:servant(false)
	end
	return object
end

function Dispatcher:resolve(reference, iface)                                   --[[VERBOSE]] verbose:servant(true, "resolving reference to servant")
	for tag, profile in ipairs(reference._profiles) do
		local port, key = Protocols[profile.tag]
		if port then
			port, key = port.getport(profile.profile_data)
			if port then
				if port == self.port then                                               --[[VERBOSE]] verbose:servant "servant colocated at same ORB"
					return self.map[key]._servant                                         --[[VERBOSE]] , verbose:servant(false)
				end                                                                     --[[VERBOSE]] verbose:servant "servant colocated at other ORB"
				break
			end
		end
	end                                                                           --[[VERBOSE]] verbose:servant(false)
	if self.manager then
		local object = self.manager:resolve(reference, iface)
		object._orb = self
		return object
	else
		return reference
	end
end

function Dispatcher:getobject(objid)
	return self.map[objid], ObjectOps
end

function Dispatcher:getreference(obj)                                                 --[[VERBOSE]] verbose:servant(true, "getting servant IOR")
	return self.reference_resolver:encode(obj)                                   --[[VERBOSE]] , verbose:servant(false)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function packpcall(success, ...)
	if success
		then return success, arg
		else return success, arg[1]
	end
end

local function dispatch(servant, method, params)
	return packpcall(pcall(method, servant, unpack(params)))
end

function Dispatcher:handle(object_key, operation, params)                       --[[VERBOSE]] verbose:dispatcher("object basic operation ", operation, " called")
	local success, result
	local object = self.map[object_key]
	if object then
																																								--[[VERBOSE]] verbose:dispatcher("object found, invoking operation ", operation)
		local servant = object._servant
		local member = object._iface.members[operation]
		if not member and ObjectOps[operation] then                                 --[[VERBOSE]] verbose:dispatcher("object basic operation ", operation, " called")
			member, servant = ObjectOps[operation], object
		end
		local method = servant[operation]
		if method then                                                              --[[VERBOSE]] verbose:dispatcher("operation implementation found [name: ", operation, "]") verbose:dispatcher(true, "get parameter values")
			success, result = dispatch(servant, method, params)                       --[[VERBOSE]] verbose:dispatcher(false)
		elseif member.attribute then                                                --[[VERBOSE]] verbose:dispatcher(true, "got request for attribute ", member.attribute)
			local result
			if member.inputs[1] then 
				servant[member.attribute] = buffer:get(member.inputs[1])                --[[VERBOSE]] verbose:dispatcher("changed the value of ", member.attribute)
			else 
				result = servant[member.attribute]                                      --[[VERBOSE]] verbose:dispatcher("the value of ", member.attribute, " is ", result)
			end
			success = true                                                            --[[VERBOSE]] verbose:dispatcher(false)
		else 
			success, result = nil, {"NO_IMPLEMENT"} -- TODO:[nogara]
		end
	else
			success, result = nil, {"OBJECT_NOT_EXIST"} -- TODO:[nogara]
	end
	return success, result
end

--------------------------------------------------------------------------------

function Dispatcher:workpending(timeout)
	return self.port:waitformore(timeout or 0)
end

function Dispatcher:performwork()
	return self.port:accept(self)
end

function Dispatcher:run()
	return self.port:acceptall(self)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- TODO:[nogara] find a better way to include the protocol here
function init(self, args)
	if not args then args = {} end
	local tag = args.protocoltag or 0
	local protocol = self.protocol 
	if protocol then                                                              --[[VERBOSE]] verbose:dispatcher(true, "initiating new ORB instance with protocol ", protocol.Tag)
		-- now, create accesspoint using the portConnection
		local port, except = self.point:listen(protocol, args)
		-- local port = true
		if port
			then return Dispatcher(self, port, args.manager)                          --[[VERBOSE]] , verbose:dispatcher(false)
			else return nil, except                                                   --[[VERBOSE]] , verbose:dispatcher(false)
		end
	else
		assert.raise{ "INTERNAL",
			message = "protocol with tag "..tag.." is not supported",
			reason = "protocol",
			tag = tag,
		}
	end
end
