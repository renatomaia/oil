local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local unpack = _G.unpack

local oo = require "oil.oo"
local class = oo.class

local GIOPRequester = require "oil.corba.giop.Requester"

local IceptedRequester = class({}, GIOPRequester)

function IceptedRequester:dorequest(request)                                    --[[VERBOSE]] verbose:interceptors(true, "intercepting outgoing request")
	local interceptor = self.interceptor
	if interceptor then
		local operation = request.operation
		local interface = operation.defined_in
		local reference = request.reference
		local channel = self:getchannel(reference) -- ignore eventual errors
		if channel ~= nil then
			channel:register(request, "outgoing")
		end
		local intercepted = {
			request_id        = request.request_id or 0,
			reference         = reference,
			profile_tag       = reference.ior_profile.tag,
			profile_data      = reference.ior_profile_decoded,
			object_key        = reference.object_key,
			interface         = interface,
			operation         = operation,
			operation_name    = operation.name,
			sync_scope        = request.sync_scope,
			response_expected = request.sync_scope ~= "channel", -- deprecated
			parameters        = { n = request.n, unpack(request, 1, request.n) },
		}
		request.intercepted = intercepted
		if interceptor.sendrequest then                                             --[[VERBOSE]] verbose:interceptors(true, "invoking sendrequest")
			interceptor:sendrequest(intercepted)                                      --[[VERBOSE]] verbose:interceptors(false, "sendrequest ended")
			local success = intercepted.success
			if success ~= nil then                                                    --[[VERBOSE]] verbose:interceptors("intercepted request was canceled")
				-- update returned values
				local results = intercepted.results or {}
				if success then
					local count = results.n or #results
					for i = 1, count do
						request[i] = results[i]
					end
					self:endrequest(request, true, count)
				else
					self:endrequest(request, false, results[1])
				end                                                                     --[[VERBOSE]] verbose:interceptors(false, "interception canceled invocation")
				return self.Request(request)
			else
				-- update GIOP message fields
				request.sync_scope = intercepted.sync_scope
				request.service_context = intercepted.service_context
				-- update parameter values
				local parameters = intercepted.parameters
				request.n = parameters.n or #parameters
				for i = 1, request.n do
					request[i] = parameters[i]
				end
				-- update operation being invoked
				local newop = intercepted.operation
				if newop ~= nil and newop ~= operation then                             --[[VERBOSE]] verbose:interceptors("interception changed the operation being invoked")
					request.operation = newop
				end
				-- update servant reference
				local newref = intercepted.reference
				if newref and newref ~= reference then                                  --[[VERBOSE]] verbose:interceptors("interception forwarded request to another reference")
					request.reference = newref
					if channel ~= nil then
						channel:unregister(request.id, "outgoing")
					end
				end
			end
		end
	end                                                                           --[[VERBOSE]] verbose:interceptors(false, "interception of outgoing request completed")
	return GIOPRequester.dorequest(self, request)
end

function IceptedRequester:endrequest(request, success, result)
	GIOPRequester.endrequest(self, request, success, result)
	local intercepted = request.intercepted
	if intercepted ~= nil then                                                    --[[VERBOSE]] verbose:interceptors(true, "intercepting incoming reply")
		request.intercepted = nil
		local interceptor = self.interceptor
		if interceptor ~= nil and interceptor.receivereply ~= nil then
			local header = request.reply
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
			}                                                                         --[[VERBOSE]] verbose:interceptors(true, "invoking receivereply")
			interceptor:receivereply(intercepted)                                     --[[VERBOSE]] verbose:interceptors(false, "receivereply ended")
			request.success = intercepted.success
			-- update returned values
			local results = intercepted.results or {}
			request.n = results.n or #results
			for i = 1, request.n do
				request[i] = results[i]
			end
		end                                                                         --[[VERBOSE]] verbose:interceptors(false, "interception of incoming reply completed")
	end
end

return IceptedRequester








--[===[
function IceptedRequester:makerequest(channel,except,reference,operation,...)
	local request = self:buildrequest(channel, except, reference, operation, ...) --[[VERBOSE]] verbose:interceptors(true, "intercepting outgoing request")
	local intercepted = self:interceptrequest(reference, operation, request)
	if intercepted then
		if request.success ~= nil then
			self:endrequest(request)                                                  --[[VERBOSE]] verbose:interceptors(false, "interception canceled invocation")
			return request
		end
		reference = intercepted.forward_reference
		local oldchannel = request.channel
		if reference then                                                           --[[VERBOSE]] verbose:interceptors("interception forwarded request to another reference")
			if oldchannel then
				oldchannel:unregister(request.id, "outgoing")
			end
			channel, except = self:getchannel(reference)
			if channel then
				request.object_key = reference.object_key
				intercepted.object_key = reference.object_key
				intercepted.profile = reference.ior_profile_decoded
				if request.sync_scope ~= "channel" then
					channel:register(request, "outgoing")
				else
					request.request_id = channel.bidirctxt=="acceptor" and 1 or 0
				end
			else
				channel = nil
			end
		elseif request.sync_scope == "channel" and oldchannel then                  --[[VERBOSE]] verbose:interceptors("interception canceled the expected response")
			oldchannel:unregister(request.id, "outgouing")
			request.request_id = channel.bidirctxt=="acceptor" and 1 or 0
		elseif request.sync_scope~="channel" and not oldchannel and channel then    --[[VERBOSE]] verbose:interceptors("interception asked for an expected response")
			channel:register(request, "outgoing")
		end
		intercepted.request_id = request.request_id
	end                                                                           --[[VERBOSE]] verbose:interceptors(false, "interception of outgoing request completed")
	self:processrequest(channel, except, request)
	return request
end
function IceptedRequester:endrequest(request, success, result)
	GIOPRequester.endrequest(self, request, success, result)
	local intercepted = request.intercepted
	if intercepted then                                                           --[[VERBOSE]] verbose:interceptors(true, "intercepting incoming reply")
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
			}                                                                         --[[VERBOSE]] verbose:interceptors(true, "invoking receivereply")
			interceptor:receivereply(intercepted)                                     --[[VERBOSE]] verbose:interceptors(false, "receivereply ended")
			request.success = intercepted.success
			-- update returned values
			local results = intercepted.results or {}
			request.n = results.n or #results
			for i = 1, request.n do
				request[i] = results[i]
			end
		end                                                                         --[[VERBOSE]] verbose:interceptors(false, "interception of incoming reply completed")
	end
end
--]===]
