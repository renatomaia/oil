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

local Request = require "oil.protocol.Request"



local Listener = class{ Request = Request }

function Listener:__init()
	self.sock2channel = memoize(function(socket)
		return self.Channel{
			socket = socket,
			context = self,
			access = self.access,
			listener = self,
		}
	end)
end

function Listener:setup(configs)
	if self.configs == nil then                                                   --[[VERBOSE]] verbose:listen("setting server up with configs ",configs)
		self.configs = configs -- delay actual initialization (see 'getaccess')
		return true
	end
	return nil, Exception{ "already started", error = "badsetup" }
end

function Listener:getaccess(probe)
	local result, except = self.access
	if result == nil and not probe then
		result = self.configs
		if result == nil then
			except = Exception{ "setup missing", error = "badsetup" }
		else                                                                        --[[VERBOSE]] verbose:listen("creating new access point")
			result, except = self.channels:newaccess(result)
			if result ~= nil then
				self.access = result
				--local address = result:address()
				--if address then
				--	self.configs.address = address
				--end
			end
		end
	end
	return result, except
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

function Listener:getchannel(timeout)                                           --[[VERBOSE]] verbose:listen(true, "get channel with new request")
	local result, except = self:getaccess()
	if result ~= nil then
		result, except = result:accept(timeout)
		if result ~= nil then
			result, except = self.sock2channel[result], nil
		end
	end                                                                           --[[VERBOSE]] verbose:listen(false, "channel retrieval ",result and "succeeded" or "failed")
	return result, except
end

function Listener:shutdown()
	local access, except = self:getaccess()
	if not access then
		return nil, except
	end                                                                           --[[VERBOSE]] verbose:listen(true, "shutting down server")
	access:close()
	local excepts = {}
	local sock2channel = self.sock2channel
	for socket, channel in pairs(sock2channel) do                                 --[[VERBOSE]] verbose:listen("closing channel")
		local closed, except = channel:close()
		if not closed then                                                          --[[VERBOSE]] verbose:listen("shutdown failed while closing channel: ",except)
			excepts[#excepts+1] = except
		end
	end
	self.access = nil
	self.address = nil
	self.configs = nil                                                            --[[VERBOSE]] verbose:listen(false, "shutdown initialized")
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
