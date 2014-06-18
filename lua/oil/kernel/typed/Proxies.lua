-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Remote Object Proxies
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local rawget = _G.rawget
local rawset = _G.rawset
local select = _G.select
local setmetatable = _G.setmetatable
local type = _G.type

local table = require "loop.table"
local clear = table.clear
local memoize = table.memoize

local asserter = require "oil.assert"
local assert = asserter.results

local oo = require "oil.oo"
local class = oo.class

local utils = require "oil.kernel.base.Proxies.utils"
local keys = utils.keys
local SecurityKey = keys.security
local SSLKey = keys.ssl

local ProxyMethods = {}
for name, key in pairs(keys) do
	ProxyMethods["__set"..name] = function (self, value)                          --[[VERBOSE]] verbose:proxies("setting ",name," for proxy ",self)
		local old = rawget(self, key)
		self[key] = value
		return true, old
	end
end


local Proxies = class()

function Proxies:__init()
	self.global = self.global or {}
	if self.class == nil then
		local methodmaker = self.invoker
		local OpCache = {
			__index = function(cache, field)
				if type(field) == "string" then
					local operation = self.indexer:valueof(cache.__type, field)
					if operation then                                                     --[[VERBOSE]] verbose:proxies("create proxy operation '",field,"'")
						local function invoker(proxy, ...)                                  --[[VERBOSE]] verbose:proxies("call to ",operation, ...)
							return self.requester:newrequest{
								security = proxy[SecurityKey],
								ssl = proxy[SSLKey],
								reference = proxy.__reference,
								operation = operation,
								n = select("#", ...), ...,
							}
						end
						invoker = methodmaker(invoker, operation)
						cache[field] = invoker
						return invoker                                                      --[[VERBOSE]] else verbose:proxies("indexed operation '",field,"' does not exist")
					end
				else
					return self.global[field]
				end
			end
		}
		local function proxytostring(proxy)
			return assert(proxy.__reference:__tostring())
		end
		local function proxynarrow(proxy, type)
			return assert(self:newproxy{
				__reference = proxy.__reference,
				__type = type,
			})
		end
		self.class = memoize(function(type)
			local cache = setmetatable({}, OpCache)
			local updater = {}
			function updater:notify()
				local backup = {}
				for name, key in pairs(keys) do
					backup[key] = rawget(cache, key)
				end
				clear(cache)
				cache.__index = cache
				cache.__type = type
				cache.__tostring = proxytostring
				cache.__narrow = proxynarrow
				for name, method in pairs(ProxyMethods) do
					cache[name] = method
				end
				for name, key in pairs(keys) do
					cache[key] = backup[key] --or self[key]
				end
			end
			updater:notify()
			if type.observer then
				rawset(type.observer, cache, updater)
			end
			return cache
		end, "k")
	end
end

function Proxies:newproxy(proxy)                                                --[[VERBOSE]] verbose:proxies(true, "create proxy for remote object")
	local type = proxy.__type or proxy.__reference:gettype()
	local result, except = self.types:resolve(type)
	if result then                                                                --[[VERBOSE]] verbose:proxies("using interface ",result.repID)
		result, except = setmetatable(proxy, self.class[result]), nil
	end                                                                           --[[VERBOSE]] verbose:proxies(false)
	return result, except
end

for name, key in pairs(keys) do
	Proxies["set"..name] = function (self, value, type)                           --[[VERBOSE]] verbose:proxies("setting ",name," ",value," for all proxies")
		local scope = self.global
		if type ~= nil then
			local result, except = self.types:resolve(type)
			if result == nil then
				return nil, except
			end
			scope = self.class[result]
		end
		local old = rawget(scope, key)
		scope[key] = value
		return true, old
	end
end


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


return Proxies