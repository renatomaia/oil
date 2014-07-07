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
		assert(type(request.request_id) == "number")
		assert(request.response_expected == true)
		assert(request.reference == sync.__reference)
		assert(request.profile_tag == 0)
		assert(type(request.profile_data) == "string")
		checks.assert(request.profile, checks.like{
		                               	host = "Fake",
		                               	port = 2809,
		                               	object_key = "object",
		                               })
		assert(request.interface == MyInterface)
		assert(request.operation == MyInterface.definitions.concat)
		checks.assert(request.parameters, checks.like{"first", "second", n=2})
		assert(#request.parameters == 2)
		assert(request.service_context == nil)
		assert(request.success == nil)
		assert(request.results == nil)
		assert(request.reply_service_context == nil)
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
		assert(reply == info.request)
		assert(reply.request_id == info.request_id)
		assert(reply.response_expected == true)
		assert(reply.object_key == "object")
		assert(reply.reference == info.reference)
		assert(reply.profile_tag == 0)
		assert(reply.profile_data == info.profile_data)
		assert(reply.profile == info.profile)
		checks.assert(reply.profile, checks.like{
		                             	host = "Fake",
		                             	port = 2809,
		                             	object_key = "object",
		                             })
		assert(reply.interface == MyInterface)
		assert(reply.operation_name == "concat")
		assert(reply.operation == MyInterface.definitions.concat)
		assert(type(reply.success) == "boolean")
		assert(reply.parameters == info.parameters)
		checks.assert(reply.parameters, checks.like{"first", "second", n=2})
		assert(reply.service_context == nil)
		assert(reply.success == false)
		checks.assert(reply.results, checks.like{
		                             	{
		                             		_repid = "IDL:omg.org/CORBA/TRANSIENT:1.0",
		                             		completed = "COMPLETED_NO",
		                             		minor = 2,
		                             		error = "badconnect",
		                             		errmsg = "host not found",
		                             		host = "Fake",
		                             		port = 2809,
		                             		profile = {tag=0},
		                             	},
		                             	n = 1,
		                             })
		assert(reply.reply_service_context == nil)
		assert(reply.reply_status == nil)
		self.lastConcatRequest = false
	end
end

orb = oil.dtests.init()
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
ok, res = pcall(sync.concat, sync, "first", "second")
assert(ok == false)
checks.assert(res, checks.like{
                   	_repid = "IDL:omg.org/CORBA/TRANSIENT:1.0",
                   	completed = "COMPLETED_NO",
                   	minor = 2,
                   })
assert(Interceptor.lastConcatRequest == false)

Interceptor.lastConcatRequest = nil
ok, res = async:concat("first", "second"):results()
assert(ok == false)
checks.assert(res, checks.like{
                   	_repid = "IDL:omg.org/CORBA/TRANSIENT:1.0",
                   	completed = "COMPLETED_NO",
                   	minor = 2,
                   })
assert(Interceptor.lastConcatRequest == false)

Interceptor.lastConcatRequest = nil
ok, res = prot:concat("first", "second")
assert(ok == false)
checks.assert(res, checks.like{
                   	_repid = "IDL:omg.org/CORBA/TRANSIENT:1.0",
                   	completed = "COMPLETED_NO",
                   	minor = 2,
                   })
assert(Interceptor.lastConcatRequest == false)

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ corba = true, interceptedcorba = true }
