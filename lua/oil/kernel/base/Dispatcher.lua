-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Object Request Dispatcher
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local pcall = _G.pcall
local select = _G.select

local array = require "table"
local unpack = array.unpack or _G.unpack

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"

local Dispatcher = class{ context = false }

function Dispatcher:dispatch(request)
	local key = request.objectkey
	local entry = self.context.servants:retrieve(key)
	if entry ~= nil then
		local object = entry.__servant
		local method = object[request.operation]
		if method ~= nil then                                                       --[[VERBOSE]] verbose:dispatcher("dispatching ",request)
			return request:setreply(pcall(method, object, request:getvalues()))
		else                                                                        --[[VERBOSE]] verbose:dispatcher("missing implementation of ",request.operation)
			return request:setreply(false, Exception{
				"servant $key does not implement $operation",
				error = "badobjimpl",
				operation = request.operation,
				object = object,
				key = key,
			})
		end
	else                                                                          --[[VERBOSE]] verbose:dispatcher("got illegal object ",key)
		return request:setreply(false, Exception{
			"unknown servant (got $key)",
			error = "badobjkey",
			key = key,
		})
	end
end

--[[VERBOSE]] local type = _G.type
--[[VERBOSE]] function verbose.custom:dispatcher(...)
--[[VERBOSE]] 	local viewer = self.viewer
--[[VERBOSE]] 	local output = viewer.output
--[[VERBOSE]] 	for i = 1, select("#", ...) do
--[[VERBOSE]] 		local val = select(i, ...)
--[[VERBOSE]] 		if type(val) == "string" then
--[[VERBOSE]] 			output:write(val)
--[[VERBOSE]] 		elseif type(val) == "table" and val.objectkey and val.operation and val.getvalues then
--[[VERBOSE]] 			output:write(val.objectkey,":",val.operation,"(")
--[[VERBOSE]] 			viewer:write(val:getvalues())
--[[VERBOSE]] 			output:write(")")
--[[VERBOSE]] 		else
--[[VERBOSE]] 			viewer:write(val)
--[[VERBOSE]] 		end
--[[VERBOSE]] 	end
--[[VERBOSE]] end

return Dispatcher
