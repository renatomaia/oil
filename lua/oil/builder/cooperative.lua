local require = require
local builder = require "oil.builder"
local arch    = require "oil.arch.cooperative"

module "oil.builder.cooperative"

BasicSystem     = arch.BasicSystem    { require "loop.thread.SocketScheduler" }
RequestReceiver = arch.RequestReceiver{ require "oil.kernel.cooperative.Receiver" }

function create(comps)
	return builder.create(_M, comps)
end
