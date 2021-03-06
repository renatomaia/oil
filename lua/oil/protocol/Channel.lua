-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : 
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local coroutine = require "coroutine"
local running = coroutine.running

local Mutex = require "cothread.Mutex"

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"

local Channel = class{ bytes = "" }

function Channel:__init()
	self.read = Mutex()
	self.write = Mutex()
end

function Channel:unlocked(operation)
	return self[operation]:isfree()
end

function Channel:trylock(operation, timeout, signal)
	local mutex = self[operation]
	if signal ~= nil then mutex[signal] = running() end
	local granted, expired = mutex:try(timeout)
	if signal ~= nil then mutex[signal] = nil end
	return granted, expired
end

function Channel:signal(operation, signal)
	local mutex = self[operation]
	local thread = mutex[signal]
	if thread then
		return mutex:deny(thread)
	end
end

function Channel:freelock(operation)
	return self[operation]:free()
end

function Channel:getpeeraddress()
	local host, port = self.socket:getpeername()
	if host ~= nil then
		return {host=host, port=port}
	end
end

function Channel:send(...)
	local socket = self.socket
	local result, except = socket:send(...)
	if result == nil then
		if except == "closed" then
			except = Exception{ "communication failure", error = "closed" }
		elseif except == "timeout" then
			except = Exception{ "timeout", error = "timeout" }
		else
			except = Exception{
				"unable to write to $channel ($errmsg)",
				error = "badchannel",
				errmsg = except,
				channel = self,
			}
		end
	end
	return result, except
end

function Channel:receive(count, timeout)
	local missing
	local bytes = self.bytes
	if count then
		if count <= #bytes then
			self.bytes = bytes:sub(count+1)
			return bytes:sub(1, count)
		end
		missing = count-#bytes
	else
		local pos = bytes:find("\n", 1, true)
		if pos then
			self.bytes = bytes:sub(pos+1)
			return bytes:sub(1, pos-1)
		end
	end
	local socket = self.socket
	local tmchanged, tmbak, tmkind
	if timeout ~= nil then
		tmchanged, tmbak, tmkind = socket:settimeout(timeout, "isTimeStamp")
	end
	local result, except, partial = socket:receive(missing)
	if tmchanged then
		socket:settimeout(tmbak, tmkind)
	end
	if result then
		self.bytes = ""
		return bytes..result
	end
	self.bytes = bytes..partial
	if except == "closed" then
		except = Exception{ "communication failure", error = "closed" }
	elseif except == "timeout" then
		except = Exception{ "timeout", error = "timeout" }
	else
		except = Exception{
			"unable to read from $channel ($errmsg)",
			error = "badchannel",
			errmsg = except,
			channel = self,
		}
	end
	return nil, except
end

function Channel:broken()
	local socket = self.socket
	local _, timeout, tmkind = socket:settimeout(0)
	local result, except = socket:receive(0)
	socket:settimeout(timeout, tmkind)
	return result == nil and except == "closed"
end

function Channel:close()
	local acceptor = self.acceptor
	if acceptor ~= nil then
		acceptor:unregister(self)
	end
	local connector = self.connector
	if connector ~= nil then
		connector:unregister(self)
	end
	local limiter = self.limiter
	if limiter ~= nil then
		limiter:remove(self)
	end
	self.socket:close()
	return true
end

return Channel
