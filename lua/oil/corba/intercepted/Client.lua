local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.corba.intercepted.Client", oo.class)

context = false

function sendrequest(self, request)
	local interceptor = self.context.interceptor
	if interceptor.sendrequest then
		local reference = request.reference
		local operation = request.operation
		local interface = operation.defined_in
		request.interface         = interface
		request.interface_name    = interface and interface.absolute_name
		request.operation_name    = operation.name
		request.object_key        = reference._object
		request.response_expected = not operation.oneway
		self.current = request
		return interceptor:sendrequest(request)
	end
end

function marshalrequest(self, header)
	local request = self.current
	if request then
		self.current = nil
		header.response_expected = request.response_expected
		header.object_key        = request.object_key or header.object_key
		header.operation         = request.operation_name
		if request.service_context ~= nil then
			header.service_context = request.service_context
		end
		if request.requesting_principal ~= nil then
			header.requesting_principal = request.requesting_principal
		end
	end
end

function unmarshalreply(self, header, request)
	request.request_id      = header.request_id
	request.reply_status    = header.reply_status
	request.service_context = header.service_context
end

function receivereply(self, reply, request)
	local interceptor = self.context.interceptor
	if interceptor.receivereply then
		reply.interface         = request.interface
		reply.interface_name    = request.interface
		reply.operation_name    = request.operation_name
		reply.object_key        = request.object_key
		reply.response_expected = request.response_expected
		return interceptor:receivereply(reply)
	end
end
