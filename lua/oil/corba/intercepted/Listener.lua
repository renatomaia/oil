local oo       = require "oil.oo"
local giop     = require "oil.corba.giop"
local Listener = require "oil.corba.giop.Listener"                              --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.corba.intercepted.Listener"

oo.class(_M, Listener)

context = false

function receivemsg(self, channel)
	local msgid, header, decoder = Listener.receivemsg(self, channel)
	if msgid == giop.RequestID then
		local interceptor = self.context.interceptor
		if interceptor and interceptor.unmarshalrequest then                        --[[VERBOSE]] verbose:interceptors(true, "intercepting request unmarshaling")
			interceptor:unmarshalrequest(header)                                      --[[VERBOSE]] verbose:interceptors(false, "interception ended")
		end
	end
	return msgid, header, decoder
end

function sendmsg(self, channel, msgid, header, types, body)
	if msgid == giop.ReplyID then
		local interceptor = self.context.interceptor
		if interceptor and interceptor.marshalreply then                            --[[VERBOSE]] verbose:interceptors(true, "intercepting reply marshaling")
			interceptor:marshalreply(header)                                          --[[VERBOSE]] verbose:interceptors(false, "interception ended")
		end
	end
	return Listener.sendmsg(self, channel, msgid, header, types, body)
end
