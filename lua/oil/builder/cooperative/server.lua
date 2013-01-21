local arch = require "oil.arch.cooperative.server"

return {
	RequestReceiver =
		arch.RequestReceiver{require "oil.kernel.cooperative.Receiver"},
}
