-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Object Request Dispatcher
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local pcall = _G.pcall
local select = _G.select
local unpack = _G.unpack

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"

module(...); local _ENV = _M

class(_ENV)

context = false

function _ENV:dispatch(request)
	local entry = self.context.servants:retrieve(request.objectkey)
	if entry then
		local object = entry.__servant
		local method = object[request.operation]
		if method then                                                              --[[VERBOSE]] verbose:dispatcher("dispatching ",request)
			request:setreply(pcall(method, object, request:getparams()))
		else
			request:setreply(false, Exception{
				error = "badobjimpl",
				message = "servant $key does not implement $operation",
				operation = operation,
				object = object,
				key = key,
			})
		end
	else
		request:setreply(false, Exception{
			error = "badobjkey",
			message = "unknown servant (got $key)",
			key = key,
		})
	end
end

--------------------------------------------------------------------------------

--[[VERBOSE]] local type = _G.type
--[[VERBOSE]] function verbose.custom:dispatcher(...)
--[[VERBOSE]] 	local viewer = self.viewer
--[[VERBOSE]] 	local output = viewer.output
--[[VERBOSE]] 	for i = 1, select("#", ...) do
--[[VERBOSE]] 		local val = select(i, ...)
--[[VERBOSE]] 		if type(val) == "string" then
--[[VERBOSE]] 			output:write(val)
--[[VERBOSE]] 		elseif val.objectkey and val.operation and val.getparams then
--[[VERBOSE]] 			output:write(val.objectkey,":",val.operation,"(")
--[[VERBOSE]] 			viewer:write(val:getparams())
--[[VERBOSE]] 			output:write(")")
--[[VERBOSE]] 		else
--[[VERBOSE]] 			viewer:write(val)
--[[VERBOSE]] 		end
--[[VERBOSE]] 	end
--[[VERBOSE]] end
