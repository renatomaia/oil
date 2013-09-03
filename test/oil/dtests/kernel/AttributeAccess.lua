local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local T = Template{"Client"} -- master process name

T.Server = [===================================================================[
Attributes = {
	changes = 0,
	field = 0,
}
function Attributes:_get_changes()
	return self.changes
end
local value = 0
function Attributes:_get_method()
	return value
end
function Attributes:_set_method(val)
	self.changes = self.changes+1
	value = val
end

orb = oil.dtests.init{ port = 2809 }
if oil.dtests.flavor.corba then
	Attributes.__type = orb:loadidl[[
		interface Attributes {
			readonly attribute long changes;
			attribute long field;
			attribute long method;
		};
	]]
end
orb:newservant(Attributes, "object")
orb:run()
----[Server]===================================================================]

T.Client = [===================================================================[
oil.dtests.init()
checks = oil.dtests.checks
sync = oil.dtests.resolve("Server", 2809, "object")

-- synchronous call
assert(sync.changes == nil)
assert(sync.field == nil)
assert(sync.method == nil)

sync:_set_field(1234)
assert(sync:_get_field() == 1234)

sync:_set_method(1234)
assert(sync:_get_method() == 1234)

assert(sync:_get_changes() == 1)

-- asynchronous call
async = oil.dtests.orb:newproxy(sync, "asynchronous")

assert(async.changes == nil)
assert(async.field == nil)
assert(async.method == nil)

fut = async:_set_field(4321)
assert(fut:results() == true)
fut:evaluate()
fut = async:_get_field()
ok, res = fut:results()
assert(ok == true and res == 4321)
assert(fut:evaluate() == 4321)

fut = async:_set_method(4321)
assert(fut:results() == true)
fut:evaluate()
fut = async:_get_method()
ok, res = fut:results()
assert(ok == true and res == 4321)
assert(fut:evaluate() == 4321)

assert(async:_get_changes():evaluate() == 2)

-- protected synchronous call
prot = oil.dtests.orb:newproxy(sync, "protected")

assert(prot.changes == nil)
assert(prot.field == nil)
assert(prot.method == nil)

assert(prot:_set_field(5678))
ok, res = prot:_get_field()
assert(ok == true and res == 5678)

assert(prot:_set_method(5678))
ok, res = prot:_get_method()
assert(ok == true and res == 5678)

ok, res = prot:_get_changes()
assert(ok == true and res == 3)
----[Client]===================================================================]

return T:newsuite()
