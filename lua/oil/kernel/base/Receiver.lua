-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Request Acceptor
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local varargs = require "varargs"
local pack = varargs.pack

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"
local Timeout = Exception.Timeout

module(...); local _ENV = _M

class(_ENV)

function _ENV:setup(configs)
	return self.listener:setup(configs)
end

function _ENV:probe(timeout)
	local result, except = self.pending
	if not result then
		local listener = self.listener
		repeat
			result, except = listener:getchannel(timeout)
			if result then
				result, except = result:getrequest(0)
				if result then
					self.pending = result
				elseif except == Timeout then
					except = nil
				end
			end
		until result or except
	end
	return result, except
end

function _ENV:step(timeout)
	local result, except = self:probe(timeout)
	if result then
		self.pending = nil
		self.dispatcher:dispatch(result)
		result, except = result:sendreply()
	end
	return result, except
end

function _ENV:start()
	if self.stopped ~= false then
		self.stopped = false
		repeat
			local result, except = self:step()
			if not result then return nil, except end
		until self.stopped
		local values = self.stopped
		self.stopped = nil
		return values()
	end
	return nil, Exception.AlreadyStarted
end

function _ENV:stop(...)
	if self.stopped == false then
		self.stopped = pack(...)
		return true
	end
end

function _ENV:shutdown()
	return self.listener:shutdown()
end
