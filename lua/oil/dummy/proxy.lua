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

module ("oil.dummy.proxy", oo.class )                                                 --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local verbose = require "oil.verbose"
local assert  = require "oil.assert"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function checkresults(result, reply)                                 --[[VERBOSE]] verbose:proxy(false)
	if result then
		return unpack(reply:result())
	else
		return assert.error(reply)
	end
end

local function checkcall(results, exception)                                    --[[VERBOSE]] verbose:proxy(false)
	if not results then return assert.error(exception) end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Object = oo.class()

function Object:__init(reference)
	assert.type(reference, "table", "reference is not a table")                   --[[VERBOSE]] verbose:proxy("new proxy")
	return oo.rawnew(self, reference)
end

function Object:__call(operation, ... )
	return self._protocol:sendrequest(self, operation, ...)
end

function Object:__index(field)
	if type(field) == "string" then                                               --[[VERBOSE]] verbose:proxy(true, "get definition of member ", field)
		local function stub(self, ...)                                              --[[VERBOSE]] verbose:proxy("invoke operation ", field, " with ", select("#", ... ), " arguments")
			return checkresults(self._protocol:sendrequest(self._reference, field, ...))
		end                                                                     
		return stub
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
classes = {}

function create(self, reference, protocol, interfaceName)
	local class
	class = self.classes[interfaceName]
	if not class then
		class = Object{
			_iface = interface,
			_reference = reference,
			_protocol = protocol,
		}
		self.classes[interfaceName] = class
	end
	return class
end

