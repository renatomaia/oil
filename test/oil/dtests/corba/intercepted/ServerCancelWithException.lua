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
		request.success = false
		request.results = { orb:newexcept{ "NO_PERMISSION" } }
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

orb = oil.dtests.init{ extraproxies = { "asynchronous", "protected" } }
sync = oil.dtests.resolve("Server", 2809, "object")
async = orb:newproxy(sync, "asynchronous")
prot = orb:newproxy(sync, "protected")

ok, res = pcall(sync.concat, sync, "first", "second")
checks:assert(ok, checks.is(false))
checks:assert(res[1], checks.is("IDL:omg.org/CORBA/NO_PERMISSION:1.0"))

ok, res = async:concat("first", "second"):results()
checks:assert(ok, checks.is(false))
checks:assert(res[1], checks.is("IDL:omg.org/CORBA/NO_PERMISSION:1.0"))

ok, res = prot:concat("first", "second")
checks:assert(ok, checks.is(false))
checks:assert(res[1], checks.is("IDL:omg.org/CORBA/NO_PERMISSION:1.0"))
--[Client]=====================================================================]

return template:newsuite{ corba = true, interceptedcorba = true }
