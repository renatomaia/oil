local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
checks = oil.dtests.checks

obj = {concat = function(s1, s2) return s1..s2 end}

Interceptor = {}
function Interceptor:receiverequest(request)
	if request.object_key == "object"
	and request.operation_name == "concat"
	then
		error("Oops!")
	end
end

orb = oil.dtests.init{ port = 2809 }
orb:setserverinterceptor(Interceptor)
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

ok, ex = pcall(sync.concat, sync, "first", "second")
assert(ok == false)
assert(type(ex) == "table")

oil.verbose:print("ex = ",ex)

assert(ex._repid == "IDL:omg.org/CORBA/UNKNOWN:1.0")
assert(ex.completed == "COMPLETED_MAYBE")

res = async:concat("first", "second")
ok, ex = res:results()
assert(ok == false)
assert(type(ex) == "table")
assert(ex._repid == "IDL:omg.org/CORBA/UNKNOWN:1.0")
assert(ex.completed == "COMPLETED_MAYBE")
ok, ex = pcall(res.evaluate, res)
assert(ok == false)
assert(type(ex) == "table")
assert(ex._repid == "IDL:omg.org/CORBA/UNKNOWN:1.0")
assert(ex.completed == "COMPLETED_MAYBE")

ok, res = prot:concat("first", "second")
assert(ok == false)
assert(type(ex) == "table")
assert(ex._repid == "IDL:omg.org/CORBA/UNKNOWN:1.0")
assert(ex.completed == "COMPLETED_MAYBE")
--[Client]=====================================================================]

return template:newsuite{ corba = true, interceptedcorba = true }
