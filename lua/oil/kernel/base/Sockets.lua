-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : Socket API Wrapper
-- Authors: Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"
local pairs = _G.pairs

local math = require "math"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"
local max = math.max

local table = require "table"
local remove = table.remove

local socket = require "socket.core"
local tcpsocket = socket.tcp
local selectsockets = socket.select
local gettime = socket.gettime

local ArraySet = require "loop.collection.ArrayedSet"
local add = ArraySet.add
local remove = ArraySet.remove

local oo = require "oil.oo"
local class = oo.class

do -- add new operation 'settimelimit' on sockets
	local debug = require "debug"
	local registry = debug.getregistry()
	local function settimelimit(self, timeout)
		if timeout and timeout >= 0 then timeout = max(0, timeout-gettime()) end
		return self:settimeout(timeout)
	end
	local socketclasses = {
		"tcp{client}",
		"tcp{server}",
		"tcp{master}",
		"udp{connected}",
		"udp{unconnected}",
	}
	for _, socketclass in ipairs(socketclasses) do
		local methods = registry[socketclass].__index
		methods.settimelimit = settimelimit
	end
end


local EventPoll = class()

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
			local count = #ready
			for i = 1, count do
				if ready[i] == socket then
					ready[socket] = nil
					ready[i], ready[count] = ready[count], nil
					break
				end
			end
		end
		return true
	end
	return false
end

function EventPoll:getready(timeout)
	repeat
		local ready = self.ready
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
		sockets[ self[i] ] = true
	end
	return sockets
end



local Sockets = class()

function Sockets:setoptions(options, socket, ...)
	if options and socket then
		for name, value in pairs(options) do
			socket:setoption(name, value)
		end
	end
	return socket, ...
end

function Sockets:newsocket(options)
	return self:setoptions(options, tcpsocket())
end

function Sockets:newpoll()
	return EventPoll()
end

return Sockets
