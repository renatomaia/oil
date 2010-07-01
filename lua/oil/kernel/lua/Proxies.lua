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
-- Release: 0.5                                                               --
-- Title  : Remote Object Proxies                                             --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- proxies:Facet
-- 	proxy:object proxyto(reference:table)
--
-- invoker:Receptacle
-- 	[results:object], [except:table] invoke(reference, operation, args...)
--------------------------------------------------------------------------------

local _G = require "_G"
local ipairs = _G.ipairs

local oo = require "oil.oo"
local class = oo.class
local rawnew = oo.rawnew

local utils = require "oil.kernel.base.Proxies.utils"
local assert = utils.assertresults

local Proxies = require "oil.kernel.base.Proxies"                               --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.kernel.lua.Proxies"

class(_M, Proxies)

function __new(self, ...)
	self = rawnew(self, ...)
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
			ops["__"..field] = function(proxy, ...)                                      --[[VERBOSE]] verbose:proxies("call to ",field," ", ...)
				local request = self.requester:newrequest(proxy, field, ...)
				return assert(proxy, operation, request:results())
			end
		end
		self.class = ops
	end
	return self
end

