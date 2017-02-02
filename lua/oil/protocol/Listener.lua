-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Server-side LuDO Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local pairs = _G.pairs
local select = _G.select
local tonumber = _G.tonumber

local array = require "table"
local unpack = array.unpack

local table = require "loop.table"
local memoize = table.memoize

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"



local Listener = class()

function Listener:setup(configs)                                                --[[VERBOSE]] verbose:listen("setting server up with configs ",configs)
	if self.access == nil then                                                    --[[VERBOSE]] verbose:listen("creating new access point")
		local result, except = self.channels:newaccess(configs)
		if result ~= nil then
			self.access = result
			--local address = result:address()
			--if address then
			--	self.configs.address = address
			--end
			return true
		end
		return nil, except
	end
	return nil, Exception{ "already started", error = "badsetup" }
end

function Listener:getaccess()
	local access = self.access
	if access ~= nil then
		return access
	end
	return nil, Exception{ "setup missing", error = "badsetup" }
end

function Listener:getaddress(probe)
	local result, except = self.address
	if result == nil then
		result, except = self:getaccess(probe)
		if result ~= nil then
			local addresses
			result, except = result:address()
			if result ~= nil then
				self.address = result
			end
		end
	end
	return result, except
end

function Listener:getchannel(acquire, timeout)                                  --[[VERBOSE]] verbose:listen(true, "get channel with new request")
	local result, except = self:getaccess()
	if result ~= nil then
		local port = result
		result, except = port:accept(acquire, timeout)
	end                                                                           --[[VERBOSE]] verbose:listen(false, "channel retrieval ",result and "succeeded" or "failed")
	return result, except
end

local function dummy() end
function Listener:ichannels()
	local access = self:getaccess()
	if access ~= nil then
		return access:ichannels()
	end
	return dummy
end

function Listener:shutdown()
	local access, except = self:getaccess()
	if not access then
		return nil, except
	end                                                                           --[[VERBOSE]] verbose:listen(true, "shutting down listener")
	local channels = access:close()
	local excepts = {}
	for channel in pairs(channels) do                                             --[[VERBOSE]] verbose:listen("closing channel")
		local closed, except = channel:close("incoming")
		if not closed then                                                          --[[VERBOSE]] verbose:listen("shutdown failed while closing channel: ",except)
			excepts[#excepts+1] = except
		end
	end
	self.access = nil
	self.address = nil
	self.configs = nil                                                            --[[VERBOSE]] verbose:listen(false, "listener shutdown concluded")
	if #excepts > 0 then
		return nil, Exception{
			"unable to close all incoming connections",
			error = "badshutdown",
			excepts = excepts,
		}
	end
	return true
end

return Listener
