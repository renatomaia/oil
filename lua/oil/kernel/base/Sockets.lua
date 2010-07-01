-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : Socket API Wrapper
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local math = require "math"
local max = math.max

local table = require "table"
local remove = table.remove

local socket = require "socket.core"
local tcpsocket = socket.tcp
local selectsockets = socket.select
local gettime = socket.gettime

local ArraySet = require "loop.collection.ArraySet"
local add = ArraySet.add
local remove = ArraySet.remove

local oo = require "oil.oo"
local class = oo.class
local rawnew = oo.rawnew

do -- add new operation 'settimelimit' on sockets
	local socket = tcpsocket()
	getmetatable(socket).__index.settimelimit = function(self, timeout)
		if timeout and timeout >= 0 then timeout = max(0, timeout-gettime()) end
		return self:settimeout(timeout)
	end
	socket:close()
end

module(...); local _ENV = _M


EventPoll = class()

function EventPoll:__init()
	self.ready = {}
end

function EventPoll:add(socket)
	return add(self, socket) ~= nil
end

function EventPoll:remove(socket)
	if remove(self, socket) ~= nil then
		local ready = self.ready
		if ready and ready[socket] ~= nil then
			for i = 1, #ready do
				if ready[i] == socket then
					ready[socket] = nil
					remove(ready, i)
					return true
				end
			end
		end
		return true
	end
	return false
end

function EventPoll:getready(timeout)
	local ready = self.ready
	repeat
		local count = #ready
		if count > 0 then
			local socket = ready[count]
			ready[count] = nil
			ready[socket] = nil
			return socket
		end
		if #self == 0 then return nil, "empty" end
		if timeout and timeout >= 0 then timeout = max(0, timeout-gettime()) end
		local recvok, _, errmsg = selectsockets(self, nil, timeout)
		if #recvok > 0 then self.ready = recvok end
	until errmsg == "timeout"
	return nil, "timeout"
end

function EventPoll:clear()
	local sockets = {}
	for i = 1, #self do
		sockets[i] = self[i]
	end
	return sockets
end



class(_ENV)

function _ENV:setoptions(options, socket, ...)
	if options and socket then
		for name, value in pairs(options) do
			socket:setoption(name, value)
		end
	end
	return socket, ...
end

function _ENV:newsocket(options)
	return self:setup(options, tcpsocket())
end

function _ENV:newpoll()
	return EventPoll()
end
