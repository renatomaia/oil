local arch = require "oil.arch.corba.intercepted.client"

return {
	OperationRequester =
		arch.OperationRequester{require "oil.corba.intercepted.Requester" },
}
