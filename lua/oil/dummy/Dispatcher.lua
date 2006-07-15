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

module ("oil.corba.Dispatcher", oo.class )                                                   --[[VERBOSE]] local verbose = require "oil.verbose"

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
	if key == nil then 
		key = getobjectid(object)
	else 
		assert.type(key, "string", "object ID")
	end                                                                             --[[VERBOSE]] verbose:dispatcher("registering object with key ", key)
	print("registering object","|".. key.."|")
	local loc_object = self.map[key]
	if not loc_object then
		loc_object = Object{
			_orb = self,
			_servant = object,
			_iface = iface,
			_objectid = key,
		}
		print( "object", key, "registered", loc_object)
		self.map[key] = loc_object                                                    --[[VERBOSE]] verbose:servant(false)
	end
	return loc_object
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

function handle(self, requestObj)
	local success, result
	local operation = requestObj.operation
	local key = requestObj.object_key
  local params = requestObj.params

	print("looking for object", "|"..key.."|")
	local object = self.map[key]
	print("found object", object)
	if object then
		local servant = object._servant
		print("found servant", servant)
		local method = servant[operation]
		print("found method", method)
		if method then                                                              --[[VERBOSE]] verbose:dispatcher("operation implementation found [name: ", operation, "]") verbose:dispatcher(true, "get parameter values")
			success, result = dispatch_servant(servant, method, params)                       --[[VERBOSE]] verbose:dispatcher(false)
		else 
			success, result = nil, {"NO_IMPLEMENT"} -- TODO:[nogara]
		end
	else
			success, result = nil, {"OBJECT_NOT_EXIST"} -- TODO:[nogara]
	end
	print("calling result from handle", success, result)
	requestObj.result(success, result)
	return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


