local package = require "package"
local socket
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
function socket:connect(address, port, params)
	if self.client_params then
	  local sock, err = luasocket.ssl(self.client_params)
	  if not sock then return nil, err end
	  local res, err = sock:connect(address, port)
	  if not res then return nil, err end
	  return sock
	else
	  return luasocket.connect(address, port)
	end
end
function socket:bind(address, port, params)
	if self.server_params then
	  local sock, err = luasocket.ssl(self.server_params)
	  if not sock then return nil, err end
	  local res, err = sock:bind(address, port)
	  if not res then return nil, err end
	  res, err = sock:listen()
	  if not res then return nil, err end
	  return sock
	else
	  return luasocket.bind(address, port)
	end
end

package.loaded["oil.socket"] = socket
oil = oil or {}
oil.socket = socket
