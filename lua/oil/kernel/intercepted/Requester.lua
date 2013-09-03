local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local select = _G.select

local array = require "table"
local unpack = array.unpack or _G.unpack

local Wrapper = require "loop.object.Wrapper"

local oo = require "oil.oo"
local class = oo.class


local Requester = class{
	__new = Wrapper.__new,
	__index = Wrapper.__index,
}

function Requester:newrequest(reference, operation, ...)
	local request = {
		reference = reference,
		operation = operation,
		n = select("#", ...),
		...,
	}
	local result, except
	local interceptor = self.interceptor
	if interceptor.newrequest then                                                --[[VERBOSE]] verbose:interceptors(true, "intercepting request being sent")
		interceptor:newrequest(request)                                             --[[VERBOSE]] verbose:interceptors(false, "interception ended")
		if request.success ~= nil then                                              --[[VERBOSE]] verbose:interceptors("interception canceled request")
			result, except = request, nil
		else
			result, except = self.__object:newrequest(request.reference,
			                                          request.operation,
			                                          unpack(request, 1, request.n))
		end
	else
		result, except = self.__object:newrequest(reference, operation, ...)
	end
	if not result then
		request.success = false
		request.n = 1
		request[1] = except
		result, except = request, nil
	end
	result[self] = request
	return result, except
end

function Requester:getreply(opreq, ...)
	local result, except = self.__object:getreply(opreq, ...)
	if result then
		local interceptor = self.interceptor
		local request = opreq[self]
		if request then
			opreq[self] = nil
			if interceptor.getreply then                                              --[[VERBOSE]] verbose:interceptors(true, "intercepting received reply")
				interceptor:getreply(request, opreq)                                    --[[VERBOSE]] verbose:interceptors(false, "interception ended")
			end
		end
	end
	return result, except
end

return Requester
