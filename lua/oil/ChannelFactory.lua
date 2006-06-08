local require         = require
local print           = print
local pairs           = pairs
local setmetatable    = setmetatable
local oo              = require "oil.oo"

module ("oil.ChannelFactory", oo.class )                                        --[[VERBOSE]] local verbose = require "oil.verbose"

local socket          = require "oil.socket"
local Exception       = require "oil.Exception"
local ObjectCache     = require "loop.collection.ObjectCache"

local ConnectionCache = ObjectCache{}
function ConnectionCache:retrieve()
	return setmetatable({}, {__mode = "v"})
end


--------------------------------------------------------------------------------
-- Client connection management ------------------------------------------------

local function newsocket(host, port)
	local conn, except = socket:tcp()                                             --[[VERBOSE]] verbose:connect "new socket for connection"
	if conn then
		local success
		success, except = conn:connect(host, port)                                  --[[VERBOSE]] verbose:connect("connect socket to ", host, ":", port, ", error: ", except, "]")
		if not success then
			conn, except = nil, Exception{ "COMM_FAILURE", minor_code_value = 0,
				message = "unable to connect to "..host..":"..port,
				reason = "connect",
				error = except,
				host = host, 
				port = port,
			}
		end
	else
		except = Exception{ "NO_RESOURCES", minor_code_value = 0,
			message = "unable to create new socket",
			reason = "socket",
			error = except,
		}
	end                                                                       
	return conn, except
end

function connect(self, reference)                                               --[[VERBOSE]] verbose:connect(true, "attempt to create new connection")
	local host, port = reference.host, reference.port
	local conn, except = ConnectionCache[host][port]
	if not conn then                                                              --[[VERBOSE]] verbose:connect("creating new connection to ", host, ":", port)
		conn, except = newsocket(host, port)
		if conn then
			ConnectionCache[host][port] = conn
		end
	end                                                                           --[[VERBOSE]] verbose:connect(false)
	return conn, except                                                           
end


function bind(self, host, port)
	if host == "*" then
		host = socket.dns.gethostname()
	end
	local sock, err = socket:tcp()                                                --[[VERBOSE]] verbose:listen("new socket for port, error: ", err)
	if not sock then return nil, err, "socket" end
	local res, err = sock:bind(host, port)                                        --[[VERBOSE]] verbose:listen("bind to address ", host, ":", port, ", error: ", err)
	if not res then return nil, err, "address" end
	res, err = sock:listen()                                                      --[[VERBOSE]] verbose:listen("listen to address ", host, ":", port, ", error: ", err)
	if not res then return nil, err, "address" end  
	return sock, host
end
