local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
orb = oil.dtests.init{ port = 2809, maxchannels = 10 }
if oil.dtests.flavor.corba then
	orb:loadidl[[ interface Hello { void say(); }; ]]
end
ref = tostring(orb:newservant{
	__type = "IDL:Hello:1.0",
	__objkey = "Hello",
	say = function () end,
})
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks
orb = oil.dtests.init()
obj = oil.dtests.resolve("Server", 2809, "Hello")
ref = tostring(obj)
orb:shutdown()

orbs = {}
proxies = {}
for i = 1, 1e2 do -- due to MacOSX file descriptor limit of 256.
	orbs[i] = oil.dtests.init{}
	proxies[i] = orbs[i]:newproxy(ref)
	proxies[i]:say()
end

for _, orb in ipairs(orbs) do
	orb:shutdown()
end
--[Client]=====================================================================]

return template:newsuite()
