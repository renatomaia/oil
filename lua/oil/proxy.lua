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

module "oil.proxy"                                                              --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local oo      = require "oil.oo"
local verbose = require "oil.verbose"
local assert  = require "oil.assert"
local idl     = require "oil.idl"
local giop    = require "oil.giop"
local invoke  = require "oil.invoke"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local addmember = idl.InterfaceMemberList.__newindex
function interface(iface)
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

local function checkresults(results, exception)                                 --[[VERBOSE]] verbose.proxy()
	if results
		then return unpack(results)
		else return assert.error(exception)
	end
end

local function checkcall(results, exception)                                    --[[VERBOSE]] verbose.proxy()
	if not results then return assert.error(exception) end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Object = oo.class()

Object._iface = { repID = "IDL:omg.org/CORBA/Object:1.0", members = {} }

function Object:__init(ior)
	assert.type(ior, "table", "IOR")                                              --[[VERBOSE]] verbose.proxy{"new proxy for ", self._iface.repID}
	return oo.rawnew(self, ior)
end

function Object:__index(field)
	local cache = getmetatable(self)
	if cache[field] then return cache[field] end
	if type(field) == "string" then                                               --[[VERBOSE]] verbose.proxy({"get definition of member ", field}, true)
		local member = self._iface.members[field]                                   --[[VERBOSE]] verbose.proxy()
		if type(member) == "table" then
			if member._type == "operation" then                                       --[[VERBOSE]] verbose.proxy{"new stub function for operation ", field}
				local function stub(self, ...)                                          --[[VERBOSE]] verbose.proxy({"invoke operation ", field, " with ", arg.n, " arguments"}, true)
					return checkresults(invoke.call(self, member, arg))
				end
				cache[field] = stub
				return stub
			elseif member._type == "attribute" then                                   --[[VERBOSE]] verbose.proxy({"read attribute ", field}, true)
				return checkresults(invoke.call(self, member.getter))
			else
				assert.error("unsupported member kind, got "..tostring(member._type))
			end
		end
	end
end

function Object:__newindex(field, value)
	if type(field) == "string" then                                               --[[VERBOSE]] verbose.proxy({"get definition of member ", field}, true)
		local member = self._iface.members[field]                                   --[[VERBOSE]] verbose.proxy()
		if type(member) == "table" then
			if member._type == "attribute" then                                       --[[VERBOSE]] verbose.proxy({"write ", member.readonly and "readonly" or "", "attribute ", field}, true)
				if not member.readonly
					then return checkcall(invoke.call(self, member.setter, {value,n=1}))
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
		Object[name] = function(self, ...)                                          --[[VERBOSE]] verbose.proxy({"invoke operation ", VERBOSE_field, " with ", arg.n, " arguments"}, true)
			return checkresults(invoke.call(self, member, arg))
		end
	end
end

local member = ObjectOps._non_existent
function Object:_non_existent()                                                 --[[VERBOSE]] verbose.proxy("invoke operation _non_existent", true)
	local results, exception = invoke.call(self, member)                          --[[VERBOSE]] verbose.proxy()
	if results then
		return results[1]
	elseif
		exception.exception_id == "IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0" or
		exception.reason == "connect" or
		exception.reason == "closed"
			then return true
			else return assert.error(exception)
	end
end

function Object:_narrow(iface)                                                  --[[VERBOSE]] verbose.proxy("narrowing proxy", true)
	local manager = self._manager

	if iface == nil then                                                          --[[VERBOSE]] verbose.proxy("no interface suppied, getting object interface", true)
		local result = invoke.call(self, ObjectOps._interface)
		if result and result[1] then
			result = result[1]
			iface = result:_get_id()
			if (not manager) or (not manager:getiface(iface)) then                    --[[VERBOSE]] verbose.proxy "using unknown remote interface"
				iface = interface(result)                                               --[[VERBOSE]] else verbose.proxy "object interface is already known"                       
			end
		else                                                                        --[[VERBOSE]] verbose.proxy "no results, using interface defined at IOR"
			iface = self._type_id
		end                                                                         --[[VERBOSE]] verbose.proxy()
	end
	
	local newclass
	if manager then
		if type(iface) ~= "string" then                                             --[[VERBOSE]] verbose.proxy("registering narrowing interface at object manager", true)
			iface = manager:putiface(iface)
			iface = iface.repID                                                       --[[VERBOSE]] verbose.proxy()
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
	else                                                                          --[[VERBOSE]] verbose.proxy("creating unmanaged proxy class from interface", true)
		assert.type(iface, "idlinterface", "narrowing interface")
		newclass = class(iface)                                                     --[[VERBOSE]] verbose.proxy()
	end
	
	return newclass(self)                                                         --[[VERBOSE]] , verbose.proxy()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function class(interface, manager, orb)                                         --[[VERBOSE]] verbose.proxy{"new proxy class for ", interface.repID}
	return oo.class({
		_iface = interface,
		__idltype = interface,
		_manager = manager or false,
		_orb = orb or false,
		_handlers = {}, -- exception handlers
		-- this is only necessary if OiL object model does not make copies of
		-- inherited members (e.g. LOOP models like 'simple' or 'multiple')
		__index = Object.__index,
		__newindex = Object.__newindex,
	}, Object)
end
