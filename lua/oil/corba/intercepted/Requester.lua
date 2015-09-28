local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local pcall = _G.pcall

local array = require "table"
local unpack = array.unpack

local oo = require "oil.oo"
local class = oo.class

local servicecontext = require "oil.corba.intercepted.servicecontext"
local srvctxttab2seq = servicecontext.table2sequence
local srvctxtseq2tab = servicecontext.sequence2table

local GIOPRequester = require "oil.corba.giop.Requester"

local function updaterequest(request, intercepted, operation)
	-- update GIOP message fields
	request.sync_scope = intercepted.sync_scope
	request.service_context = srvctxttab2seq(intercepted.service_context)
	-- update parameter values
	local parameters = intercepted.parameters
	request.n = parameters.n or #parameters
	for i = 1, request.n do
		request[i] = parameters[i]
	end
	-- update operation being invoked
	local operation = request.operation_desc
	local newop = intercepted.operation
	if newop ~= nil and newop ~= operation then                                   --[[VERBOSE]] verbose:interceptors("interception changed the operation being invoked")
		operation = newop
		request.operation_desc = operation
	end
	request.operation = operation
	-- update servant reference
	local newref = intercepted.reference
	if newref and newref ~= request.reference then                                --[[VERBOSE]] verbose:interceptors("interception forwarded request to another reference")
		request.reference = newref
	end
end

local IceptedRequester = class({}, GIOPRequester)

function IceptedRequester:dorequest(request)                                    --[[VERBOSE]] verbose:interceptors(true, "intercepting outgoing request")
	local interceptor = self.interceptor
	if interceptor ~= nil then
		local operation = request.operation_desc or request.operation
		local interface = operation.defined_in
		local reference = request.reference
		local channel = self:getchannel(reference, request) -- ignore eventual errors
		if channel ~= nil then
			channel:register(request, "outgoing")
		end
		local intercepted = request.intercepted
		if intercepted == nil then
			intercepted = {}
			request.intercepted = intercepted
		end
		intercepted.request_id = request.request_id or 0
		intercepted.reference = reference
		local profile = reference.ior_profile
		if profile ~= nil then
			intercepted.profile_tag = profile.tag
			intercepted.profile_data = profile.profile_data
			intercepted.profile = profile.decoded
		end
		intercepted.object_key = reference.object_key
		intercepted.interface = interface
		intercepted.operation = operation
		intercepted.operation_name = operation.name
		intercepted.sync_scope = operation.oneway and "channel" or "servant"
		intercepted.response_expected = not operation.oneway -- deprecated
		intercepted.parameters = { n = request.n, unpack(request, 1, request.n) }
		request.operation_desc = operation
		local sendrequest = interceptor.sendrequest
		if sendrequest ~= nil then                                                  --[[VERBOSE]] verbose:interceptors(true, "invoking sendrequest")
			local success, except = pcall(sendrequest, interceptor, intercepted)      --[[VERBOSE]] verbose:interceptors(false, "sendrequest ended")
			if success then
				success = intercepted.success
				if success ~= nil then                                                  --[[VERBOSE]] verbose:interceptors("intercepted request was canceled")
					if channel ~= nil then channel:unregister(request.id, "outgoing") end
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
					end                                                                   --[[VERBOSE]] verbose:interceptors(false, "interception canceled invocation")
					return self.Request(request)
				else
					updaterequest(request, intercepted)
					if request.reference ~= reference then
						if channel ~= nil then channel:unregister(request.id,"outgoing") end
						return self:dorequest(request)
					end
				end
			else                                                                      --[[VERBOSE]] verbose:interceptors("error on interception: ",except)
				if channel ~= nil then channel:unregister(request.id, "outgoing") end
				self:endrequest(request, false, except)
				return self.Request(request)
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
		if interceptor ~= nil then
			local receivereply = interceptor.receivereply
			if receivereply ~= nil then
				local header = request.reply
				if header then
					if header.service_context ~= nil then
						intercepted.reply_service_context = srvctxtseq2tab(header.service_context)
					end
					intercepted.reply_status = header.reply_status
				end
				intercepted.success = request.success
				intercepted.results = {
					n = request.n,
					unpack(request, 1, request.n),
				}                                                                       --[[VERBOSE]] verbose:interceptors(true, "invoking receivereply")
				local success, except = pcall(receivereply, interceptor, intercepted)   --[[VERBOSE]] verbose:interceptors(false, "receivereply ended")
				if success then
					success = intercepted.success
					request.success = success
					if success ~= nil then
						-- update returned values
						local results = intercepted.results or {}
						request.n = results.n or #results
						for i = 1, request.n do
							request[i] = results[i]
						end
					else                                                                  --[[VERBOSE]] verbose:interceptors("intercepted request must be reissued")
						updaterequest(request, intercepted)
						self:dorequest(request)
					end
				else                                                                    --[[VERBOSE]] verbose:interceptors("error on interception: ",except)
					request[1] = except
					request.n = 1
					request.success = false
				end
			end
		end                                                                         --[[VERBOSE]] verbose:interceptors(false, "interception of incoming reply completed")
	end
end

return IceptedRequester
