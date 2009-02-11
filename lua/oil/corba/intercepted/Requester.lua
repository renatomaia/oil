local oo        = require "oil.oo"
local giop      = require "oil.corba.giop"
local Requester = require "oil.corba.giop.Requester"                            --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.corba.intercepted.Requester"

oo.class(_M, Requester)

context = false

function sendmsg(self, channel, msgid, header, types, body)
	if msgid == giop.RequestID then
		local interceptor = self.context.interceptor
		if interceptor and interceptor.marshalrequest then                          --[[VERBOSE]] verbose:interceptors(true, "intercepting request marshaling")
			interceptor:marshalrequest(header)
			if not header.response_expected then                                      --[[VERBOSE]] verbose:interceptors("interception canceled expected response")
				unregister(channel, header.request_id)
			end                                                                       --[[VERBOSE]] verbose:interceptors(false, "interception ended")
		end
	end
	return Requester.sendmsg(self, channel, msgid, header, types, body)
end

function receivemsg(self, channel)
	local msgid, header, decoder = Requester.receivemsg(self, channel)
	if msgid == giop.ReplyID then
		local interceptor = self.context.interceptor
		if interceptor and interceptor.unmarshalreply then
			local request = channel[header.request_id]                                --[[VERBOSE]] verbose:interceptors(true, "intercepting reply unmarshaling")
			interceptor:unmarshalreply(header, request)                               --[[VERBOSE]] verbose:interceptors(false, "interception ended")
		end
	end
	return msgid, header, decoder
end
