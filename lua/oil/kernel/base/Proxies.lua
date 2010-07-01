-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Remote Object Proxies
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local setmetatable = _G.setmetatable

local tabop = require "loop.table"
local memoize = tabop.memoize

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"
local class = oo.class

module(...); local _ENV = _M

class(_ENV)

function _ENV:__init()
	if self.class == nil then
		local methodmaker = self.invoker
		self.class = {
			__index = memoize(function(operation)
				local function invoker(proxy, ...)                                      --[[VERBOSE]] verbose:proxies("call to ",operation)
					return self.requester:newrequest(proxy.__reference, operation, ...)
				end
				return methodmaker(invoker, operation)
			end, "v"), -- TODO:[maia] can method creation/collection be worse than
			           --             memory leak due to invocation of constantly
			           --             changing methods ?
			__tostring = function(proxy)
				return self.referrer:encode(proxy.__reference)
			end,
		}
	end
end

function _ENV:newproxy(proxy)                                                   --[[VERBOSE]] verbose:proxies("new proxy to ",reference)
	return setmetatable(proxy, self.class)
end

function _ENV:fromstring(reference, ...)
	local result, except = self.referrer:decode(reference)
	if result then
		result, except = self:resolve(result, ...)
	end
	return result, except
end

function _ENV:resolve(reference, ...)
	local objkey = self.referrer:islocal(reference)
	if objkey and self.servants then
		local servants = self.servants
		if servants then
			local registered = servants:retrieve(objkey)
			if registered then                                                        --[[VERBOSE]] verbose:proxies("local object with key '",objkey,"' restored")
				return registered
			end
		end
	end
	return self:newproxy({__reference = reference}, ...)
end

function _ENV:excepthandler(handler)                                            --[[VERBOSE]] verbose:proxies("setting exception handler for proxies")
	self.class.__exceptions = handler
	return true
end
