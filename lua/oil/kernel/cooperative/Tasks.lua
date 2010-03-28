-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.5
-- Title  : Socket API Wrapper
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local coroutine = require "coroutine"
local running = coroutine.running
local create = coroutine.create
local yield = coroutine.yield

local oo = require "oil.oo"
local class = oo.class

module(..., class)

function current(self)
	return running()
end

function start(self, func, ...)
	return yield("resume", create(func), ...)
end

function remove(self, thread)
	return yield("unschedule", thread)
end
