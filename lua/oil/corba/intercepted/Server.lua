local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.corba.intercepted.Server", oo.class)

context = false

function receiverequest(self, request)
	local context = self.context
	local interceptor = context.interceptor
	if interceptor.receiverequest then
		local objectkey = request.object_key
		local operation = request.operation
		local object, type = context.servants:retrieve(objectkey)
		request.interface      = type
		request.interface_name = type.absolute_name
		request.operation_name = operation
		request.servant_impl   = object
		return interceptor:receiverequest(request)
	end
end

function sendreply(self, reply)
	local interceptor = self.context.interceptor
	if interceptor.sendreply then
		self.current = reply
		interceptor:sendreply(reply)
	end
end

function marshalreply(self, header)
	local reply = self.current
	if reply then
		self.current = nil
		if reply.reply_service_context ~= nil then
			header.service_context = reply.reply_service_context
		end
	end
end
