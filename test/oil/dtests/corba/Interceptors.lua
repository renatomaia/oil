local Suite = require "loop.test.Suite"
local Template = require"oil.dtests.Template"
local test = Template{"Client"} -- master process name

Server = [=====================================================================[
checks = oil.dtests.checks

Object = {}
function Object:concat(str1, str2)
	return str1.."&"..str2
end

local CurrentRequest

oil.setserverinterceptor{
	receiverequest = function(self, request)
		if request.object_key == "object" and request.operation == "concat" then
			checks:assert(request.service_context, checks.typeis("table"))
			checks:assert(request.request_id, checks.typeis("number"))
			checks:assert(request.response_expected, checks.is(true))
			checks:assert(request.servant, checks.typeis("table"))
			checks:assert(request.servant.__newindex, checks.is(Object))
			checks:assert(request.method, checks.is(Object.concat))
			checks:assert(request.success, checks.is(nil))
			checks:assert(request.count, checks.is(2))
			checks:assert(request[1], checks.is("first"))
			checks:assert(request[2], checks.is("second"))
		
			--checks:assert(request.service_context[1].context_id, checks.is(1234))
			--checks:assert(request.service_context[1].context_data, checks.is("1234"))
			
			CurrentRequest = request
		end
	end,
	sendreply = function(self, reply)
		if reply == CurrentRequest then
			checks:assert(reply.service_context, checks.typeis("table"))
			checks:assert(reply.request_id, checks.typeis("number"))
			checks:assert(reply.response_expected, checks.is(true))
			checks:assert(reply.object_key, checks.is("object"))
			checks:assert(reply.operation, checks.is("concat"))
			checks:assert(reply.servant.__newindex, checks.is(Object))
			checks:assert(reply.method, checks.is(Object.concat))
			checks:assert(reply.success, checks.is(true))
			checks:assert(reply.count, checks.is(1))
			checks:assert(reply[1], checks.is("first&second"))
		
			reply.service_context[1] = {
				context_id = 4321,
				context_data = "4321",
			}
		end
	end,
}

oil.init{ port = 2809 }
oil.loadidl[[
	interface MyInterface {
		string concat(in string str1, in string str2);
	};
]]
oil.newservant(Object, "::MyInterface", "object")
oil.run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks
object = oil.dtests.resolve("Server", 2809, "object")

local CurrentRequest

oil.setclientinterceptor{
	sendrequest = function(self, request)
		if request.object_key == "object" and request.operation == "concat" then
			checks:assert(request.response_expected, checks.is(true))
			checks:assert(request.service_context, checks.is(nil))
			checks:assert(request.success, checks.is(nil))
			checks:assert(request.count, checks.is(2))
			checks:assert(request[1], checks.is("first"))
			checks:assert(request[2], checks.is("second"))
		
			request.service_context = {
				{
					context_id = 1234,
					context_data = "1234",
				}
			}
			
			CurrentRequest = request
		end
	end,
	receivereply = function(self, reply)
		if reply == CurrentRequest then
			checks:assert(reply.request_id, checks.typeis("number"))
			checks:assert(reply.response_expected, checks.is(true))
			checks:assert(reply.object_key, checks.is("object"))
			checks:assert(reply.operation, checks.is("concat"))
			checks:assert(reply.service_context, checks.typeis("table"))
			checks:assert(reply.reply_status, checks.is("NO_EXCEPTION"))
			checks:assert(reply.success, checks.is(true))
			checks:assert(reply.count, checks.is(1))
			checks:assert(reply[1], checks.is("first&second"))
		
			checks:assert(reply.service_context[1].context_id, checks.is(4321))
			checks:assert(reply.service_context[1].context_data, checks.is("4321"))
		end
	end,
}

object:concat("first", "second")

--[Client]=====================================================================]

return Suite{
	IceptedCORBA = test{
		Server = { flavor = "intercepted;corba;typed;base" },
		Client = { flavor = "intercepted;corba;typed;base" },
	},
	CoServerIceptedCORBA = test{
		Server = { flavor = "intercepted;corba;typed;cooperative;base" },
		Client = { flavor = "intercepted;corba;typed;base" },
	},
	CoClientIceptedCORBA = test{
		Server = { flavor = "intercepted;corba;typed;base" },
		Client = { flavor = "intercepted;corba;typed;cooperative;base" },
	},
	CoIceptedCORBA = test{
		Server = { flavor = "intercepted;corba;typed;cooperative;base" },
		Client = { flavor = "intercepted;corba;typed;cooperative;base" },
	},
}
