local string = require "string"
local oil    = require "oil"
local utils  = require "dtest.run.utils"
local checks = ...

local corbaloc = string.format("corbaloc::%s:2809/LuaServer", utils.hostof("Server"))
local server = oil.narrow(utils.waitfor(oil.newproxy(corbaloc, oil.corba.idl.object)))

local newiface = [[
		interface Server {
			void say_hello();
		};
]]

server:dostring([=[
	oil.loadidl[[
]=]..newiface..[=[
	]]
	function LuaServer:say_hello()
		print "Hello, World!"
	end
]=])

oil.loadidl(newiface)
server:say_hello()
checks:assert(server.dostring == nil, "old method was not removed from proxy class cache")
