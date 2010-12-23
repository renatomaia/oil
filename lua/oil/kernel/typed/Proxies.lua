-- Project: OiL - ORB in Lua
-- Release: 0.5
-- Title  : Remote Object Proxies
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local select = _G.select
local setmetatable = _G.setmetatable
local rawget = _G.rawget
local rawset = _G.rawset

local tabop = require "loop.table"
local clear = tabop.clear
local memoize = tabop.memoize

local oo = require "oil.oo"
local class = oo.class

module(...); local _ENV = _M

class(_ENV)

function _ENV:__init()
	if self.class == nil then
		local methodmaker = self.invoker
		local OpCache = {
			__index = function(cache, field)
				local operation = self.indexer:valueof(cache.__type, field)
				if operation then                                                       --[[VERBOSE]] verbose:proxies("create proxy operation '",field,"'")
					local function invoker(proxy, ...)                                    --[[VERBOSE]] verbose:proxies("call to ",operation, ...)
						return self.requester:newrequest{
							reference = proxy.__reference,
							operation = operation,
							n = select("#", ...), ...,
						}
					end
					invoker = methodmaker(invoker, operation)
					cache[field] = invoker
					return invoker                                                        --[[VERBOSE]] else verbose:proxies("indexed operation '",field,"' does not exist")
				end
			end
		}
		local function proxytostring(proxy)
			return proxy.__reference:__tostring()
		end
		local function proxynarrow(proxy, type)
			return self:newproxy{
				__reference = proxy.__reference,
				__type = type,
			}
		end
		self.class = memoize(function(type)
			local cache = setmetatable({}, OpCache)
			local updater = {}
			function updater:notify()
				local handler = rawget(cache, "__exceptions")
				clear(cache)
				cache.__index = cache
				cache.__type = type
				cache.__tostring = proxytostring
				cache.__narrow = proxynarrow
				cache.__exceptions = handler
			end
			updater:notify()
			if type.observer then
				rawset(type.observer, cache, updater)
			end
			return cache
		end, "k")
	end
end

function _ENV:newproxy(proxy)                                                   --[[VERBOSE]] verbose:proxies(true, "create proxy for remote object")
	local type = proxy.__type or proxy.__reference:gettype()
	local result, except = self.types:resolve(type)
	if result then                                                                --[[VERBOSE]] verbose:proxies("using interface ",result.repID)
		result, except = setmetatable(proxy, self.class[result]), nil
	end                                                                           --[[VERBOSE]] verbose:proxies(false)
	return result, except
end

function _ENV:excepthandler(handler, type)                                      --[[VERBOSE]] verbose:proxies("setting exception handler for proxies of ",type)
	local result, except = self.types:resolve(type)
	if result then
		local class = self.class[result]
		class.__exceptions = handler
		result, except = true, nil
	end
	return result, except
end

--------------------------------------------------------------------------------

--[[VERBOSE]] local select = _G.select
--[[VERBOSE]] local type = _G.type
--[[VERBOSE]] function verbose.custom:proxies(...)
--[[VERBOSE]] 	local params
--[[VERBOSE]] 	for i = 1, select("#", ...) do
--[[VERBOSE]] 		local value = select(i, ...)
--[[VERBOSE]] 		local type = type(value)
--[[VERBOSE]] 		if type == "string" then
--[[VERBOSE]] 			if params then
--[[VERBOSE]] 				self.viewer.output:write(params)
--[[VERBOSE]] 				params = ", "
--[[VERBOSE]] 				self.viewer:write((value:gsub("[^%w%p%s]", "?")))
--[[VERBOSE]] 			else
--[[VERBOSE]] 				self.viewer.output:write(value)
--[[VERBOSE]] 			end
--[[VERBOSE]] 		elseif not params and type == "table" and
--[[VERBOSE]] 		       value._type == "operation" then
--[[VERBOSE]] 			params = "("
--[[VERBOSE]] 			self.viewer.output:write(value.name)
--[[VERBOSE]] 		else
--[[VERBOSE]] 			if params then
--[[VERBOSE]] 				self.viewer.output:write(params)
--[[VERBOSE]] 				params = ", "
--[[VERBOSE]] 			end
--[[VERBOSE]] 			self.viewer:write(value)
--[[VERBOSE]] 		end
--[[VERBOSE]] 	end
--[[VERBOSE]] 	if params then
--[[VERBOSE]] 		self.viewer.output:write(params == "(" and "()" or ")")
--[[VERBOSE]] 	end
--[[VERBOSE]] end
