local arch = require "oil.arch.corba.intercepted.server"

return {
	RequestListener =
		arch.RequestListener{require "oil.corba.intercepted.Listener"},
}
