local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
ObjectMapMeta = {}

orb = oil.dtests.init{
	port = 2809,
	objectmap = setmetatable({}, ObjectMapMeta),
}

if oil.dtests.flavor.corba then
	HolderType = orb:loadidl[[interface Holder {
		string get();
		void set(in string value);
		void dispose();
	};]]
end

function ObjectMapMeta:__index(objkey)
	if objkey:sub(1, 1) ~= "_" then
		local holder = {__objkey = objkey}
		function holder:get()
			return self.value or self.__objkey
		end
		function holder:set(value)
			self.value = value
		end
		function holder:dispose()
			local ok, ex = orb:deactivate(self)
			if not ok then error(ex) end
		end
		
		local entry = { __servant = holder }
		if oil.dtests.flavor.corba then
			entry.__type = HolderType
		end
		rawset(self, objkey, entry)
		return entry
	end
end

orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
orb = oil.dtests.init()

local var = {}
for i = 1, 3 do
	var[i] = oil.dtests.resolve("Server", 2809, "var"..i)
	assert(var[i]:get() == "var"..i)
	var[i]:set("I'm variable number "..i)
end
for i = 1, 3 do
	assert(var[i]:get() == "I'm variable number "..i)
	var[i]:dispose()
end
for i = 1, 3 do
	assert(var[i]:get() == "var"..i)
end

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite()
