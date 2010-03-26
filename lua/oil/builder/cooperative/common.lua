local require = require
local builder = require "oil.builder"
local arch    = require "oil.arch.cooperative.common"

module "oil.builder.cooperative.common"

BasicSystem = arch.BasicSystem{
	tasks   = require "oil.kernel.cooperative.Tasks",
	sockets = require "oil.kernel.cooperative.Sockets",
	dns     = require "oil.kernel.base.DNS",
}

function create(comps)
	return builder.create(_M, comps)
end
