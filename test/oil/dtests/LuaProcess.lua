local socket = require "socket.core"
local Runner = require "loop.test.Results"
local Message = "%s\n%d\n%s\n"
local conn = assert(socket.tcp())
assert(conn:connect(HOST, PORT))
local runner = Runner()
local result, errmsg = conn:receive() -- get chunk name
if result then
	local name = result
	result, errmsg = conn:receive() -- get chunk size
	if result then
		result, errmsg = tonumber(result) -- convert size to number
		if result then
			result, errmsg = conn:receive(result) -- get code chunk
			if result then
				result, errmsg = load(result, name) -- compile code
				if result then
					result, errmsg = runner(nil, result) -- run code
					if result then
						result = "success"
					else
						result = "error"
					end
				else
					result = "compile"
				end
			else
				result = "protocol"
			end
		else
			result = "protocol"
		end
	else
		result = "protocol"
	end
else
	result = "protocol"
end
errmsg = tostring(errmsg)
conn:send(Message:format(result, #errmsg, errmsg))
