-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Object Request Dispatcher
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local pcall = _G.pcall

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"

module(...); local _ENV = _M

class(_ENV)

context = false

function _ENV:dispatch(request)
	local context = self.context
	local entry = context.servants:retrieve(request.objectkey)
	if entry then
		local object = entry.__servant
		local type = entry.__type
		local opname = request.operation
		local opinfo = context.indexer:valueof(type, opname)
		if opinfo then
			local method = object[opname] or opinfo.implementation
			if method then                                                            --[[VERBOSE]] verbose:dispatcher("dispatching ",request)
				request:setreply(pcall(method, object, request:getvalues()))
			else
				request:setreply(false, Exception{
					error = "badobjimpl",
					message = "servant $key does not implement $operation",
					operationdescription = opinfo,
					operation = opname,
					object = object,
					type = type,
					key = key,
				})
			end
		else
			request:setreply(false, Exception{
				error = "badobjop",
				message = "operation $operation is illegal for servant $key",
				operation = opname,
				object = object,
				type = type,
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
