local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local T = Template{"Client"} -- master process name

T.Client = [===================================================================[
checks = oil.dtests.checks

Exception = io.stderr

Interceptor = {}
function Interceptor:sendrequest(request)
	if request.object_key == "object"
	and request.operation_name == "concat"
	then
		request.success = false
		request.results = { Exception }
	end
end
function Interceptor:receivereply(request)
	if request.object_key == "object"
	and request.operation_name == "concat"
	then
		checks:assert(request.success, checks.is(false))
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
ok, res = pcall(sync.concat, sync, "first", "second")
checks:assert(ok, checks.is(false))
checks:assert(res, checks.is(Exception))
checks:assert(InterceptedResult, checks.is(Exception))

InterceptedResult = nil
ok, res = async:concat("first", "second"):results()
checks:assert(ok, checks.is(false))
checks:assert(res, checks.is(Exception))
checks:assert(InterceptedResult, checks.is(Exception))

InterceptedResult = nil
ok, res = prot:concat("first", "second")
checks:assert(ok, checks.is(false))
checks:assert(res, checks.is(Exception))
checks:assert(InterceptedResult, checks.is(Exception))
----[Client]===================================================================]

return T:newsuite{ corba = true, interceptedcorba = true }
