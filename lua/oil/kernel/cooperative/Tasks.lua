-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : Cooperatibe Threads API Wrapper
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local coroutine = require "coroutine"
local running = coroutine.running
local create = coroutine.create
local yield = coroutine.yield

local oo = require "oil.oo"
local class = oo.class


local Tasks = class()

function Tasks:current()
	return running()
end

function Tasks:start(func, ...)
	return yield("next", create(func), ...)
end

function Tasks:remove(thread)
	return yield("unschedule", thread)
end

return Tasks
