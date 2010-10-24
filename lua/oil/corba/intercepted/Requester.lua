local _G = require "_G"
local unpack = _G.unpack

local oo = require "oil.oo"
local class = oo.class

local GIOPRequester = require "oil.corba.giop.Requester"                            --[[VERBOSE]] local verbose = require "oil.verbose"



local IceptedRequester = class({}, GIOPRequester)

function IceptedRequester:interceptrequest(reference, operation, request)
	local interceptor = self.interceptor
	if interceptor then
		local interface = operation.defined_in
		local intercepted = {
			reference         = reference,
			operation         = operation,
			profile_tag       = reference._profiletag,
			profile_data      = reference._profiledata,
			interface         = interface,
			interface_name    = interface and interface.absolute_name,
			request_id        = request.request_id,
			response_expected = request.response_expected,
			object_key        = request.object_key,
			operation_name    = request.operation,
			parameters        = { n = request.n, unpack(request, 1, request.n) },
		}
		request.intercepted = intercepted
		if interceptor.sendrequest then                                             --[[VERBOSE]] verbose:interceptors(true, "intercepting request being sent")
			interceptor:sendrequest(intercepted)
			if intercepted.success ~= nil then                                        --[[VERBOSE]] verbose:interceptors("interception request was canceled")
				request.success = intercepted.success
				-- update returned values
				local results = intercepted.results or {}
				request.n = results.n or #results
				for i = 1, request.n do
					request[i] = results[i]
				end
			else
				-- update parameter values
				local parameters = intercepted.parameters
				request.n = parameters.n or #parameters
				for i = 1, request.n do
					request[i] = parameters[i]
				end
				-- update operation being invoked
				if intercepted.operation and intercepted.operation ~= operation then
					operation = intercepted.operation
					interface = operation.defined_in
					intercepted.interface      = interface
					intercepted.interface_name = interface and interface.absolute_name
					intercepted.operation_name = operation.name
					request.operation  = operation.name
					request.inputs     = operation.inputs
					request.outputs    = operation.outputs
					request.exceptions = operation.exceptions
				end
				-- update GIOP message fields
				request.object_key           = intercepted.object_key
				request.response_expected    = intercepted.response_expected
				request.service_context      = intercepted.service_context or
				                               request.service_context
				request.requesting_principal = intercepted.requesting_principal or
				                               request.requesting_principal             --[[VERBOSE]] verbose:interceptors(false, "interception ended")
			end
		end
		return intercepted
	end
end

function IceptedRequester:makerequest(channel, except, reference, operation, ...)
	local request = self:buildrequest(channel, except, reference, operation, ...) --[[VERBOSE]] verbose:interceptors(true, "intercepting request")
	local intercepted = self:interceptrequest(reference, operation, request)
	if intercepted then
		if request.success ~= nil then
			self:endrequest(request)                                                  --[[VERBOSE]] verbose:interceptors(false, "interception canceled invocation")
			return request
		end
		reference = intercepted.forward_reference
		if reference then                                                           --[[VERBOSE]] verbose:interceptors("intercepted request forwarded")
			if request.channel then
				unregister(request.channel, request.request_id)
			end
			channel, except = self:getchannel(reference)
			if channel then
				intercepted.object_key = self.objkeyof[proxy]
				intercepted.profile = reference._profile
				request.object_key = except
				if request.response_expected then
					register(channel, request)
				else
					request.request_id = 0
				end
			else
				channel = nil
			end
		elseif not request.response_expected and request.channel then               --[[VERBOSE]] verbose:interceptors("interception canceled the expected response")
			unregister(request.channel, request.request_id)
			request.request_id = 0
		elseif request.response_expected and not request.channel and channel then   --[[VERBOSE]] verbose:interceptors("interception asked for an expected response")
			register(channel, request)
		end
		intercepted.request_id = request.request_id
	end                                                                           --[[VERBOSE]] verbose:interceptors(false, "interception completed")
	return self:processrequest(channel, except, request)
end



function IceptedRequester:interceptreply(request, header)
	local intercepted = request.intercepted
	if intercepted then
		request.intercepted = nil
		local interceptor = self.interceptor
		if interceptor and interceptor.receivereply then
			local header = request.reply_header
			if header then
				if header.service_context then
					intercepted.reply_service_context = header.service_context
				end
				intercepted.reply_status = header.reply_status
			end
			intercepted.success = request.success
			intercepted.results = {
				n = request.n,
				unpack(request, 1, request.n),
			}
			interceptor:receivereply(intercepted)
			request.success = intercepted.success
			-- update returned values
			local results = intercepted.results or {}
			request.n = results.n or #results
			for i = 1, request.n do
				request[i] = results[i]
			end
		end
	end
end

function IceptedRequester:endrequest(request, success, result)
	GIOPRequester.endrequest(self, request, success, result)
	self:interceptreply(request)
end

function IceptedRequester:doreply(replied, header, decoder)
	replied.reply_header = header
	return GIOPRequester.doreply(self, replied, header, decoder)
end

return IceptedRequester
