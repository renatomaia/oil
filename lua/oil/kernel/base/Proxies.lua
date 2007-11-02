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
	return self.success, unpack(self, 1, self.resultcount)
end

--------------------------------------------------------------------------------

local function callhandler(self, ...)
	local handler = rawget(self, "__exceptions") or
	                oo.classof(self).__exceptions
	if not handler then return error((...)) end
	return handler(self, ...)
end

local function packresults(...)
	return Results{ success = true, resultcount = select("#", ...), ... }
end

--------------------------------------------------------------------------------

function checkcall(self, operation, reply, except)
	return reply or packresults(callhandler(self, except, operation))
end

function checkresults(self, operation, success, ...)
	if not success then
		return callhandler(self, ..., operation)
	end
	return ...
end

--------------------------------------------------------------------------------

Proxy = oo.class()

local operation

function Proxy:invoke(...)                                                      --[[VERBOSE]] verbose:proxies("call to ",operation, ...)
	return checkresults(self, operation, 
	       	checkcall(self, operation,
	       		self.__context.invoker:invoke(self, operation, ...)
	       	):results()
	       )
end

function Proxy:__index(field)
	operation = field
	return oo.classof(self).invoke
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Deferred = oo.class({ __index = Proxy.__index }, Proxy)

function deferredresults(self)                                                  --[[VERBOSE]] verbose:proxies("getting deferred results of ",self.operation)
	return checkresults(
		self.proxy,
		self.operation,
		oo.classof(self).results(self)
	)
end

function Deferred:invoke(...)                                                   --[[VERBOSE]] verbose:proxies("deferred call to ",operation, ...)
	self = self[1]
	local reply = checkcall(self, operation,
		self.__context.invoker:invoke(self, operation, ...))
	reply.proxy = self
	reply.operation = operation
	reply.results = deferredresults
	return reply
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function proxyto(self, reference)
	reference.__context = self.context
	reference.__deferred = Deferred{ reference }
	return Proxy(reference)
end

function excepthandler(self, handler)
	Proxy.__exceptions = handler
	return true
end
