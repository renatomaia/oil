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

local assert       = assert
local error        = error
local pairs        = pairs
local rawget       = rawget
local select       = select
local setmetatable = setmetatable
local unpack       = unpack

local table = require "loop.table"

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.base.Proxies", oo.class)

context = false

--------------------------------------------------------------------------------

local DefaultHandler

function callhandler(self, ...)
	local handler = rawget(self, "__exceptions") or
	                rawget(oo.classof(self), "__exceptions") or
	                DefaultHandler or
	                error((...))
	return handler(self, ...)
end

function assertresults(self, operation, success, except, ...)
	if not success then
		return callhandler(self, except, operation)
	end
	return except, ...
end

--------------------------------------------------------------------------------

function newcache(methodmaker)
	return setmetatable(oo.initclass(), {
		__mode = "v",
		__call = oo.rawnew,
		__index = function(cache, operation)
			local function invoker(self, ...)                                         --[[VERBOSE]] verbose:proxies("call to ",operation, ...)
				return self.__context.requester:newrequest(self.__reference, operation, ...)
			end
			invoker = methodmaker(invoker, operation)
			cache[operation] = invoker
			return invoker
		end,
	})
end

--------------------------------------------------------------------------------

function makemethod(invoker, operation)
	return function(self, ...)
		local success, except = invoker(self, ...)
		if success then
			local request = success
			success, except = self.__context.requester:getreply(request)
			if success then
				return assertresults(self, operation, request:contents())
			end
		end
		if not success then
			return callhandler(self, except, operation)
		end
	end
end

Proxy = newcache(makemethod)

--------------------------------------------------------------------------------

function makeprotected(invoker)
	return function(self, ...)
		local success, except = invoker(self, ...)
		if success then
			local request = success
			success, except = self.__context.requester:getreply(request)
			if success then
				return request:contents()
			end
		end
		return success, except
	end
end

Protected = newcache(makeprotected)

--------------------------------------------------------------------------------

Request = oo.class()
function Request:ready()                                                        --[[VERBOSE]] verbose:invoke(true, "check reply")
	local proxy = self.proxy
	assertresults(proxy, self.operation,
	              proxy.__context.requester:getreply(request, true))              --[[VERBOSE]] verbose:invoke(false)
	return self.contents ~= nil
end
function Request:results()                                                      --[[VERBOSE]] verbose:invoke(true, "get reply")
	local success, except = self.proxy.__context.requester:getreply(self)
	if success then
		return self:contents()
	end                                                                           --[[VERBOSE]] verbose:invoke(false)
	return success, except
end
function Request:evaluate()                                                     --[[VERBOSE]] verbose:proxies("getting deferred results of ",self.operation)
	return assertresults(
		self.proxy,
		self.operation,
		self:results()
	)
end

Failed = oo.class({}, Request)
function Failed:ready()
	return true
end
function Failed:results()
	return false, self[1]
end

function makedeferred(invoker, operation)
	return function(self, ...)
		local request, except = invoker(self, ...)
		if request then
			request = Request(request)
		else
			request = Failed{ except }
		end
		request.proxy = self
		request.operation = operation
		return request
	end
end

Deferred = newcache(makedeferred)

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
