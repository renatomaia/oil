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

module ("oil.corba.SimpleDispatcher", oo.class )                                                   --[[VERBOSE]] local verbose = require "oil.verbose"

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

Object = oo.class()

function Object:__index(field)
	local value = self._servant[field]
	if value == nil then value = Object[field] end
	return value
end

function Object:__newindex(field, value)
	self._servant[field] = value
end

-- specific functions for corba objects
function Object:_is_a(repID)                                                    --[[VERBOSE]] verbose:servant(true, "verifying if object interface ", self._iface.repID, " is a ", repID )
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

--------------------------------------------------------------------------------
-- Dispatcher initialization -------------------------------------------------------

map = {}

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

function register(self, key, object, intfaceName)
	local iface
	if self.objects then
		iface = self.objects:lookup(intfaceName)
		assert.type(iface, "idlinterface", "object interface")
	end

	if key == nil then 
		key = getobjectid(object)
	else 
		assert.type(key, "string", "object ID")
	end
	local loc_object = self.map[key]
	if loc_object then                                                                --[[VERBOSE]] verbose:servant(true, "servant already is registered")
		if iface and loc_object._type_id ~= iface.repID then
			if isbaseof(loc_object._type_id, iface) then                              --[[VERBOSE]] verbose:servant "changing actual object interface to a narrowed interface"
				loc_object._iface = iface
				loc_object._type_id = iface.repID
			elseif not isbaseof(iface.repID, loc_object._iface) then
				assert.illegal(iface.repID, "attempt to change object interface")   --[[VERBOSE]] else verbose:servant "attempt to change object interface for a broader interface, no action done"
			end                                                                       --[[VERBOSE]] else verbose:servant "object is exported with same interface as before"
		end                                                                         --[[VERBOSE]] verbose:servant(false)
	else
		loc_object = Object{
			_orb = self,
			_servant = object,
			_iface = iface,
			_objectid = key,
			_type_id = iface.repID,
		}
		self.map[key] = loc_object                                                    --[[VERBOSE]] verbose:servant(false)
	end
	return loc_object
end

-- TODO[nogara]: see why 'resolve' is here
function resolve(self, reference, iface)                                   --[[VERBOSE]] verbose:servant(true, "resolving reference to servant")
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

function getobject(self, objid)
	return self.map[objid], ObjectOps
end

function deactivate(self, obj)
	self.map[obj._objectid] = nil
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function packpcall(success, ...)
	if success
		then return success, arg
		else return success, arg[1]
	end
end

local function dispatch_servant(servant, method, params)
	return packpcall(pcall(method, servant, unpack(params)))
end

local ObjectOps = giop.ObjectOperations

function handle(self, requestObj)
	local success, result
	local operation = requestObj.operation
	local key = requestObj.object_key
  local params = requestObj.params

	local object = self.map[key]
	if object then
		local servant = object._servant
		local member = object._iface.members[operation]
		if not member and ObjectOps[operation] then                                 --[[VERBOSE]] verbose:dispatcher("object basic operation ", operation, " called")
			member, servant = ObjectOps[operation], object
		end
		local method = servant[operation]
		if method then                                                              --[[VERBOSE]] verbose:dispatcher("operation implementation found [name: ", operation, "]") verbose:dispatcher(true, "get parameter values")
			success, result = dispatch_servant(servant, method, params)                       --[[VERBOSE]] verbose:dispatcher(false)
		elseif member.attribute then                                                --[[VERBOSE]] verbose:dispatcher(true, "got request for attribute ", member.attribute)
			if member.inputs[1] then 
				servant[member.attribute] = params[1]                                   --[[VERBOSE]] verbose:dispatcher("changed the value of ", member.attribute)
				result = {}
			else 
				result = {servant[member.attribute]}                                      --[[VERBOSE]] verbose:dispatcher("the value of ", member.attribute, " is ", result)
			end
			success = true                                                            --[[VERBOSE]] verbose:dispatcher(false)
		else 
			success, result = nil, {"NO_IMPLEMENT"} -- TODO:[nogara]
		end
	else
			success, result = nil, {"OBJECT_NOT_EXIST"} -- TODO:[nogara]
	end
	requestObj.result(success, result)
	return true
end

--------------------------------------------------------------------------------
--- Helper functions

function isbaseof(baseid, iface)
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


