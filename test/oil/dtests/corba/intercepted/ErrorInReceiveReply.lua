local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
checks = oil.dtests.checks

obj = {concat = function(self, s1, s2) return s1..s2 end}

orb = oil.dtests.init{ port = 2809 }
orb:loadidl[[
	interface MyInterface {
		string concat(in string str1, in string str2);
	};
]]
orb:newservant(obj, "object", "::MyInterface")
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks

Interceptor = {}
function Interceptor:receivereply(request)
	if request.object_key == "object"
	and request.operation_name == "concat"
	then
		error("Oops!")
	end
end

orb = oil.dtests.init{ extraproxies = { "asynchronous", "protected" } }
orb:setclientinterceptor(Interceptor)
sync = oil.dtests.resolve("Server", 2809, "object")
orb:loadidl[[
	interface MyInterface {
		string concat(in string str1, in string str2);
	};
]]
sync = orb:narrow(sync, "MyInterface")
async = orb:newproxy(sync, "asynchronous")
prot = orb:newproxy(sync, "protected")

ok, ex = pcall(sync.concat, sync, "first", "second")
assert(ok == false)
assert(type(ex) == "string")
assert(ex:match("Oops!$"))

res = async:concat("first", "second")
ok, ex = res:results()
assert(ok == false)
assert(type(ex) == "string")
assert(ex:match("Oops!$"))
ok, ex = pcall(res.evaluate, res)
assert(ok == false)
assert(type(ex) == "string")
assert(ex:match("Oops!$"))

ok, res = prot:concat("first", "second")
assert(ok == false)
assert(type(ex) == "string")
assert(ex:match("Oops!$"))
--[Client]=====================================================================]

return template:newsuite{ corba = true, interceptedcorba = true }
