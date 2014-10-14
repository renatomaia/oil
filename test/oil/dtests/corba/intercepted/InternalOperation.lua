local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
Object = {}
function Object:someoperation()
	return "I'm some operation"
end

Interceptor = {}
function Interceptor:receiverequest(request)
	if request.object_key == "objectA"
	and request.operation_name == "_is_a"
	then
		oil.sleep(1)
	end
end

orb = oil.dtests.init{ port = 2809 }
orb:setserverinterceptor(Interceptor)
orb:loadidl[[
	interface A { void someoperation(); };
	interface B { void someoperation(); };
]]
orb:newservant(Object, "objectA", "::A")
orb:newservant(Object, "objectB", "::B")
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
orb = oil.dtests.init()
objA = orb:newproxy(oil.dtests.resolve("Server", 2809, "objectA"), "asynchronous")
objB = oil.dtests.resolve("Server", 2809, "objectB")

local fut = objA:_is_a("IDL:A:1.0")
assert(objB:_is_a("IDL:B:1.0") == true)
assert(fut:evaluate() == true)

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ corba = true, interceptedcorba = true }
