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

function proxytostring(self)
	return self.__context.referrer:encode(self.__reference)
end

function unpackrequest(request)
	return request.success, unpack(request, 1, request.n)
end

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
	return setmetatable(oo.initclass{
		__tostring = proxytostring,
	}, {
		__mode = "v", -- TODO:[maia] can method creation/collection be worse than
		              --             memory leak due to invocation of constantly
		              --             changing methods ?
		__call = oo.rawnew,
		__index = function(cache, field)
			local function invoker(self, ...)                                         --[[VERBOSE]] verbose:proxies("call to ",field," ", ...)
				return self.__context.requester:newrequest(self.__reference, field, ...)
			end
			invoker = methodmaker(invoker, field)
			cache[field] = invoker
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
				return assertresults(self, operation, unpackrequest(request))
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
				return unpackrequest(request)
			end
		end
	end
end

Protected = newcache(makeprotected)

--------------------------------------------------------------------------------

Request = oo.class()
function Request:ready()                                                        --[[VERBOSE]] verbose:proxies("check reply availability")
	local proxy = self.proxy
	assertresults(proxy, self.operation,
	              proxy.__context.requester:getreply(request, true))
	return self.success ~= nil
end
function Request:results()                                                      --[[VERBOSE]] verbose:proxies(true, "get reply results")
	local success, except = self.proxy.__context.requester:getreply(self)
	if success then
		return unpackrequest(self)
	end                                                                           --[[VERBOSE]] verbose:proxies(false)
	return success, except
end
function Request:evaluate()                                                     --[[VERBOSE]] verbose:proxies("get deferred results of ",self.operation)
	return assertresults(self.proxy, self.operation, self:results())
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
			request.proxy = self
			request.operation = operation
			request = Request(request)
		else
			request = Failed{ except }
		end
		return request
	end
end

Deferred = newcache(makedeferred)

--------------------------------------------------------------------------------

Extras = {
	__deferred = Deferred,
	__try = Protected,
}

function fromstring(self, reference, ...)
	local result, except = self.context.referrer:decode(reference)
	if result then
		result, except = self:newproxy(result, ...)
	end
	return result, except
end

function resolve(self, reference, ...)
	local result, except
	local context = self.context
	local servants = context.servants
	if servants then
		result, except = context.referrer:islocal(reference, servants.accesspoint)
		if result then
			result = servants:retrieve(result)
		end
	end
	if not result then
		result, except = self:newproxy(reference, ...)                              --[[VERBOSE]] else verbose:unmarshal "local object implementation restored"
	end
	return result, except
end

function newproxy(self, reference)                                              --[[VERBOSE]] verbose:proxies("new proxy to ",reference)
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

function excepthandler(self, handler)                                           --[[VERBOSE]] verbose:proxies("setting exception handler for proxies")
	DefaultHandler = handler
	return true
end
