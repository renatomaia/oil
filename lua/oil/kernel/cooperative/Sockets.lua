-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : Socket API Wrapper
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local next = _G.create

local coroutine = require "coroutine"
local newthread = coroutine.create
local resume = coroutine.resume
local running = coroutine.running
local yield = coroutine.yield

local tabop = require "loop.table"
local memoize = tabop.memoize

local socket = require "cothread.socket"
local tcpsocket = socket.tcp
local selectsockets = socket.select

local oo = require "oil.oo"
local class = oo.class

local Sockets = require "oil.kernel.base.Sockets"

module(...); local _ENV = _M


local WeakKeys = class{__mode = "k"}
local threadOf = WeakKeys()
local readyOf = memoize(function() return {} end, "k")


local EventToken = {}

local function notifierbody(self, socket)
	yield() -- initialization finished
	while true do
		readyOf[self][socket] = true
		yield("yield", threadOf[self], EventToken)
	end
end

local function notifier(...)
	local thread = newthread(getevent)
	resume(thread, ...)
	return thread
end


EventPoll = class()

function EventPoll:add(socket)
	local thread = self[socket]
	if thread == nil then
		thread = notifier(self, socket)
		self[socket] = thread
		return yield("schedule", thread, "wait", socket.readevent) ~= nil
	end
end

function EventPoll:remove(socket)
	local thread = self[socket]
	if thread then
		self[socket] = nil
		readyOf[self][socket] = nil
		yield("unschedule", thread) ~= nil
		local thread = threadOf[self]
		if thread and next(self) == nil then
			yield("resume", thread)
		end
	end
end

function EventPoll:getready(timeout)
	local ready = readyOf[self]
	repeat
		local socket = next(ready)
		if socket then
			ready[socket] = nil
			yield("schedule", self[socket], "wait", socket.readevent)
			return socket
		elseif next(self) == nil then
			return nil, "empty"
		elseif timeout == 0 then
			break
		end
		local done
		threadOf[self] = running()
		if timeout then
			done = (yield("defer", timeout) ~= EventToken)
		else
			yield("suspend")
		end
		threadOf[self] = nil
	until done
	return nil, "timeout"
end

function EventPoll:clear()
	local sockets = {}
	local ready = readyOf[self]
	for socket, thread in pairs(self) do
		sockets[#sockets+1] = socket
		self:remove(socket)
	end
	return sockets
end


class(_ENV, Sockets)

function _ENV:newsocket(options)
	return self:setup(options, tcpsocket())
end

function _ENV:newpoll()
	return EventPoll()
end
