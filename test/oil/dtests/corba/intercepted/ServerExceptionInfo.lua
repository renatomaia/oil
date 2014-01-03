local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
checks = oil.dtests.checks

Object = {}
function Object:concat(str1, str2)
	checks:assert(Interceptor.lastConcatRequest, checks.isnot(nil))
	error("Oops!")
end

Interceptor = {}
function Interceptor:receiverequest(request)
	if request.object_key == "object"
	and request.operation_name == "concat"
	then
		checks:assert(request.request_id,            checks.typeis("number"))
		checks:assert(request.response_expected,     checks.is(true))
		checks:assert(request.servant,               checks.is(Object))
		checks:assert(request.interface,             checks.is(MyInterface))
		checks:assert(request.operation,             checks.is(MyInterface.definitions.concat))
		checks:assert(request.parameters,            checks.similar{"first", "second", n=2})
		checks:assert(#request.parameters,           checks.is(2))
		checks:assert(request.service_context,       checks.similar({}, nil, {isomorphic=true}))
		checks:assert(request.success,               checks.is(nil))
		checks:assert(request.results,               checks.is(nil))
		checks:assert(request.reply_service_context, checks.is(nil))
		self.lastConcatRequest = {
			request = request,
			request_id = request.request_id,
			parameters = request.parameters,
			service_context = request.service_context,
		}
	end
end
function Interceptor:sendreply(reply)
	local info = self.lastConcatRequest
	if info then
		checks:assert(reply,                       checks.is(info.request))
		checks:assert(reply.request_id,            checks.is(info.request_id))
		checks:assert(reply.response_expected,     checks.is(true))
		checks:assert(reply.object_key,            checks.is("object"))
		checks:assert(reply.servant,               checks.is(Object))
		checks:assert(reply.interface,             checks.is(MyInterface))
		checks:assert(reply.operation_name,        checks.is("concat"))
		checks:assert(reply.operation,             checks.is(MyInterface.definitions.concat))
		checks:assert(reply.parameters,            checks.is(info.parameters))
		checks:assert(reply.parameters,            checks.similar{"first", "second", n=2})
		checks:assert(#reply.parameters,           checks.is(2))
		checks:assert(reply.service_context,       checks.is(info.service_context))
		checks:assert(reply.service_context,       checks.similar({}, nil, {isomorphic=true}))
		checks:assert(reply.success,               checks.is(false))
		checks:assert(reply.results,               checks.similar{
		                                           	{
		                                           		_repid = "IDL:omg.org/CORBA/UNKNOWN:1.0",
		                                           		completed = "COMPLETED_MAYBE",
		                                           		minor = 0,
		                                           		error = '[string "Server"]:6: Oops!',
		                                           	},
		                                           	n = 1,
		                                           })
		checks:assert(reply.reply_status,          checks.is("SYSTEM_EXCEPTION"))
		checks:assert(reply.reply_service_context, checks.is(nil))
		self.lastConcatRequest = nil
	end
end

orb = oil.dtests.init{ port = 2809 }
orb:setserverinterceptor(Interceptor)
MyInterface = orb:loadidl[[
	interface MyInterface {
		string concat(in string str1, in string str2);
	};
]]
orb:newservant(Object, "object", "::MyInterface")
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks

Interceptor = {}
function Interceptor:sendrequest(request)
	if request.object_key == "object"
	and request.operation_name == "concat"
	then
		checks:assert(request.request_id,            checks.typeis("number"))
		checks:assert(request.response_expected,     checks.is(true))
		checks:assert(request.reference,             checks.is(sync.__reference))
		checks:assert(request.profile_tag,           checks.is(0))
		checks:assert(request.profile_data,          checks.typeis("string"))
		checks:assert(request.profile,               checks.similar{
		                                             	host = oil.dtests.hosts.Server,
		                                             	port = 2809,
		                                             	object_key = "object",
		                                             	iiop_version = {
		                                             		major = 1,
		                                             		minor = 0,
		                                             	}
		                                             })
		checks:assert(request.interface,             checks.is(MyInterface))
		checks:assert(request.operation,             checks.is(MyInterface.definitions.concat))
		checks:assert(request.parameters,            checks.similar{"first", "second", n=2})
		checks:assert(#request.parameters,           checks.is(2))
		checks:assert(request.service_context,       checks.is(nil))
		checks:assert(request.success,               checks.is(nil))
		checks:assert(request.results,               checks.is(nil))
		checks:assert(request.reply_service_context, checks.is(nil))
		self.lastConcatRequest = {
			request = request,
			request_id = request.request_id,
			reference = request.reference,
			profile_data = request.profile_data,
			profile = request.profile,
			parameters = request.parameters,
		}
	end
end
function Interceptor:receivereply(reply)
	local info = self.lastConcatRequest
	if info then
		checks:assert(reply,                        checks.is(info.request))
		checks:assert(reply.request_id,             checks.is(info.request_id))
		checks:assert(reply.response_expected,      checks.is(true))
		checks:assert(reply.object_key,             checks.is("object"))
		checks:assert(reply.reference,              checks.is(info.reference))
		checks:assert(reply.profile_tag,            checks.is(0))
		checks:assert(reply.profile_data,           checks.is(info.profile_data))
		checks:assert(reply.profile,                checks.similar{
		                                            	host = oil.dtests.hosts.Server,
		                                            	port = 2809,
		                                            	object_key = "object",
		                                            	iiop_version = {
		                                            		major = 1,
		                                            		minor = 0,
		                                            	}
		                                            })
		checks:assert(reply.interface,              checks.is(MyInterface))
		checks:assert(reply.operation_name,         checks.is("concat"))
		checks:assert(reply.operation,              checks.is(MyInterface.definitions.concat))
		checks:assert(reply.parameters,             checks.is(info.parameters))
		checks:assert(reply.parameters,             checks.similar{"first", "second", n=2})
		checks:assert(#reply.parameters,            checks.is(2))
		checks:assert(reply.service_context,        checks.is(nil))
		checks:assert(reply.success,                checks.is(false))
		checks:assert(reply.results,                checks.similar{
		                                            	{
		                                            		_repid = "IDL:omg.org/CORBA/UNKNOWN:1.0",
		                                            		completed = "COMPLETED_MAYBE",
		                                            		minor = 0,
		                                            	},
		                                            	n = 1,
		                                            })
		checks:assert(#reply.results,               checks.is(1))
		checks:assert(reply.reply_status,           checks.is("SYSTEM_EXCEPTION"))
		checks:assert(reply.reply_service_context,  checks.isnot(info.service_context))
		checks:assert(reply.reply_service_context,  checks.similar({}, nil, {isomorphic=true}))
		self.lastConcatRequest = false
	end
end

orb = oil.dtests.init()
orb:setclientinterceptor(Interceptor)
sync = oil.dtests.resolve("Server", 2809, "object")
async = orb:newproxy(sync, "asynchronous")
prot = orb:newproxy(sync, "protected")
MyInterface = orb.types:resolve("MyInterface")

Interceptor.lastConcatRequest = nil
ok, res = pcall(sync.concat, sync, "first", "second")
checks:assert(ok, checks.is(false))
checks:assert(res, checks.similar{
                   	_repid = "IDL:omg.org/CORBA/UNKNOWN:1.0",
                   	completed = "COMPLETED_MAYBE",
                   	minor = 0,
                   })
checks:assert(Interceptor.lastConcatRequest, checks.is(false))

Interceptor.lastConcatRequest = nil
ok, res = async:concat("first", "second"):results()
checks:assert(ok, checks.is(false))
checks:assert(res, checks.similar{
                   	_repid = "IDL:omg.org/CORBA/UNKNOWN:1.0",
                   	completed = "COMPLETED_MAYBE",
                   	minor = 0,
                   })
checks:assert(Interceptor.lastConcatRequest, checks.is(false))

Interceptor.lastConcatRequest = nil
ok, res = prot:concat("first", "second")
checks:assert(ok, checks.is(false))
checks:assert(res, checks.similar{
                   	_repid = "IDL:omg.org/CORBA/UNKNOWN:1.0",
                   	completed = "COMPLETED_MAYBE",
                   	minor = 0,
                   })
checks:assert(Interceptor.lastConcatRequest, checks.is(false))

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ corba = true, interceptedcorba = true }
