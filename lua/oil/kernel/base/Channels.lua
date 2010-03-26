--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua                                                  --
-- Release: 0.5                                                               --
-- Title  : Client-side CORBA GIOP Protocol specific to IIOP                  --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------

local _G = require "_G"
local pairs = _G.pairs
local type = _G.type

local coroutine = require "coroutine"
local running = coroutine.running

local tabop = require "loop.table"
local copy = tabop.copy

local Wrapper = require "loop.object.Wrapper"

local Mutex = require "cothread.Mutex"

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"
local class = oo.class

module("oil.kernel.base.Channels", class)

--------------------------------------------------------------------------------

local function dummy() return true end

LuaSocketOps = {
	trylock  = dummy,
	freelock = dummy,
	signal   = dummy,
}


CoSocketOps = {}

function CoSocketOps:trylock(operation, wait, signal)
	local mutex = self[operation]
	if signal ~= nil then mutex[signal] = running() end
	local granted = mutex:try(wait)
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

--------------------------------------------------------------------------------

function setupsocket(self, socket, ...)
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
