local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
checks = oil.dtests.checks

Object = {}
function Object:concat(str1, str2)
	return str1.."&"..str2
end

orb = oil.dtests.init{ port = 2809 }
orb:loadidl[[
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
function Interceptor:receivereply(request)
	if request.object_key == "object"
	and request.operation_name == "concat"
	then
		request.success = nil
		request.reference = forward.__reference
	end
end

orb = oil.dtests.init()
orb:setclientinterceptor(Interceptor)
forward = oil.dtests.resolve("Server", 2809, "object")
sync = oil.dtests.resolve("Fake", 2809, "object", nil, true, true)
sync = orb:narrow(sync, "MyInterface")
async = orb:newproxy(sync, "asynchronous")
prot = orb:newproxy(sync, "protected")

oil.verbose:level(4)
oil.verbose:flag("interceptors", true)

checks:assert(sync:concat("first", "second"), checks.is("first&second"))
checks:assert(async:concat("first", "second"):evaluate(), checks.is("first&second"))
ok, res = prot:concat("first", "second")
checks:assert(ok, checks.is(true))
checks:assert(res, checks.is("first&second"))
--[Client]=====================================================================]

return template:newsuite{ corba = true, interceptedcorba = true }
