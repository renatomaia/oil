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

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.base.Proxies", oo.class)

context = false

--------------------------------------------------------------------------------

Results = oo.class{}

function Results:results()
	return unpack(self, 1, self.resultcount)
end

--------------------------------------------------------------------------------

local function callhandler(self, ...)
	local handler = rawget(self, "__exceptions") or
	                rawget(oo.classof(self), "__exceptions") or
	                rawget(Proxy, "__exceptions")
	return handler(self, ...)
end

local function packresults(...)
	return Results{ resultcount = select("#", ...) + 1, true, ... }
end

--------------------------------------------------------------------------------

Proxy = oo.class()

function Proxy:__exceptions(except)
	error(except)
end

function Proxy:checkcall(operation, reply, except)
	return reply or packresults(callhandler(self, except, operation))
end

function Proxy:checkresults(operation, success, ...)
	if not success then
		return callhandler(self, ..., operation)
	end
	return ...
end

function Proxy:deferredresults()                                                --[[VERBOSE]] verbose:proxies("getting deferred results of ",self.operation)
	return Proxy.checkresults(self.proxy, self.operation, Results.results(self))
end

local operation

function Proxy:defer(...)                                                       --[[VERBOSE]] verbose:proxies("deferred call to ",operation, ...)
	local reply = Proxy.checkcall(self, operation,
		self.__context.invoker:invoke(self, operation, ...))
	reply.proxy = self
	reply.operation = operation
	reply.results = Proxy.deferredresults
	return reply
end

function Proxy:invoke(...)                                                      --[[VERBOSE]] verbose:proxies("call to ",operation, ...)
	return Proxy.checkresults(self, operation, 
	       	Proxy.checkcall(self, operation,
	       		self.__context.invoker:invoke(self, operation, ...)
	       	):results()
	       )
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

function excepthandler(self, handler)
	Proxy.__exceptions = handler
	return true
end
