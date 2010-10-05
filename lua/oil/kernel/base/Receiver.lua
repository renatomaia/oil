-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Request Acceptor
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local vararg = require "vararg"
local pack = vararg.pack

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"

module(...); local _ENV = _M

class(_ENV)

function _ENV:setup(configs)
	return self.listener:setup(configs)
end

function _ENV:probe(timeout)
	local result, except = self.pending
	if result == nil then
		local listener = self.listener
		repeat
			result, except = listener:getchannel(timeout)
			if result then
				result, except = result:getrequest(0)
				if result then
					self.pending = result
				elseif except.error == "timeout" then
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
	return nil, Exception{
		error = "already started",
		message = "already started",
	}
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
