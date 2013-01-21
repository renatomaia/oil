-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : Socket API Wrapper
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local error = _G.error
local pairs = _G.pairs
local next = _G.next

local coroutine = require "coroutine"
local newthread = coroutine.create
local resume = coroutine.resume
local running = coroutine.running
local yield = coroutine.yield

local table = require "loop.table"
local memoize = table.memoize

local cothread = require "cothread"
cothread.plugin(require "cothread.plugin.socket")

local socket = require "cothread.socket"
local tcpsocket = socket.tcp
local selectsockets = socket.select
local cosocket = socket.cosocket

local EventPoll = require "cothread.EventPoll"

local oo = require "oil.oo"
local class = oo.class
local rawnew = oo.rawnew

local Sockets = require "oil.kernel.base.Sockets"



local function findupvalue(func, name)
	local debug = require "debug"
	local math = require "math"
	for i = 1, math.huge do
		local upname, value = debug.getupvalue(func, i)
		if upname == nil then break end
		if upname == name then return value end
	end
	error("upvalue "..name.." not found!")
end
local CoSocket = findupvalue(socket.cosocket, "CoSocket")
function CoSocket:settimelimit(timestamp)
	self:settimeout(timestamp, "isTimestamp")
end


local Poll = class()

function Poll:__init()
	if self.wrapperOf == nil then self.wrapperOf = {} end
	if self.poll == nil then self.poll = EventPoll() end
end

function Poll:add(wrapper, ready)
	local socket = wrapper.__object
	self.wrapperOf[socket] = wrapper
	local poll = self.poll
	poll:add(socket, "r")
	if ready then
		yield("next", poll.thread, socket, "r") -- simulate that socket is ready
	end
end

function Poll:remove(wrapper)
	local socket = wrapper.__object
	self.wrapperOf[socket] = nil
	return self.poll:remove(socket, "r")
end

function Poll:clear()
	local wrapperOf = self.wrapperOf
	local sockets = self.poll:clear().r
	local results = {}
	for socket in pairs(sockets) do
		results[wrapperOf[socket]] = true
		wrapperOf[socket] = nil
	end
	return results
end

function Poll:getready(timeout)
	local socket, errmsg = self.poll:getready()
	if socket == nil then return nil, errmsg end
	return self.wrapperOf[socket]
end


local Sockets = class({}, Sockets)

function Sockets:newsocket(options)
	return self:setoptions(options, tcpsocket())
end

function Sockets:newpoll()
	return Poll()
end

return Sockets
