-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : DNS API Wrapper
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local socket = require "socket.core"
local thishostname = socket.dns.gethostname
local hostname2ip = socket.dns.toip
local ip2hostname = socket.dns.tohostname

local oo = require "oil.oo"
local class = oo.class


local DNS = class()

function DNS:gethostname()
	return thishostname()
end

function DNS:toip(...)
	return hostname2ip(...)
end

function DNS:toname(...)
	return ip2hostname(...)
end

return DNS
