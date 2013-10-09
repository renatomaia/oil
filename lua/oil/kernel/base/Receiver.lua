-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Request Acceptor
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local vararg = require "vararg"
local pack = vararg.pack

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"


local Receiver = class()

function Receiver:setup(configs)
	return self.listener:setup(configs)
end

function Receiver:probe(timeout)                                                    --[[VERBOSE]] verbose:acceptor(true, "checking for invocation requests")
	local result, except = self.pending
	if result == nil then                                                         --[[VERBOSE]] verbose:acceptor("waiting requests for ",timeout and timeout.." seconds" or "ever")
		local listener = self.listener
		repeat
			result, except = listener:getchannel(timeout)
			if result then
				local result, except = result:getrequest(0)
				if result then                                                          --[[VERBOSE]] verbose:acceptor("new request received")
					self.pending = result
				elseif except.error ~= "timeout" and except.error ~= "terminated" then
					if stderr then stderr:write(tostring(except), "\n") end
				end
			end
		until result or except
	end                                                                           --[[VERBOSE]] verbose:acceptor(false)
	return result, except
end

function Receiver:step(timeout)
	local result, except = self:probe(timeout)
	if result then                                                                --[[VERBOSE]] verbose:acceptor(true, "processing one single request")
		self.pending = nil
		self.dispatcher:dispatch(result)                                            --[[VERBOSE]] verbose:acceptor(false, "request completed")
		return true
	end
	return result, except
end

function Receiver:start()
	if self.stopped ~= false then                                                 --[[VERBOSE]] verbose:acceptor(true, "start processing invocation requests")
		self.stopped = false
		repeat
			local result, except = self:step()
			if not result then return nil, except end
		until self.stopped                                                          --[[VERBOSE]] verbose:acceptor(false, "invocation request processing stopped")
		local values = self.stopped
		self.stopped = nil
		return values()
	end
	return nil, Exception{ "already started", error = "badinitialize" }
end

function Receiver:stop(...)
	if self.stopped == false then                                                 --[[VERBOSE]] verbose:acceptor("attempt to stop invocation request processing")
		self.stopped = pack(...)
		return true
	end
	return nil, Exception{ "ORB is not running", error = "badinitialize" }
end

function Receiver:shutdown()                                                        --[[VERBOSE]] verbose:acceptor("attempt to shutdown the ORB")
	return self.listener:shutdown()
end

return Receiver
