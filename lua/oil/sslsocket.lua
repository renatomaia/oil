local package = require "package"
local scheduler = oil and oil.scheduler
local socket
if scheduler then
	socket = scheduler.socket
else
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
	function socket:ssl(params)
		return luasocket.ssl(params)
	end
	function socket:connect(address, port)
		return luasocket.connect(address, port)
	end
	function socket:bind(address, port)
		return luasocket.bind(address, port)
	end
	function socket:ssl_connect(address, port, params)
    local sock, err = luasocket.ssl(params)
    if not sock then return nil, err end
    local res, err = sock:connect(address, port)
    if not res then return nil, err end
    return sock
	end
	function socket:ssl_bind(address, port, params)
		local sock, err = luasocket.ssl(params)
		if not sock then return nil, err end
		local res, err = sock:bind(address, port)
		if not res then return nil, err end
		res, err = sock:listen()
		if not res then return nil, err end
		return sock
	end
end
package.loaded["oil.sslsocket"] = socket
oil = oil or {}
oil.sslsocket = socket
