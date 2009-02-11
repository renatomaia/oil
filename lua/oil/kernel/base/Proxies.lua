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

local setmetatable = setmetatable

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.base.Proxies", oo.class)

context = false

local function newclass(methodmaker)
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

function __init(self, ...)
	self = oo.rawnew(self, ...)
	self.class = self.class or newclass(self.invoker)
	return self
end

function fromstring(self, reference, ...)
	local result, except = self.context.referrer:decode(reference)
	if result then
		result, except = self:resolve(result, ...)
	end
	return result, except
end

function resolve(self, reference, ...)                                          --[[VERBOSE]] verbose:proxies(true, "resolve reference for ",reference)
	local result, except
	local context = self.context
	local servants = context.servants
	if servants then
		result, except = context.referrer:islocal(reference, servants.accesspoint)
		if result then                                                              --[[VERBOSE]] verbose:unmarshal "local object implementation restored"
			result = servants:retrieve(result)
		end
	end
	if not result then
		result, except = self:newproxy(reference, ...)
	end                                                                           --[[VERBOSE]] verbose:proxies(false)
	return result, except
end

function newproxy(self, reference)                                              --[[VERBOSE]] verbose:proxies("new proxy to ",reference)
	return self.class{
		__context = self.context,
		__reference = reference,
	}
end

function excepthandler(self, handler)                                           --[[VERBOSE]] verbose:proxies("setting exception handler for proxies")
	self.defaulthandler = handler
	return true
end
