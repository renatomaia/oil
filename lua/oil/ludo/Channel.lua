-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : 
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local error = _G.error
local pcall = _G.pcall
local tonumber = _G.tonumber

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"

local Channel = require "oil.protocol.Channel"


local LuDOChannel = class({}, Channel)

local function encodemsg(self, ...)                                             --[[VERBOSE]] verbose:message("sending values ",verbose.viewer:tostring(...))
	local encoder = self.context.codec:encoder()
	encoder:put(...)
	local data = encoder:__tostring()
	return #data.."\n"..data
end

local function decodemsg(self, bytes)
	return self.context.codec:decoder(bytes):get()
end

local function doreply(self, ok, requestid, success, ...)
	if not ok then return nil, requestid end
	local request, except = self[requestid]
	if request then
		self[requestid] = nil
		request.channel = nil
		request:setreply(success, ...)
		self:signal("read", request)
	else                                                                          --[[VERBOSE]] verbose:message("LuDO failure: reply for unknown request ID")
		except = Exception{
			"unexpected LuDO reply ID (got $requestid)",
			error = "badmessage",
			requestid = requestid,
		}
	end
	return request, except
end



function LuDOChannel:sendvalues(request_id, ...)
	local ok, result = pcall(encodemsg, self, request_id, ...)
	if ok then
		self:trylock("write")
		ok, result = self:send(result)
		self:freelock("write")                                                      --[[VERBOSE]] else verbose:message("message encoding failed")
	end
	return ok, result
end

function LuDOChannel:receivevalues(timeout)
	local size = self.pendingsize
	if size then                                                                  --[[VERBOSE]] verbose:message("reading a previous incomplete message (got only its size)")
		self.pendingsize = nil
	else
		local bytes, except = self:receive(nil, timeout)
		if bytes ~= nil then
			size = tonumber(bytes)
			if size == nil then                                                       --[[VERBOSE]] verbose:message("LuDO failure: illegal message size")
				return nil, Exception{
					"invalid LuDO message size (got $size)",
					error = "badmessage",
					size = bytes,
				}
			end
		else
			return nil, except
		end
	end
	local bytes, except = self:receive(size, timeout)
	if bytes ~= nil then                                                          --[[VERBOSE]] verbose:message("got message ",bytes)
		return pcall(decodemsg, self, bytes)
	elseif except.error == "timeout" then                                         --[[VERBOSE]] verbose:message("message was not available before timeout")
		self.pendingsize = size
	end
	return nil, except
end

function LuDOChannel:processmessage(timeout)
	return doreply(self, self:receivevalues(timeout))
end

return LuDOChannel