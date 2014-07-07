local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Client = [=====================================================================[
Interceptor = {}
function Interceptor:sendrequest(request)
	if request.object_key == "object"
	and request.operation_name == "concat"
	then
		request.success = true
		request.results = { request.parameters[1].."&"..request.parameters[2] }
	end
end
function Interceptor:receivereply(request)
	if request.object_key == "object"
	and request.operation_name == "concat"
	then
		assert(request.success == true)
		InterceptedResult = request.results[1]
	end
end

orb = oil.dtests.init()
orb:setclientinterceptor(Interceptor)
sync = oil.dtests.resolve("Server", 2809, "object", nil, true, true)
orb:loadidl[[
	interface MyInterface {
		string concat(in string str1, in string str2);
	};
]]
sync = orb:narrow(sync, "MyInterface")
async = orb:newproxy(sync, "asynchronous")
prot = orb:newproxy(sync, "protected")

InterceptedResult = nil
assert(sync:concat("first", "second") == "first&second")
assert(InterceptedResult == "first&second")

InterceptedResult = nil
assert(async:concat("first", "second"):evaluate() == "first&second")
assert(InterceptedResult == "first&second")

InterceptedResult = nil
ok, res = prot:concat("first", "second")
assert(ok == true)
assert(res == "first&second")
assert(InterceptedResult == "first&second")

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ corba = true, interceptedcorba = true }
