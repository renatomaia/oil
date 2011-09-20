local require = require
local builder = require "oil.builder"
local arch    = require "oil.arch.basic.common"
local Exception = require "oil.Exception"

module "oil.builder.basic.common"

BasicSystem = arch.BasicSystem{
	sockets = require "oil.kernel.base.Sockets",
	dns     = require "oil.kernel.base.DNS",
}

function create(comps)
	if comps.Exception == nil then
		comps.Exception = Exception
	end
	return builder.create(_M, comps)
end
