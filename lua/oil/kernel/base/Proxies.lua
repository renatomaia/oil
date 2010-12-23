-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Remote Object Proxies
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local select = _G.select
local setmetatable = _G.setmetatable

local tabop = require "loop.table"
local memoize = tabop.memoize

local oo = require "oil.oo"
local class = oo.class

module(...); local _ENV = _M

class(_ENV)

function _ENV:__init()
	if self.class == nil then
		local methodmaker = self.invoker
		self.class = {
			__index = memoize(function(operation)                                     --[[VERBOSE]] verbose:proxies("create proxy operation '",operation,"'")
				local function invoker(proxy, ...)                                      --[[VERBOSE]] verbose:proxies("call to ",operation)
					return self.requester:newrequest{
						reference = proxy.__reference,
						operation = operation,
						n = select("#", ...), ...,
					}
				end
				return methodmaker(invoker, operation)
			end, "v"), -- TODO:[maia] can method creation/collection be worse than
			           --             memory leak due to invocation of constantly
			           --             changing methods ?
			__tostring = function(proxy)
				return proxy.__reference:__tostring()
			end,
		}
	end
end

function _ENV:newproxy(proxy)                                                   --[[VERBOSE]] verbose:proxies("create proxy for remote object")
	return setmetatable(proxy, self.class)
end

function _ENV:excepthandler(handler)                                            --[[VERBOSE]] verbose:proxies("setting exception handler for proxies")
	self.class.__exceptions = handler
	return true
end
