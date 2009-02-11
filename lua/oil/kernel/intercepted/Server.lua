local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.intercepted.Server", oo.class)

function before(self, request, object, ...)
	if request.port == "dispatcher" then
		if request.method == request.object.dispatch then
			local interceptor = self.interceptor
			if interceptor.receiverequest then
				local opreq = ...                                                       --[[VERBOSE]] verbose:interceptors(true, "intercepting request received")
				interceptor:receiverequest(opreq)
				request.reply = opreq
				if opreq.cancel then                                                    --[[VERBOSE]] verbose:interceptors(false, "interception canceled request")
					request.cancel = true
					return opreq
				end                                                                     --[[VERBOSE]] verbose:interceptors(false, "interception ended")
			end
		end
	end
	return object, ...
end

function after(self, request, ...)
	if request.port == "dispatcher" then
		if request.method == request.object.dispatch then
			local interceptor = self.interceptor
			if interceptor.sendreply then                                             --[[VERBOSE]] verbose:interceptors(true, "intercepting reply being sent")
				interceptor:sendreply(request.reply)                                    --[[VERBOSE]] verbose:interceptors(false, "interception ended")
			end
		end
	end
	return ...
end
