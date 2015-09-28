local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Client = [=====================================================================[
checks = oil.dtests.checks

iface = [[ interface Hello { void say(); }; ]]

orb = oil.dtests.init{ maxchannels = 20 }
if oil.dtests.flavor.corba then
	orb:loadidl(iface)
end
ref = tostring(orb:newservant{
	__type = "IDL:Hello:1.0",
	__objkey = "Hello",
	say = function () end,
})

orbs = {}
proxies = {}
for i = 1, 1e2 do
	orbs[i] = oil.dtests.init{}
	if oil.dtests.flavor.corba then
		orbs[i]:loadidl(iface)
	end
	proxies[i] = orbs[i]:newproxy(ref, nil, "Hello")
	proxies[i]:say()
end

orb:shutdown()
for _, orb in ipairs(orbs) do
	orb:shutdown()
end
--[Client]=====================================================================]

return template:newsuite{ cooperative = true }
