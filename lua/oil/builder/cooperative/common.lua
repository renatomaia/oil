local arch = require "oil.arch.cooperative.common"

return {
	BasicSystem = arch.BasicSystem{
		tasks = require "oil.kernel.cooperative.Tasks",
		sockets = require "oil.kernel.cooperative.Sockets",
		dns = require "oil.kernel.base.DNS",
	},
}
