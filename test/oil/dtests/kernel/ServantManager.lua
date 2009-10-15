local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[

ObjectMapMeta = {}
orb = oil.dtests.init{
	port = 2809,
	objectmap = setmetatable({}, ObjectMapMeta),
}
function ObjectMapMeta:__index(objkey)
	if objkey:sub(1, 1) ~= "_" then
		local holder = Holder{ __objkey = objkey }
		if oil.dtests.flavor.corba then
			holder = { object = holder, type = holder.__type }
		end
		return holder
	end
end

oo = require "oil.oo"
Holder = oo.class()
function Holder:get()
	return self.value or self.__objkey
end
function Holder:set(value)
	self.value = value
end
if oil.dtests.flavor.corba then
	Holder.__type = orb:loadidl[[interface Holder {
		string get();
		void set(in string value);
		void dispose();
	};]]
end

orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks

orb = oil.dtests.init()

local var = {}
for i = 1, 3 do
	var[i] = oil.dtests.resolve("Server", 2809, "var"..i)
	checks:assert(var[i]:get(), checks.is("var"..i))
	var[i]:set("I'm variable number "..i)
end
for i = 1, 3 do
	checks:assert(var[i]:get(), checks.is("var"..i))
end
--[Client]=====================================================================]

return template:newsuite()
