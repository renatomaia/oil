require "cothread.auxiliary"
require "cothread.debug"

local socket = require "socket"
local Results = require "loop.test.Results"
local Message = "%s\n%d\n%s\n"
local conn = assert(socket.connect(HOST, PORT))
local results = Results()
local result, errmsg = conn:receive() -- get chunk name
if result then
	local name = result
	result, errmsg = conn:receive() -- get chunk size
	if result then
		result, errmsg = tonumber(result) -- convert size to number
		if result then
			result, errmsg = conn:receive(result) -- get code chunk
			if result then
				result, errmsg = loadstring(result, name) -- compile code
				if result then
					result, errmsg = results:test(nil, result, results) -- run code
					if result then
						result = "success"
					elseif results:isfailure(errmsg) then
						result = "failure"
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
