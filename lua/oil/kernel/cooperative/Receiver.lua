-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Cooperative Request Acceptor
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local pairs = _G.pairs
local tostring = _G.tostring
local stderr = _G.io and _G.io.stderr -- only if available

local coroutine = require "coroutine"
local newthread = coroutine.create
local running = coroutine.running
local yield = coroutine.yield

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"
local Receiver = require "oil.kernel.base.Receiver"

local CoReceiver = class({}, Receiver)

function CoReceiver:setup(configs)
	local result, errmsg = Receiver.setup(self, configs)
	if result and not self.started then                                           --[[VERBOSE]] verbose:acceptor("setting up processing invocation requests in a new thread")
		self.started = {}
		local acceptor = newthread(self.dolistener)                                 --[[VERBOSE]] local address = self.listener:getaddress(); verbose.viewer.labels[acceptor] = "Acceptor("..(address and address.host or "?")..":"..(address and address.port or "?")..")"
		yield("last", acceptor, self)
	end
	return result, errmsg
end

function CoReceiver:shutdown(...)
	if self.started ~= nil then                                                   --[[VERBOSE]] verbose:acceptor("finishing processing invocation requests in a new thread")
		self.started = nil
		return Receiver.shutdown(self, ...)
	end
	return nil, Exception{ "setup missing", error = "badsetup" }
end

function CoReceiver:probe(timeout)
	if self.thread == nil then
		return Receiver.probe(self, timeout)
	end
	return nil, Exception{ "already started", error = "badsetup" }
end

function CoReceiver:step(timeout)
	if self.thread == nil then
		return Receiver.step(self, timeout)
	end
	return true
end

function CoReceiver:dochannel(channel)
	local result, except
	local listener = self.listener
	repeat
		result, except = channel:getrequest()
		if result then
			local dispatcher = newthread(self.dorequest)                              --[[VERBOSE]] verbose.viewer.labels[dispatcher] = "Dispatcher("..result.operation..")"
			yield("last", dispatcher, self, result)
		end
	until not result
	channel:close("incoming")
	if except.error ~= "terminated" then
		self:notifyerror("request", except)
	end
end

function CoReceiver:dolistener()
	local listener = self.listener
	local result, except
	repeat
		result, except = listener:getchannel()
		if result then
			result:acquire()
			local reader = newthread(self.dochannel)                                  --[[VERBOSE]] local host,port = result.socket:getpeername(); verbose.viewer.labels[reader] = "Reader("..host..":"..port..")"
			yield("last", reader, self, result)
		end
	until not result
	if except.error ~= "terminated" then
		self:notifyerror("connection", except)
	end
end

function CoReceiver:start()
	local started = self.started
	if started ~= nil then                                                        --[[VERBOSE]] verbose:acceptor("ignoring attempt to start processing invocation requests")
		started[running()] = true
		yield("suspend")
		return true
	end
	return nil, Exception{ "setup missing", error = "badsetup" }
end

function CoReceiver:stop()
	local started = self.started
	if started ~= nil then                                                        --[[VERBOSE]] verbose:acceptor("ignoring attempt to stop processing invocation request")
		for thread in pairs(started) do
			yield("schedule", thread)
			started[thread] = nil
		end
		return true
	end
	return nil, Exception{ "setup missing", error = "badsetup" }
end

return CoReceiver
