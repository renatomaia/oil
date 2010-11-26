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
	local granted = mutex:try(timeout)
	if signal ~= nil then mutex[signal] = nil end
	return granted
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

function Channel:send(...)
	local socket = self.socket
	local result, except = socket:send(...)
	if result == nil then
		if except == "closed" then
			except = Exception{
				error = "terminated",
				message = "terminated",
			}
		elseif except == "timeout" then
			except = Exception{
				error = "timeout",
				message = "timeout",
			}
		else
			except = Exception{
				error = "badchannel",
				message = "unable to write to $channel ($errmsg)",
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
	socket:settimelimit(timeout)
	local result, except, partial = socket:receive(missing)
	if result then
		self.bytes = ""
		return bytes..result
	end
	self.bytes = bytes..partial
	if except == "closed" then
		except = Exception{
			error = "terminated",
			message = "terminated",
		}
	elseif except == "timeout" then
		except = Exception{
			error = "timeout",
			message = "timeout",
		}
	else
		except = Exception{
			error = "badchannel",
			message = "unable to read from $channel ($errmsg)",
			errmsg = except,
			channel = self,
		}
	end
	return nil, except
end

function Channel:close()
	self.socket:close()
	return true
end

function Channel:acquire()
	self.listener.access:remove(self.socket)
end

function Channel:release()
	self.listener.access:add(self.socket)
end

return Channel
