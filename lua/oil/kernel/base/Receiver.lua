-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Request Acceptor
-- Authors: Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"
local tostring = _G.tostring

local package = require "package"
local io = package.loaded.io
local stderr = io and io.stderr -- only if available

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"


local Receiver = class()

function Receiver:notifyerror(except, tag)
	if stderr ~= nil then
		stderr:write("OiL caught error: [", tag, "] ", tostring(except), "\n")
	end
end

function Receiver:dorequest(request)
	local success, except = self.dispatcher:dispatch(request)
	if not success then
		self:notifyerror(except, "reply")
	end
	except = request.unotifiederror
	if except ~= nil then
		self:notifyerror(except, "dispatch")
	end
end

function Receiver:setup(configs)
	return self.listener:setup(configs)
end

function Receiver:probe(timeout)                                                --[[VERBOSE]] verbose:acceptor(true, "checking for invocation requests")
	local result, except = self.pending
	if result == nil then                                                         --[[VERBOSE]] verbose:acceptor("waiting requests for ",timeout and tostring(timeout).." seconds" or "ever")
		local listener = self.listener
		repeat
			result, except = listener:getchannel(timeout)
			if result then
				result, except = result:getrequest(0)
				if result then                                                          --[[VERBOSE]] verbose:acceptor("new request received")
					self.pending = result
				else
					if except.error ~= "timeout" and except.error ~= "terminated" then
						self:notifyerror(except, "request")
					end
					except = nil
				end
			else
				self:notifyerror(except, "connection")
			end
		until result or except
	end                                                                           --[[VERBOSE]] verbose:acceptor(false)
	return result, except
end

function Receiver:step(timeout)
	local result, except = self:probe(timeout)
	if result then                                                                --[[VERBOSE]] verbose:acceptor(true, "processing one single request")
		self.pending = nil
		self:dorequest(result)                                                      --[[VERBOSE]] verbose:acceptor(false, "request completed")
		return true
	end
	return result, except
end

function Receiver:start()
	if not self.started then                                                      --[[VERBOSE]] verbose:acceptor(true, "start processing invocation requests")
		self.started = true
		repeat until not self:step() or not self.started
		self.started = false                                                        --[[VERBOSE]] verbose:acceptor(false, "invocation request processing stopped")
		return true
	end
	return nil, Exception{ "already started", error = "badinitialize" }
end

function Receiver:stop()
	if self.started then                                                          --[[VERBOSE]] verbose:acceptor("attempt to stop invocation request processing")
		self.started = false
		return true
	end
	return nil, Exception{ "ORB is not running", error = "badinitialize" }
end

function Receiver:shutdown()                                                    --[[VERBOSE]] verbose:acceptor("attempt to shutdown the ORB")
	return self.listener:shutdown()
end

return Receiver
