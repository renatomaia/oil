-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.5
-- Title  : Socket API Wrapper
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local socket = require "cothread.socket"
local tcpsocket = socket.tcp
local selectsockets = socket.select

local oo = require "oil.oo"
local class = oo.class

module(..., class)

function tcp(self)
	return tcpsocket()
end

function select(self, recvt, sendt, timeout)
	return selectsockets(recvt, sendt, timeout)
end
