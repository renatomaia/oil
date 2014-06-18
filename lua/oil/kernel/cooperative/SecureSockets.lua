-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : Secure Socket API Wrapper
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local cothread = require "cothread"                                             --[[VERBOSE]] local verbose = require "oil.verbose"
cothread.plugin(require "cothread.plugin.socket")

local sslsocket = require "cothread.socket.ssl"
local sslwrap = sslsocket.ssl
local sslctxt = sslsocket.sslcontext

local oo = require "oil.oo"
local class = oo.class

local Sockets = require "oil.kernel.cooperative.Sockets"


local SecureSockets = class({}, Sockets)

function SecureSockets:sslcontext(...)
	return sslctxt(...)
end

function SecureSockets:ssl(...)
	return sslwrap(...)
end

return SecureSockets
