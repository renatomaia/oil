local string = require "string"
local oil    = require "oil"
local utils  = require "dtest.run.utils"
local checks = ...

local corbaloc = string.format("corbaloc::%s:2809/Server", utils.hostof("Server"))
local server = oil.narrow(utils.waitfor(oil.newproxy(corbaloc, oil.corba.idl.object)))

local future = server.__deferred:start(-1)
oil.sleep(1)
checks:assert(future:ready(), checks.is(false, "endless operation returned."))
checks:timeout(1, "server is not responding.", server.start, server, 0)
server:complete()
checks:timeout(1, "completed operation didn't return.", future.results, future)
