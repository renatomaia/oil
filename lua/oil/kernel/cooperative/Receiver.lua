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
		end
		if not timeout or timeout > 0 then
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
			end
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
	if self.thread then
		local result, except = self:probe(timeout)
		if result then yield("pause") end -- let other threads execute
		return result, except
	end
	-- 'CoReceiver' was not started yet, then behave as 'Receiver'
	return Receiver.step(self, timeout)
end

function _ENV:dorequest(request)
	self.dispatcher:dispatch(request)
	local result, except = request:sendreply()
	if not result then
		self:stop(nil, except)
	end
end

function _ENV:dochannel(channel)
	local result, except
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
			local reader = newthread(self.dochannel)                                  --[[VERBOSE]] verbose.viewer.labels[reader] = "Reader(".._G.tostring(result).."->"..self.listener.configs.host..":"..self.listener.configs.port..")"
			readers[reader] = result
			yield("resume", reader, self, result)
		end
	until not result
	self:stop(nil, except)
end

function _ENV:start()
	if self.thread == nil then
		-- process any pending request
		local pending = self.pending
		if pending then
			self.pending = nil
			local dispatcher = newthread(self.dorequest)
			yield("resume", dispatcher, self, pending)
		end
		-- start processing new requests
		self.thread = running()
		self.acceptor = newthread(self.dolistener)                                  --[[VERBOSE]] verbose.viewer.labels[self.acceptor] = "Acceptor("..self.listener.configs.host..":"..self.listener.configs.port..")"
		return yield("yield", self.acceptor, self)
	end
	return nil, Exception{
		error = "already started",
		message = "already started",
	}
end

function _ENV:stop(...)
	local thread = self.thread
	if thread then
		-- unschedule 'channel readers' and release their channels
		local readers = self.readers
		for reader, channel in pairs(readers) do
			yield("unschedule", reader)
			channel:release()
			readers[reader] = nil
		end
		self.readers = nil
		-- unschedule the acceptor thread
		yield("unschedule", self.acceptor)
		self.acceptor = nil
		-- resume thread that started this 'CoReceiver'
		self.thread = nil
		yield("resume", thread, ...)
		return true
	end
end
