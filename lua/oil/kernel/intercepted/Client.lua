
local select = select
local unpack = unpack

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.intercepted.Client", oo.class)

function before(self, request, object, ...)
	if request.port == "requests" then
		if request.method == request.object.newrequest then
			local interceptor = self.interceptor
			if interceptor.sendrequest then
				local reference, operation = ...
				request.reference = reference
				request.operation = operation
				request.n = select("#", ...) - 2
				for i = 1, request.n do
					request[i] = select(i+2, ...)
				end                                                                     --[[VERBOSE]] verbose:interceptors(true, "intercepting request being sent")
				interceptor:sendrequest(request)
				if request.cancel then                                                  --[[VERBOSE]] verbose:interceptors(false, "interception canceled request")
					return request
				else                                                                    --[[VERBOSE]] verbose:interceptors(false, "interception ended")
					return object,
					       request.reference,
					       request.operation,
					       unpack(request, 1, request.n)
				end
			end
		elseif request.method == request.object.getreply then
			local opreq = ...
			request.reply = opreq
		end
	end
	return object, ...
end

function after(self, request, ...)
	if request.port == "requests" then
		if request.method == request.object.newrequest then
			local opreq = ...
			if opreq then
				opreq[self] = request
			end
		elseif request.method == request.object.getreply then
			local interceptor = self.interceptor
			if interceptor.receivereply then
				if ... then                                                             --[[VERBOSE]] verbose:interceptors(true, "intercepting reply received")
					local reply = request.reply
					local opreq = reply[self]
					interceptor:receivereply(reply, opreq)                                --[[VERBOSE]] verbose:interceptors(false, "interception ended")
				end
			end
		end
	end
	return ...
end
