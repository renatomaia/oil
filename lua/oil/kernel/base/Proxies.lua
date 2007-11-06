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

local assert = assert
local error  = error
local pairs  = pairs
local rawget = rawget
local unpack = unpack

local table = require "loop.table"

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.base.Proxies", oo.class)

context = false

--------------------------------------------------------------------------------

Results = oo.class{}

function Results:results()
	return self.success, unpack(self, 1, self.resultcount)
end

--------------------------------------------------------------------------------

local DefaultHandler

function callhandler(self, ...)
	local handler = rawget(self, "__exceptions") or
	                oo.classof(self).__exceptions or
	                DefaultHandler or
	                error((...))
	return handler(self, ...)
end

function packresults(...)
	return Results{ success = true, resultcount = select("#", ...), ... }
end

--------------------------------------------------------------------------------

function assertcall(self, operation, reply, except)
	return reply or packresults(callhandler(self, except, operation))
end

function assertresults(self, operation, success, except, ...)
	if not success then
		return callhandler(self, except, operation)
	end
	return except, ...
end

--------------------------------------------------------------------------------

local CurrentOp -- current operation that is being invoked

local function invokecurrent(self, ...)                                         --[[VERBOSE]] verbose:proxies("call to ",CurrentOp, ...)
	return self.__context.invoker:invoke(self.__reference, CurrentOp, ...)
end

--------------------------------------------------------------------------------

Proxy = oo.class()

function makemethod(invoker, operation)
	return function(self, ...)
		return assertresults(self, operation,
			assertcall(self, operation, invoker(self, ...)):results()
		)
	end
end

local proxymethod = makemethod(invokecurrent)
function Proxy:__index(operation)       
	CurrentOp = operation
	return proxymethod
end

--------------------------------------------------------------------------------

Protected = oo.class()

function makeprotected(invoker)
	return function(self, ...)
		local reply, except = invoker(self, ...)
		if reply
			then return reply:results()
			else return false, except
		end
	end
end

local protectedmethod = makeprotected(invokecurrent)
function Protected:__index(operation)
	CurrentOp = operation
	return protectedmethod
end

--------------------------------------------------------------------------------

Deferred = oo.class()

FailedFuture = oo.class()
function FailedFuture:ready() return true end
function FailedFuture:results() return false, self[1] end
function evaluatefuture(self)                                                   --[[VERBOSE]] verbose:proxies("getting deferred results of ",self.operation)
	return assertresults(
		self.proxy,
		self.operation,
		self:results()
	)
end

function makedeferred(invoker, operation)
	return function(self, ...)
		local reply, except = invoker(self, ...)
		if reply == nil then reply = FailedFuture{ except } end
		reply.proxy = self
		reply.operation = operation
		reply.evaluate = evaluatefuture
		return reply
	end
end

local deferredmethod = makedeferred(invokecurrent)
function Deferred:__index(operation)
	CurrentOp = operation
	return deferredmethod
end

--------------------------------------------------------------------------------

Extras = {
	__deferred = Deferred,
	__try = Protected,
}

function proxyto(self, reference)
	local proxy = Proxy{
		__context = self.context,
		__reference = reference,
	}
	for label, class in pairs(Extras) do
		proxy[label] = class{
			__context = self.context,
			__reference = reference,
		}
	end
	return proxy
end

function excepthandler(self, handler)
	DefaultHandler = handler
	return true
end
