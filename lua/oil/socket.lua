local package = require "package"
--local scheduler = oil and oil.myScheduler
local socket
--if scheduler then
--	socket = scheduler.socket
--else
	local luasocket = require "socket"
	socket = setmetatable({}, { __index = luasocket })
	function socket:select(recv, send, timeout)
		return luasocket.select(recv, send, timeout)
	end
	function socket:sleep(timeout)
		return luasocket.sleep(timeout)
	end
	function socket:tcp()
		return luasocket.tcp()
	end
	function socket:udp()
		return luasocket.udp()
	end
	function socket:connect(address, port)
		return luasocket.connect(address, port)
	end
	function socket:bind(address, port)
		return luasocket.bind(address, port)
	end
--end
package.loaded["oil.socket"] = socket
oil = oil or {}
oil.socket = socket
