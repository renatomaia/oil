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
-- Title  : Dynamic client stub for remote object access                      --
-- Authors: Renato Maia           <maia@inf.puc-rio.br>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   class(iface) Creates a class for creating client stubs (object proxies)  --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   You can use this module to access objects without use of an Interface    --
--   Repository (IR) or IDL compiler. See the example below:                  --
--                                                                            --
--     local Hello = oil.proxy.class(oil.idl.interface{                       --
--       name = "Hello",                                                      --
--       members = {                                                          --
--         say_hello_to = oil.idl.operation{                                  --
--           parameters = {{name = "to", type = IDL.string}},                 --
--         },                                                                 --
--       },                                                                   --
--     }                                                                      --
--     local proxy = Hello(oil.ior.decode("IOR:..."))                         --
--     proxy:say_hello_to("world")                                            --
--                                                                            --
--------------------------------------------------------------------------------

local type         = type
local pairs        = pairs
local ipairs       = ipairs
local tostring     = tostring
local unpack       = unpack
local require      = require
local rawset       = rawset
local getmetatable = getmetatable
local print        = print
local select       = select

local oo      = require "oil.oo"

module ("oil.proxy", oo.class )                                                 --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local verbose = require "oil.verbose"
local assert  = require "oil.assert"
local idl     = require "oil.idl"
local giop    = require "oil.corba.giop"
local invoke  = require "oil.corba.Protocol"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local addmember = idl.InterfaceMemberList.__newindex
function interface(iface)                                                       --[[VERBOSE]] verbose:proxy("entering interface")
	local desc = iface:describe_interface()

	rawset(iface, "_type", "interface")
	rawset(iface, "repID", desc.id)
	rawset(iface, "members", {})

	for _, attribute in ipairs(desc.attributes) do
		attribute.defined_in = iface
		addmember(iface.members, attribute.name, idl.attribute(attribute))
	end
	
	for _, operation in ipairs(desc.operations) do
		local excepts = operation.exceptions
		for index, except in ipairs(excepts) do
			excepts[index] = except.type
		end
		operation.defined_in = iface
		addmember(iface.members, operation.name, idl.operation(operation))
	end
	
	return iface
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function checkresults(results, exception)                                 --[[VERBOSE]] verbose:proxy(false)
	if results
		then return unpack(results)
		else return assert.error(exception)
	end
end

local function checkcall(results, exception)                                    --[[VERBOSE]] verbose:proxy(false)
	if not results then return assert.error(exception) end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Object = oo.class()

Object._iface = { repID = "IDL:omg.org/CORBA/Object:1.0", members = {} }

function Object:__init(reference)
	assert.type(reference, "table", "reference is not a table")                   --[[VERBOSE]] verbose:proxy("new proxy for ", reference._type_id)
	return oo.rawnew(self, reference)
end

function Object:__call(operation, ... )
	return self.protocol:sendrequest(self, operation, ...)
end

function Object:__index(field)
	local cache = getmetatable(self)
	if cache[field] then return cache[field] end
	if type(field) == "string" then                                               --[[VERBOSE]] verbose:proxy(true, "get definition of member ", field)
		local member = self._iface.members[field]                                   --[[VERBOSE]] verbose:proxy(false)
		if type(member) == "table" then
			if member._type == "operation" then                                       --[[VERBOSE]] verbose:proxy("new stub function for operation ", field)
				local function stub(self, ...)                                          --[[VERBOSE]] verbose:proxy("invoke operation ", field, " with ", select("#", ... ), " arguments")
					return checkresults(self._protocol:call(self.reference, member, ...))
				end                                                                     
				cache[field] = stub
				return stub
			elseif member._type == "attribute" then                                   --[[VERBOSE]] verbose:proxy("read attribute ", field)
				return checkresults(self._protocol:call(self.reference, member.getter))
			else
				assert.error("unsupported member kind, got "..tostring(member._type))
			end
		end
	end
end

function Object:__newindex(field, value)
	if type(field) == "string" then                                               --[[VERBOSE]] verbose:proxy(true, "get definition of member ", field)
		local member = self._iface.members[field]                                   --[[VERBOSE]] verbose:proxy(false)
		if type(member) == "table" then
			if member._type == "attribute" then                                       --[[VERBOSE]] verbose:proxy("write ", member.readonly and "readonly" or "", "attribute ", field)
				if not member.readonly
					then checkcall(self._protocol:call(self._decoded_profile, member.setter, value))
					else assert.error("attempt to set read-only attribute "..field)
				end
			elseif member._type ~= "operation" then
				assert.error("unsupported interface member type, got "..tostring(member._type))
			end
		end
	end
	rawset(self, field, value)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

ObjectOps = giop.ObjectOperations

for name, value in pairs(ObjectOps) do
	if type(value) == "table" and value._type == "operation" then
		local member = value                                                        --[[VERBOSE]] local VERBOSE_field = name
		Object[name] = function(self, ...)                                          --[[VERBOSE]] verbose:proxy(true, "invoke operation ", VERBOSE_field, " with ", select( "#", ... ), " arguments")
			return checkresults(self._protocol:call(self._decoded_profile, member, ...))
		end
	end
end

local member = ObjectOps._non_existent
function Object:_non_existent()                                                 --[[VERBOSE]] verbose:proxy(true, "invoke operation _non_existent")
	local results, exception = self._protocol:call(self._decoded_profile, member) --[[VERBOSE]] verbose:proxy(false)
	if results then
		return results[1]
	elseif exception.reason == "connect" or exception.reason == "closed" then
		return true
	else
		return assert.error(exception)
	end
end

function Object:_narrow(iface)                                                  --[[VERBOSE]] verbose:proxy(true, "narrowing proxy")
	local manager = self._manager

	if iface == nil then                                                          --[[VERBOSE]] verbose:proxy(true, "no interface suppied, getting object interface")
		local result = self._protocol:call(self._decoded_profile, ObjectOps._interface)
		if result and result[1] then
			result = result[1]
			iface = result:_get_id()
			if (not manager) or (not manager:getiface(iface)) then                    --[[VERBOSE]] verbose:proxy "using unknown remote interface"
				iface = interface(result)                                               --[[VERBOSE]] else verbose:proxy "object interface is already known"                       
			end
		else                                                                        --[[VERBOSE]] verbose:proxy "no results, using interface defined at reference table"
			iface = self._type_id
		end                                                                         --[[VERBOSE]] verbose:proxy(false)
	end
	
	local newclass
	if manager then
		if type(iface) ~= "string" then                                             --[[VERBOSE]] verbose:proxy(true, "registering narrowing interface at object manager")
			iface = manager:putiface(iface)
			iface = iface.repID                                                       --[[VERBOSE]] verbose:proxy(false)
		elseif manager.lookup then
			local interface = manager:lookup(iface)
			if interface then iface = interface.repID end
		end
		newclass = manager:getclass(iface)
		if not newclass then
			assert.raise{ "INTERNAL", minor_code_value = 0,
				reason = "interface",
				message = "unknown interface repository ID",
				repID = iface,
			}
		end
	else                                                                          --[[VERBOSE]] verbose:proxy(true, "creating unmanaged proxy class from interface")
		assert.type(iface, "idlinterface", "narrowing interface")
		newclass = class(iface)                                                     --[[VERBOSE]] verbose:proxy(false)
	end
	
	return newclass(self)                                                         --[[VERBOSE]] , verbose:proxy(false)
end

function create(self, reference, protocol, interfaceName)
	if not interfaceName then
		interfaceName = reference._type_id  
	end
	
	local class
	if self.interfaces then 
		class = self.interfaces:getclass(interfaceName)
		if not class then
			local interface = self.interfaces:lookup(interfaceName) 
			if interface then
				class = self.interfaces:getclass(interface.repID)
			end
			if not class then
				object = self.manager:getclass("IDL:omg.org/CORBA/Object:1.0")(object) 
				object = object:_narrow()
			end
		end
		if class then object = class(object) end            
	end
	rawset(object, "_orb", init())
  return Object{ reference = reference, 
	               protocol = protocol,
	}
	return object
end
