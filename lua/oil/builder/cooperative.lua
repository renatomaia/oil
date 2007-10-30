local require = require
local builder = require "oil.builder"
local arch    = require "oil.arch.cooperative"

module "oil.builder.cooperative"

TaskManager = arch.TaskManager{ require "loop.thread.SocketScheduler" }
OperationInvoker = arch.OperationInvoker{
	invoker = require "oil.kernel.cooperative.Invoker",
	mutex   = require "oil.kernel.cooperative.Mutex",
}
RequestReceiver = arch.RequestReceiver{
	acceptor = require "oil.kernel.cooperative.Receiver",
	mutex    = require "oil.kernel.cooperative.Mutex",
}

function create(comps)
	comps = builder.create(_M, comps)
	comps.OperatingSystem = comps.TaskManager
	return comps
end
