local Template = require "oil.dtests.Template"
local _ENV = Template{"Client"} -- master process name

for i = 1, 5e2 do
	_ENV["Server"..i] = [[
		orb = oil.dtests.init{ port = 4809+]]..i..[[ }
		if oil.dtests.flavor.corba then
			orb:loadidl"interface Hello { void say(); };"
		end
		ref = tostring(orb:newservant{
			__type = "IDL:Hello:1.0",
			__objkey = "Hello",
			say = function () end,
		})
		orb:run()
	]]
end

Client = [=====================================================================[
checks = oil.dtests.checks
oil.dtests.timeout = 20

orb = oil.dtests.init{ maxchannels = nil }

objs = {}
futs = {}
for i = 1, 5e2 do
	local obj = oil.dtests.resolve("Server"..i, 4809+i, "Hello")
	objs[i] = orb:newproxy(obj, "asynchronous")
end
for i, obj in ipairs(objs) do
	futs[i] = obj:say()
end
for i, fut in ipairs(futs) do
	fut:evaluate()
end

orb:shutdown()
--[Client]=====================================================================]

return _ENV:newsuite()
