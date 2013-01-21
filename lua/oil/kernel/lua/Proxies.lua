-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Remote Object Proxies
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local ipairs = _G.ipairs
local select = _G.select

local oo = require "oil.oo"
local class = oo.class
local rawnew = oo.rawnew

local utils = require "oil.kernel.base.Proxies.utils"
local assert = utils.assertresults

local Proxies = require "oil.kernel.base.Proxies"

local LuaProxies = class{ newproxy = Proxies.newproxy }

function LuaProxies:__init()
	if self.class == nil then
		local ops = class()
		for _, field in ipairs{
			"tostring",
			"unm",
			"len",
			"add",
			"sub",
			"mul",
			"div",
			"mod",
			"pow",
			"eq",
			"lt",
			"le",
			"concat",
			"call",
			"index",
			"newindex",
		} do
			ops["__"..field] = function(proxy, ...)                                   --[[VERBOSE]] verbose:proxies("call to ",field)
				local request = self.requester:newrequest{
					reference = proxy.__reference,
					operation = field,
					n = select("#", ...), ...,
				}
				return assert(proxy, field, request:getreply())
			end
		end
		self.class = ops
	end
end

return LuaProxies
