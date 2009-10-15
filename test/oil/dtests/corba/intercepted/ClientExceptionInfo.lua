local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

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
		checks:assert(request.profile_data,          checks.similar{
		                                             	host = "Fake",
		                                             	port = 2809,
		                                             	object_key = "object",
		                                             })
		checks:assert(request.interface_name,        checks.is("::MyInterface"))
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
			profile = request.profile_data,
			parameters = request.parameters,
		}
	end
end
function Interceptor:receivereply(reply)
	local info = self.lastConcatRequest
	if info then
		checks:assert(reply,                       checks.is(info.request))
		checks:assert(reply.request_id,            checks.is(info.request_id))
		checks:assert(reply.response_expected,     checks.is(true))
		checks:assert(reply.object_key,            checks.is("object"))
		checks:assert(reply.reference,             checks.is(info.reference))
		checks:assert(reply.profile_tag,           checks.is(0))
		checks:assert(reply.profile_data,          checks.is(info.profile))
		checks:assert(reply.profile_data,          checks.similar{
		                                           	host = "Fake",
		                                           	port = 2809,
		                                           	object_key = "object",
		                                           })
		checks:assert(reply.interface_name,        checks.is("::MyInterface"))
		checks:assert(reply.interface,             checks.is(MyInterface))
		checks:assert(reply.operation_name,        checks.is("concat"))
		checks:assert(reply.operation,             checks.is(MyInterface.definitions.concat))
		checks:assert(reply.success,               checks.typeis("boolean"))
		checks:assert(reply.parameters,            checks.is(info.parameters))
		checks:assert(reply.parameters,            checks.similar{"first", "second", n=2})
		checks:assert(reply.service_context,       checks.is(nil))
		checks:assert(reply.success,               checks.is(false))
		checks:assert(reply.results,               checks.similar{
		                                           	{
		                                           		"IDL:omg.org/CORBA/COMM_FAILURE:1.0",
		                                           		completion_status = 1,
		                                           		minor_code_value = 1,
		                                           	},
		                                           	n = 1,
		                                           })
		checks:assert(reply.reply_service_context, checks.is(nil))
		checks:assert(reply.reply_status,          checks.is(nil))
		self.lastConcatRequest = false
	end
end

orb = oil.dtests.init{ extraproxies = { "asynchronous", "protected" } }
orb:setclientinterceptor(Interceptor)
sync = oil.dtests.resolve("Fake", 2809, "object", nil, true, true)
MyInterface = orb:loadidl[[
	interface MyInterface {
		string concat(in string str1, in string str2);
	};
]]
sync = orb:narrow(sync, "MyInterface")
async = orb:newproxy(sync, "asynchronous")
prot = orb:newproxy(sync, "protected")

Interceptor.lastConcatRequest = nil
ok, res = oil.pcall(sync.concat, sync, "first", "second")
checks:assert(ok, checks.is(false))
checks:assert(res, checks.similar{
                   	"IDL:omg.org/CORBA/COMM_FAILURE:1.0",
                   	completion_status = 1,
                   	minor_code_value = 1,
                   })
checks:assert(Interceptor.lastConcatRequest, checks.is(false))

Interceptor.lastConcatRequest = nil
ok, res = async:concat("first", "second"):results()
checks:assert(ok, checks.is(false))
checks:assert(res, checks.similar{
                   	"IDL:omg.org/CORBA/COMM_FAILURE:1.0",
                   	completion_status = 1,
                   	minor_code_value = 1,
                   })
checks:assert(Interceptor.lastConcatRequest, checks.is(false))

Interceptor.lastConcatRequest = nil
ok, res = prot:concat("first", "second")
checks:assert(ok, checks.is(false))
checks:assert(res, checks.similar{
                   	"IDL:omg.org/CORBA/COMM_FAILURE:1.0",
                   	completion_status = 1,
                   	minor_code_value = 1,
                   })
checks:assert(Interceptor.lastConcatRequest, checks.is(false))

--[Client]=====================================================================]

return template:newsuite{ corba = true, interceptedcorba = true }
