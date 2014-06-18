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
local copy = table.copy
local memoize = table.memoize

local oo = require "oil.oo"
local class = oo.class

local utils = require "oil.kernel.base.Proxies.utils"
local keys = utils.keys
local SecurityKey = keys.security
local SSLKey = keys.ssl

local PredefinedMethods = {}
for name, key in pairs(keys) do
	PredefinedMethods["__set"..name] = function (self, value)                     --[[VERBOSE]] verbose:proxies("setting ",name," ",value," for proxy ",self)
		local old = rawget(self, key)
		self[key] = value
		return old
	end
end

local Proxies = class()

function Proxies:__init()
	if self.class == nil then
		local methodmaker = self.invoker
		local methods = memoize(function(operation)
			if type(operation) == "string" then                                       --[[VERBOSE]] verbose:proxies("create proxy operation '",operation,"'")
				local function invoker(proxy, ...)                                      --[[VERBOSE]] verbose:proxies("call to ",operation)
					return self.requester:newrequest{
						security = proxy[SecurityKey],
						ssl = proxy[SSLKey],
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
		copy(PredefinedMethods, methods)
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

for name, key in pairs(keys) do
	Proxies["set"..name] = function (self, value)                                 --[[VERBOSE]] verbose:proxies("setting ",name," ",value," for all proxies")
		local class = self.class.__index
		local old = rawget(class, key)
		class[key] = value
		return true, old
	end
end

return Proxies
