-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Object Request Dispatcher
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local pcall = _G.pcall

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"

local Dispatcher = class{ context = false }

function Dispatcher:dispatch(request)
	local context = self.context
	local key = request.objectkey
	local entry = context.servants:retrieve(key)
	local operation -- defined later if servant exists
	if entry ~= nil then
		operation = context.indexer:valueof(entry.__type, request.operation)
	end
	local object, method = request:preinvoke(entry, operation)
	if object ~= nil then
		if method ~= nil then                                                       --[[VERBOSE]] verbose:dispatcher("dispatching ",request)
			request:setreply(pcall(method, object, request:getvalues()))
		else                                                                        --[[VERBOSE]] verbose:dispatcher("missing implementation of ",request.operation)
			request:setreply(false, Exception{
				"servant $key does not implement $operation",
				error = "badobjimpl",
				operationdescription = operation,
				operation = request.operation,
				object = object,
				key = key,
			})
		end
	elseif entry == nil then                                                      --[[VERBOSE]] verbose:dispatcher("got illegal object ",key)
		request:setreply(false, Exception{
			"unknown servant (got $key)",
			error = "badobjkey",
			key = key,
		})
	elseif operation == nil then                                                  --[[VERBOSE]] verbose:dispatcher("got illegal operation ",request.operation)
		request:setreply(false, Exception{
			"operation $operation is illegal for servant $key",
			error = "badobjop",
			operation = request.operation,
			object = object,
			type = entry.__type,
			key = key,
		})                                                                          --[[VERBOSE]] else verbose:dispatcher("pre-invocation failed!")
	end
end

return Dispatcher
