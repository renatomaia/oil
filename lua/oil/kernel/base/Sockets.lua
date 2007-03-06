--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua: An Object Request Broker in Lua                 --
-- Release: 0.4                                                               --
-- Title  : Socket API Wrapper                                                --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------

local socket = require "socket"

local oo = require "oil.oo"

module("oil.kernel.base.Sockets", oo.class)

function select(self, recvt, sendt, timeout)
	return socket.select(recvt, sendt, timeout)
end

function sleep(self, timeout)
	return socket.sleep(timeout)
end

function tcp(self)
	return socket.tcp()
end

function udp(self)
	return socket.udp()
end

function connect(self, address, port)
	return socket.connect(address, port)
end

function bind(self, address, port)
	return socket.bind(address, port)
end
