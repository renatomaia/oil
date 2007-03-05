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
-- Release: 0.4                                                               --
-- Title  : Remote Object Proxies                                             --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- proxies:Facet
-- 	proxy:object proxyto(reference:table)
--
-- invoker:Receptacle
-- 	[results:object], [except:table] invoke(reference, operation, args...)
--------------------------------------------------------------------------------

--[[VERBOSE]] local select = select

local error  = error
local rawget = rawget
local type   = type
local unpack = unpack

local oo     = require "oil.oo"
local assert = require "oil.assert"                                             --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.base.Proxies", oo.class)

context = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Proxy = oo.class()

local function raiseerror(except)
	error(except)
end
function Proxy:doresult(operation, success, ...)
	if not success then
		return (rawget(self, "__exceptions") or raiseerror)(..., operation)
	end
	return success, ...
end

function Proxy:deferredresults()                                                --[[VERBOSE]] verbose:proxies("getting deferred results of ",self.operation)
	return select(2, Proxy.doresult(self.proxy, self.operation,
	                                unpack(self, 1, self.resultcount)))
end

local operation

function Proxy:defer(...)                                                       --[[VERBOSE]] verbose:proxies("deferred call to ",operation, ...)
	local reply = Proxy.doresult(self, operation,
		self.__context.invoker:invoke(self, operation, ...))
	reply.proxy = self
	reply.operation = operation
	reply.results = Proxy.deferredresults
	return reply
end

function Proxy:invoke(...)                                                      --[[VERBOSE]] verbose:proxies("call to ",operation, ...)
	return select(2, Proxy.doresult(self, operation, 
	                 	Proxy.doresult(self, operation,
	                 		self.__context.invoker:invoke(self, operation, ...)
	                 	):results()
	                 ))
end

function Proxy:currentop(value)
	operation = value
end

Proxy.DeferredPattern = "^___(.+)$"

function Proxy:__index(field)
	if type(field) == "string" then
		operation = field
		return field:match(Proxy.DeferredPattern) and Proxy.defer or Proxy.invoke
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function proxyto(self, reference)
	reference.__context = self.context
	return Proxy(reference)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--[[VERBOSE]] function verbose.custom:proxies(...)
--[[VERBOSE]] 	local params = false
--[[VERBOSE]] 	for i = 1, select("#", ...) do
--[[VERBOSE]] 		local value = select(i, ...)
--[[VERBOSE]] 		local type = type(value)
--[[VERBOSE]] 		if type == "string" and not params then
--[[VERBOSE]] 			self.viewer.output:write(value)
--[[VERBOSE]] 		elseif type == "table" and rawget(value, "name") then
--[[VERBOSE]] 			self.viewer.output:write(value.name,"(")
--[[VERBOSE]] 			params = true
--[[VERBOSE]] 		else
--[[VERBOSE]] 			self.viewer:write(value)
--[[VERBOSE]] 		end
--[[VERBOSE]] 	end
--[[VERBOSE]] 	if params then self.viewer.output:write(")") end
--[[VERBOSE]] end
