local builder = require "oil.builder"
local create = builder.create

local arch = require "oil.arch.basic.common"
local Exception = require "oil.Exception"

local factories = {
	BasicSystem = arch.BasicSystem{
		sockets = require "oil.kernel.base.Sockets",
		dns = require "oil.kernel.base.DNS",
	},
}

function factories.create(built)
	if built.Exception == nil then built.Exception = Exception end
	create(factories, built)
end

return factories
