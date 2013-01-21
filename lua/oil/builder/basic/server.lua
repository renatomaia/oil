local arch = require "oil.arch.basic.server"

return {
	RequestReceiver = arch.RequestReceiver{require "oil.kernel.base.Receiver"  },
	ServantManager = arch.ServantManager {require "oil.kernel.base.Servants",
		dispatcher = require "oil.kernel.base.Dispatcher",
	},
}

