local oil = require "oil"

local function returnexception(proxy, exception, operation)
	if
		operation.name == "read" and
		exception[1] == "IDL:Control/AccessError:1.0"
	then
		return nil, exception.reason
	end
	error(exception)
end

oil.main(function()
	local orb = oil.init()
	local Server
	
	local success, exception = pcall(function()
		Server = orb:newproxy(oil.readfrom("ref.ior"))
		print("Value of 'a_number' is ", Server:read("a_number")._anyval)
		Server:write("a_number", "bad value") -- raises an exception to be captured!
	end)
	if not success then
		if exception._repid == "IDL:Control/AccessError:1.0" 
			then print(string.format("Got error: %s '%s'", exception.reason, exception.tagname))
			else print("Got unkown exception:", exception)
		end
	end
	
	orb:setexcatch(returnexception, "Control::Server") -- set an exception handler
	
	local success, exception = pcall(function()
		local value, errmsg = Server:read("unknown") -- exception handled by 'returnexception'
		if value
			then print("Value of 'unknown' is ", value._anyval)
			else print("Error on 'unknown' access:", errmsg)
		end
		Server:write("unknown", 1234) -- exception will be re-raised by 'returnexception'
	end)
	if not success then
		if exception._repid == "IDL:Control/AccessError:1.0" 
			then print(string.format("Got error: %s '%s'", exception.reason, exception.tagname))
			else print("Got unkown exception:", exception)
		end
	end
end)
