require "oil.iiop"  -- transport protocol used (CORBA default is IIOP)
require "oil.ior"   -- for decode of stringfied IOR
require "oil.proxy" -- use of sugar of proxy objects for method invokation
--------------------------------------------------------------------------------
local iface = oil.idl.interface{
	repID = "IDL:Hello/Hello:1.0",
	name = "Hello",
	members = {
		quiet = oil.idl.attribute{ oil.idl.boolean },
		count = oil.idl.attribute{ oil.idl.long, readonly=true },
		say_hello_to = oil.idl.operation{
			parameters = {
				{ type = oil.idl.Object("IDL:Hello/Person:1.0"), name = "person" }
			},
			result = oil.idl.string,
		},
		new_person = oil.idl.operation{
			parameters = {
				{ type = oil.idl.string , name = "name" },
				{ type = oil.idl.boolean, name = "male" },
			},
			result = oil.idl.Object("IDL:Hello/Person:1.0"),
		},
	},
}
--------------------------------------------------------------------------------
local proxy = oil.proxy.class(iface)
--------------------------------------------------------------------------------
local objects = {}
for _, path in ipairs(arg) do
	local file = io.open(path)
	if file then
		table.insert(objects, oil.ior.decode(file:read("*a")))
		file:close()
	else
		io.stderr:write("unable to read IOR files ", path)
	end
end
if table.getn(objects) < 2 then
	io.stderr:write("unable to get IORs\n")
	os.exit(1)
end
--------------------------------------------------------------------------------
for _, object in ipairs(objects) do
	proxy(object)
end
--------------------------------------------------------------------------------
io.write "Type your name\n> "
local name = io.read()
io.write "Are you a male? [yes, no]\n> "
local male = string.find(string.lower(io.read()), "^y") ~= nil
--------------------------------------------------------------------------------
objects[1].quiet = false
print(objects[1]:say_hello_to(objects[2]:new_person(name, male)))
