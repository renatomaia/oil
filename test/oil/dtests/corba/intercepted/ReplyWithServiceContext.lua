local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
checks = oil.dtests.checks

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
		checks:assert(reply.reply_service_context, checks.typeis("table"))
		checks:assert(reply.reply_service_context, checks.similar({[1234]="1234"}, nil, {isomorphic=true}))
		self.success = true
	end
end

orb = oil.dtests.init()
orb:setclientinterceptor(Interceptor)
sync = oil.dtests.resolve("Server", 2809, "object")
async = orb:newproxy(sync, "asynchronous")
prot = orb:newproxy(sync, "protected")

Interceptor.success = nil
checks:assert(sync:concat("first", "second"), checks.is("first&second"))
checks:assert(Interceptor.success, checks.is(true))

Interceptor.success = nil
checks:assert(async:concat("first", "second"):evaluate(), checks.is("first&second"))
checks:assert(Interceptor.success, checks.is(true))

Interceptor.success = nil
ok, res = prot:concat("first", "second")
checks:assert(ok, checks.is(true))
checks:assert(res, checks.is("first&second"))
checks:assert(Interceptor.success, checks.is(true))

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ corba = true, interceptedcorba = true }
