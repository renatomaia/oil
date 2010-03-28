-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.5
-- Title  : DNS API Wrapper
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local socket = require "socket.core"
local thishostname = socket.dns.gethostname
local hostname2ip = socket.dns.toip

local oo = require "oil.oo"
local class = oo.class

module(..., class)

function gethostname(self)
	return thishostname()
end

function toip(self, hostname)
	return hostname2ip(hostname)
end
