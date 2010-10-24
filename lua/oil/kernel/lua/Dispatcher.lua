-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Object Request Dispatcher
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local pcall = _G.pcall
local unpack = _G.unpack

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"
local Dispatcher = require "oil.kernel.base.Dispatcher"



local Operations = {
	tostring = function(self)               return tostring(self) end,
	unm      = function(self)               return -self end,
	len      = function(self)               return #self end,
	add      = function(self, other)        return self + other end,
	sub      = function(self, other)        return self - other end,
	mul      = function(self, other)        return self * other end,
	div      = function(self, other)        return self / other end,
	mod      = function(self, other)        return self % other end,
	pow      = function(self, other)        return self ^ other end,
	lt       = function(self, other)        return self < other end,
	eq       = function(self, other)        return self == other end,
	le       = function(self, other)        return self <= other end,
	concat   = function(self, other)        return self .. other end,
	call     = function(self, ...)          return self(...) end,
	index    = function(self, field)        return self[field] end,
	newindex = function(self, field, value) self[field] = value end,
}



local LuaDispatcher = class({ context = true }, Dispatcher)

function LuaDispatcher:dispatch(request)
	local entry = self.context.servants:retrieve(request.objectkey)
	if entry then
		local method = Operations[request.operation]
		if method then                                                              --[[VERBOSE]] verbose:dispatcher("dispatching ",request)
			request:setreply(pcall(method, entry.__servant, request:getvalues()))
		else
			request:setreply(false, Exception{
				error = "badobjimpl",
				message = "no implementation of $operation for object (got $key)",
				operation = request.operation,
				object = entry.__servant,
				key = request.objectkey,
			})
		end
	else
		request:setreply(false, Exception{
			reason = "badobjkey",
			message = "no object with key (got $key)",
			key = request.objectkey,
		})
	end
	return true
end

return LuaDispatcher
