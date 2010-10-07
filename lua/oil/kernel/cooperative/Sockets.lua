-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : Socket API Wrapper
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local pairs = _G.pairs
local next = _G.next

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



local function findupvalue(package, name)
	local debug = require "debug"
	local math = require "math"
	for _, func in pairs(package) do
		if type(func) == "function" then
			for i = 1, math.huge do
				local upname, value = debug.getupvalue(func, i)
				if upname == nil then break end
				if upname == name then return value end
			end
		end
	end
	error("upvalue "..name.." not found!")
end
local watchsocket = findupvalue(socket, "watchsocket")
local forgetsocket = findupvalue(socket, "forgetsocket")
local readingsockets = findupvalue(socket, "reading")

local indexFunc = _G.getmetatable(findupvalue(socket, "WrapperOf")).__index
local funcUpVal = findupvalue({indexFunc}, "func")
local CoSocket = findupvalue({funcUpVal}, "CoSocket")
function CoSocket:settimelimit(timestamp)
	self:settimeout(timestamp, "isTimestamp")
end


module(...); local _ENV = _M


local WeakKeys = class{__mode = "k"}
local threadOf = WeakKeys()
local readyOf = memoize(function() return {} end, "k")


local EventToken = {}

local function notifierbody(self, socket)
	yield() -- initialization finished
	while true do
		forgetsocket(socket.__object, readingsockets)
		readyOf[self][socket] = true
		yield("yield", threadOf[self], EventToken)
	end
end

local function notifier(...)
	local thread = newthread(notifierbody)
	resume(thread, ...)
	return thread
end


EventPoll = class()

function EventPoll:add(socket)
	local thread = self[socket]
	if thread == nil then
		thread = notifier(self, socket)                                             --[[VERBOSE]] verbose.viewer.labels[thread] = "SocketWatcher(".._G.tostring(socket)..")"
		self[socket] = thread
		watchsocket(socket.__object, readingsockets) -- register socket for network event watch
		return yield("schedule", thread, "wait", socket.readevent) ~= nil
	end
end

function EventPoll:remove(socket)
	local thread = self[socket]
	if thread then
		self[socket] = nil
		readyOf[self][socket] = nil
		yield("unschedule", thread)
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
			watchsocket(socket.__object, readingsockets) -- register socket for network event watch
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
	return self:setoptions(options, tcpsocket())
end

function _ENV:newpoll()
	return EventPoll()
end
