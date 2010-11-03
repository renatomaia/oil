-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Server-side LuDO Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local select = _G.select
local tonumber = _G.tonumber
local unpack = _G.unpack

local tabops = require "loop.table"
local memoize = tabops.memoize

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"

local Request = require "oil.protocol.Request"
local LuDOChannel = require "oil.ludo.Channel"



local ServerRequest = class({}, Request)

function ServerRequest:__init()
	local channel = self.channel
	if channel then
		channel[self.request_id] = self
		channel.pending = 1 + (channel.pending or 0)
	end
end

function ServerRequest:finish()
	local channel = self.channel
	if channel then
		self.channel = nil
		channel[self.request_id] = nil
		local pending = channel.pending
		channel.pending = pending-1
		if channel.closing and pending <= 1 then                                    --[[VERBOSE]] verbose:listen "all pending requests replied, connection being closed"
			return channel:close()
		end
	end
	return true
end

function ServerRequest:sendreply()                                              --[[VERBOSE]] verbose:listen(true, "replying for request ",self.request_id," to object ",self.objectkey,":",self.operation)
	local channel = self.channel
	channel:trylock("write")
	local result, except = channel:sendreply(self)
	channel:freelock("write")
	if result then
		result, except = self:finish()
	end                                                                           --[[VERBOSE]] verbose:listen(false)
	return result, except
end



local Listener = class{ Request = ServerRequest }

function Listener:__init()
	self.sock2channel = memoize(function(socket)
		return self.Channel{
			codec = self.codec,
			socket = socket,
			listener = self,
		}
	end, "k")
end

function Listener:setup(configs)
	if self.configs == nil then                                                   --[[VERBOSE]] verbose:listen("setting server up with configs ",configs)
		self.configs = configs -- delay actual initialization (see 'getaccess')
		return true
	end
	return nil, Exception{
		error = "already started",
		message = "already started",
	}
end

function Listener:getaccess(probe)
	local result, except = self.access
	if result == nil and not probe then
		result = self.configs
		if result == nil then
			except = Exception{
				error = "terminated",
				message = "terminated",
			}
		else                                                                        --[[VERBOSE]] verbose:listen("creating new access point")
			result, except = self.channels:newaccess(result)
			if result ~= nil then
				self.access = result
				local host, port, addresses = result:address()
				self.configs.host = host
				self.configs.port = port
				self.configs.addresses = addresses
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
			result, except, addresses = result:address()
			if result ~= nil then
				result, except = {
					host = result,
					port = except,
					addresses = addresses,
				}
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
	local sock2channel = self.sock2channel
	for _, socket in ipairs(access:close()) do
		local channel = sock2channel[socket]
		if channel.pending > 0 then                                                 --[[VERBOSE]] verbose:listen("channel in use, marked to be closed")
			channel.closing = true
		else                                                                        --[[VERBOSE]] verbose:listen("closing channel")
			local closed, except = channel:close()
			if not closed then                                                        --[[VERBOSE]] verbose:listen(false, "shutdown failed while closing channel")
				return nil, except
			end
		end
	end
	self.access = nil
	self.address = nil
	self.configs = nil                                                            --[[VERBOSE]] verbose:listen(false, "shutdown initialized")
	return true
end

return Listener
