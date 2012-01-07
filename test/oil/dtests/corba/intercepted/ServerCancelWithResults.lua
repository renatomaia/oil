local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
checks = oil.dtests.checks

Interceptor = {}
function Interceptor:receiverequest(request)
	if request.object_key == "object"
	and request.operation_name == "concat"
	then
		request.success = true
		request.results = { request.parameters[1].."&"..request.parameters[2] }
	end
end

orb = oil.dtests.init{ port = 2809 }
orb:setserverinterceptor(Interceptor)
orb:loadidl[[
	interface MyInterface {
		string concat(in string str1, in string str2);
	};
]]
orb:newservant({}, "object", "::MyInterface")
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks

orb = oil.dtests.init()
sync = oil.dtests.resolve("Server", 2809, "object")
orb:loadidl[[
	interface MyInterface {
		string concat(in string str1, in string str2);
	};
]]
sync = orb:narrow(sync, "MyInterface")
async = orb:newproxy(sync, "asynchronous")
prot = orb:newproxy(sync, "protected")

checks:assert(sync:concat("first", "second"), checks.is("first&second"))
checks:assert(async:concat("first", "second"):evaluate(), checks.is("first&second"))
ok, res = prot:concat("first", "second")
checks:assert(ok, checks.is(true))
checks:assert(res, checks.is("first&second"))
--[Client]=====================================================================]

return template:newsuite{ corba = true, interceptedcorba = true }
