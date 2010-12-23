-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Cooperative Request Acceptor
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local pairs = _G.pairs

local coroutine = require "coroutine"
local newthread = coroutine.create
local running = coroutine.running
local yield = coroutine.yield

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"

local Receiver = require "oil.kernel.base.Receiver"                             --[[VERBOSE]] local verbose = require "oil.verbose"

module(...); local _ENV = _M

class(_ENV, Receiver)

function _ENV:probe(timeout)
	local readers = self.readers
	if readers then
		-- check if any 'channel reader' is ready for execution
		for thread in yield("ready") do
			if readers[thread] then return true end
		end                                                                         --[[VERBOSE]] verbose:acceptor(true, "checking for invocation requests")
		if not timeout or timeout > 0 then                                          --[[VERBOSE]] verbose:acceptor("waiting requests for ",timeout and timeout.." seconds" or "ever")
			-- trap any request processing that might take place during the timeout
			local pending = {}
			local thread = running()
			local dorequest = self.dorequest
			function self:dorequest(request)
				yield("resume", thread, pending)
				return dorequest(self, request)
			end
			-- suspend this thread for the timeout and let other threads execute
			pending = (yield(timeout and "defer" or "suspend", timeout) == pending)
			-- restore original 'dorequest' operation
			self.dorequest = nil
			if self.dorequest ~= dorequest then
				self.dorequest = dorequest
			end                                                                       --[[VERBOSE]] verbose:acceptor(false, pending and "new request received" or "")
			if pending then return true end
		end
		return nil, Exception{
			error = "timeout",
			message = "timeout",
		}
	end
	-- 'CoReceiver' was not started yet, then behave as 'Receiver'
	return Receiver.probe(self, timeout)
end

function _ENV:step(timeout)
	if self.thread then                                                           --[[VERBOSE]] verbose:acceptor(true, "processing one single request")
		local result, except = self:probe(timeout)
		if result then yield("pause") end --[[let other threads execute]]           --[[VERBOSE]] verbose:acceptor(false)
		return result, except
	end
	-- 'CoReceiver' was not started yet, then behave as 'Receiver'
	return Receiver.step(self, timeout)
end

function _ENV:dorequest(request)
	self.dispatcher:dispatch(request)
end

function _ENV:dochannel(channel)
	local result, except
	local listener = self.listener
	repeat
		result, except = channel:getrequest()
		if result then
			local dispatcher = newthread(self.dorequest)                              --[[VERBOSE]] verbose.viewer.labels[dispatcher] = "Dispatcher('"..result.operation.."')"
			yield("resume", dispatcher, self, result)
		end
	until not result
	if except.error ~= "terminated" then
		self:stop(nil, except)
	end
end

function _ENV:dolistener()
	local listener = self.listener
	local readers = {}
	self.readers = readers
	local result, except
	repeat
		result, except = listener:getchannel()
		if result then
			result:acquire()
			local reader = newthread(self.dochannel)                                  --[[VERBOSE]] local address = listener:getaddress(); local host,port = result.socket:getpeername(); verbose.viewer.labels[reader] = "Reader("..host..":"..port.."->"..address.host..":"..address.port..")"
			readers[reader] = result
			yield("resume", reader, self, result)
		end
	until not result
	self:stop(nil, except)
end

function _ENV:start()
	if self.thread == nil then                                                    --[[VERBOSE]] verbose:acceptor("start processing invocation requests")
		-- process any pending request
		local pending = self.pending
		if pending then
			self.pending = nil
			local dispatcher = newthread(self.dorequest)
			yield("resume", dispatcher, self, pending)
		end
		-- start processing new requests
		self.thread = running()
		self.getter = newthread(self.dolistener)                                    --[[VERBOSE]] local address = self.listener:getaddress(); verbose.viewer.labels[self.getter] = "Acceptor("..(address and address.host or "?")..":"..(address and address.port or "?")..")"
		return yield("yield", self.getter, self)
	end
	return nil, Exception{
		error = "badinitialize",
		message = "already started",
	}
end

function _ENV:stop(...)
	local thread = self.thread
	if thread then                                                                --[[VERBOSE]] verbose:acceptor("attempt to stop invocation request processing")
		-- unschedule 'channel readers' and release their channels
		local readers = self.readers
		for reader, channel in pairs(readers) do
			yield("unschedule", reader)
			channel:release()
			readers[reader] = nil
		end
		self.readers = nil
		-- unschedule the getter thread
		yield("unschedule", self.getter)
		self.getter = nil
		-- resume thread that started this 'CoReceiver'
		self.thread = nil
		yield("resume", thread, ...)
		return true
	end
end
