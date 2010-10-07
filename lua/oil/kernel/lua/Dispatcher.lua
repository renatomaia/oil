--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua: An Object Request Broker in Lua                 --
-- Release: 0.5                                                               --
-- Title  : Object Request Dispatcher                                         --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- dispatcher:Facet
-- 	success:boolean, [except:table]|results... dispatch(key:string, operation:string|function, params...)
--------------------------------------------------------------------------------

local pcall = pcall
local unpack = unpack

local oo          = require "oil.oo"
local Exception   = require "oil.Exception"
local Dispatcher  = require "oil.kernel.base.Dispatcher"                        --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.kernel.lua.Dispatcher"

oo.class(_M, Dispatcher)

context = false

--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------

function dispatch(self, request)
	local object = self.context.servants:retrieve(request.objectkey)
	if object then
		local method = Operations[request.operation]
		if method then                                                              --[[VERBOSE]] verbose:dispatcher("dispatching operation ",object,":",request.operation,unpack(request, 1, request.n))
			self:setresults(request, pcall(method, object,
			                               unpack(request, 1, request.n)))
		else
			self:setresults(request, false, Exception{
				error = "badobjimpl",
				message = "no implementation for operation $operation of object with key $key",
				operation = operation,
				object = object,
				key = key,
			})
		end
	else
		self:setresults(request, false, Exception{
			reason = "badobjkey",
			message = "no object with key (got $key)",
			key = key,
		})
	end
	return true
end
