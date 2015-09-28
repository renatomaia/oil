local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Client = [=====================================================================[
checks = oil.dtests.checks

iface = [[ interface Hello { void say(); }; ]]
orbs = {}
refs = {}

for i = 1, 1e2 do
	orbs[i] = oil.dtests.init{}
	if oil.dtests.flavor.corba then
		orbs[i]:loadidl(iface)
	end
	refs[i] = tostring(orbs[i]:newservant{
		__type = "IDL:Hello:1.0",
		__objkey = "Hello",
		say = function () end,
	})
end

orb = oil.dtests.init{ maxchannels = 10 }
if oil.dtests.flavor.corba then
	orb:loadidl(iface)
end

proxies = {}
results = {}
for i, ref in ipairs(refs) do
	proxies[i] = orb:newproxy(ref, "asynchronous", "Hello")
	results[i] = proxies[i]:say()
end
for i in ipairs(results) do
	results[i]:evaluate()
end

orb:shutdown()
for _, orb in ipairs(orbs) do
	orb:shutdown()
end
--[Client]=====================================================================]

return template:newsuite{ cooperative = true }
