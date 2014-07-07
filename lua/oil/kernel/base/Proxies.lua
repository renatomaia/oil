-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Remote Object Proxies
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local rawget = _G.rawget
local select = _G.select
local setmetatable = _G.setmetatable
local type = _G.type

local table = require "loop.table"
local memoize = table.memoize

local oo = require "oil.oo"
local class = oo.class

local utils = require "oil.kernel.base.Proxies.utils"
local ExHandlerKey = utils.ExHandlerKey
local TimeoutKey = utils.TimeoutKey

local Proxies = class()

function Proxies:__init()
	if self.class == nil then
		local methodmaker = self.invoker
		local methods = memoize(function(operation)
			if type(operation) == "string" then                                       --[[VERBOSE]] verbose:proxies("create proxy operation '",operation,"'")
				local function invoker(proxy, ...)                                      --[[VERBOSE]] verbose:proxies("call to ",operation)
					return self.requester:newrequest{
						reference = proxy.__reference,
						operation = operation,
						n = select("#", ...), ...,
					}
				end
				return methodmaker(invoker, operation)
			end
		end, "v") -- TODO:[maia] can method creation/collection be worse than
		          --             memory leak due to invocation of constantly
		          --             changing methods ?
		function methods:__setexcatch(handler)                                      --[[VERBOSE]] verbose:proxies("setting exception handler ",handler," for proxy ",self)
			local old = rawget(self, ExHandlerKey)
			self[ExHandlerKey] = handler
			return old
		end
		function methods:__settimeout(timeout)                                      --[[VERBOSE]] verbose:proxies("setting timeout ",timeout," for proxy ",self)
			local old = rawget(self, TimeoutKey)
			self[TimeoutKey] = timeout
			return old
		end
		self.class = {
			__index = methods,
			__tostring = function(proxy)
				return proxy.__reference:__tostring()
			end,
		}
	end
end

function Proxies:newproxy(proxy)                                                --[[VERBOSE]] verbose:proxies("create proxy for remote object")
	return setmetatable(proxy, self.class)
end

function Proxies:setexcatch(handler)                                            --[[VERBOSE]] verbose:proxies("setting exception handler ",handler," for all proxies")
	local class = self.class.__index
	local old = rawget(class, ExHandlerKey)
	class[ExHandlerKey] = handler
	return true, old
end

function Proxies:settimeout(timeout)                                            --[[VERBOSE]] verbose:proxies("setting timeout ",timeout," for all proxies")
	local class = self.class.__index
	local old = rawget(class, TimeoutKey)
	class[TimeoutKey] = timeout
	return true, old
end

return Proxies
