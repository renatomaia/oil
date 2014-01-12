local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
Object = {}
function Object:concat(str1, str2)
	return str1.."&"..str2
end

Interceptor = {}
function Interceptor:sendreply(reply)
	if reply.object_key == "object"
	and reply.operation_name == "concat"
	then
		reply.reply_service_context = { [1234] = "1234" }
	end
end

orb = oil.dtests.init{ port = 2809 }
orb:setserverinterceptor(Interceptor)
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
function Interceptor:receivereply(reply)
	if reply.object_key == "object"
	and reply.operation_name == "concat"
	then
		assert(type(reply.reply_service_context) == "table")
		checks.assert(reply.reply_service_context, checks.like({[1234]="1234"}, nil, {isomorphic=true}))
		self.success = true
	end
end

orb = oil.dtests.init()
orb:setclientinterceptor(Interceptor)
sync = oil.dtests.resolve("Server", 2809, "object")
async = orb:newproxy(sync, "asynchronous")
prot = orb:newproxy(sync, "protected")

Interceptor.success = nil
assert(sync:concat("first", "second") == "first&second")
assert(Interceptor.success == true)

Interceptor.success = nil
assert(async:concat("first", "second"):evaluate() == "first&second")
assert(Interceptor.success == true)

Interceptor.success = nil
ok, res = prot:concat("first", "second")
assert(ok == true)
assert(res == "first&second")
assert(Interceptor.success == true)

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ corba = true, interceptedcorba = true }
