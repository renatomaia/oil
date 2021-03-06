local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
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
Interceptor = {}
function Interceptor:sendrequest(request)
	if request.object_key == "object"
	and request.operation_name == "concat"
	then
		if request.reference == forward.__reference then
			FinalRequestId = request.request_id
		else
			request.reference = forward.__reference
		end
	end
end
function Interceptor:receivereply(request)
	if request.object_key == "object"
	and request.operation_name == "concat"
	then
		assert(request.request_id == FinalRequestId)
		FinalRequestId = true
	end
end

orb = oil.dtests.init()
orb:setclientinterceptor(Interceptor)
forward = oil.dtests.resolve("Server", 2809, "object")
sync = oil.dtests.resolve("Fake", 2809, "object", nil, true, true)
sync = orb:narrow(sync, "MyInterface")
async = orb:newproxy(sync, "asynchronous")
prot = orb:newproxy(sync, "protected")

FinalRequestId = nil
assert(sync:concat("first", "second") == "first&second")
assert(FinalRequestId == true)

FinalRequestId = nil
assert(async:concat("first", "second"):evaluate() == "first&second")
assert(FinalRequestId == true)

FinalRequestId = nil
ok, res = prot:concat("first", "second")
assert(ok == true)
assert(res == "first&second")
assert(FinalRequestId == true)

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ corba = true, interceptedcorba = true }
