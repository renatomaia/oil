-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Enhancements to the standard socket API
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local pairs = _G.pairs
local type = _G.type

local math = require "math"
local max = math.max

local coroutine = require "coroutine"
local running = coroutine.running

local socket = require "socket.core"
local gettime = socket.gettime

local table = require "loop.table"
local copy = table.copy

local Wrapper = require "loop.object.Wrapper"

local Mutex = require "cothread.Mutex"

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"
local class = oo.class


local function dummy() return true end


local LuaSocketOps = {
	unlocked = dummy,
	trylock  = dummy,
	freelock = dummy,
	signal   = dummy,
	bytes    = "",
}

function LuaSocketOps:settimeout(timeout, timestamp)
	if timestamp then timeout = max(0, timeout-gettime()) end
	return self.__object:settimeout(timeout)
end

function LuaSocketOps:probe(count, timeout)
	local bytes = self.bytes
	if #bytes >= count then
		self.bytes = bytes:sub(count+1)
		return bytes:sub(1, count)
	end
	if timeout ~= nil then
		tmchanged, tmbak, tmkind = self:settimeout(timeout, "isTimeStamp")
	end
	local result, except, partial = self:receive(count-#bytes)
	if tmchanged then
		self:settimeout(tmbak, tmkind)
	end
	if result then
		self.bytes = ""
		return bytes..result
	end
	self.bytes = bytes..partial
	return nil, except
end


local CoSocketOps = {
	bytes = LuaSocketOps.bytes,
	probe = LuaSocketOps.probe,
}

function CoSocketOps:unlocked(operation)
	return self[operation]:isfree()
end

function CoSocketOps:trylock(operation, timeout, signal)
	local mutex = self[operation]
	if signal ~= nil then mutex[signal] = running() end
	local granted = mutex:try(timeout)
	if signal ~= nil then mutex[signal] = nil end
	return granted
end

function CoSocketOps:signal(operation, signal)
	local mutex = self[operation]
	local thread = mutex[signal]
	if thread then
		return mutex:deny(thread)
	end
end

function CoSocketOps:freelock(operation)
	return self[operation]:free()
end


local Channels = class()

function Channels:setupsocket(socket, ...)
	if socket then
		-- setup of TCP socket options
		local options = self.options
		if options then
			for name, value in pairs(options) do
				socket:setoption(name, value)
			end
		end
		
		-- additional socket operations
		if type(socket) ~= "table" then
			socket = Wrapper{ __object = socket }
			copy(self.LuaSocketOps, socket)
		else
			copy(self.CoSocketOps, socket)
			socket.read = Mutex()
			socket.write = Mutex()
		end
	end
	return socket, ...
end

return Channels
