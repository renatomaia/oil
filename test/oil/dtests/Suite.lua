local Suite = require "loop.test.Suite"
return Suite{
	MethodInvocation = require "oil.dtests.kernel.MethodInvocation",
	ExceptionCatch   = require "oil.dtests.kernel.ExceptionCatch",
	ORBShutdown      = require "oil.dtests.kernel.ORBShutdown",
	ORBShutdown2     = require "oil.dtests.kernel.ORBShutdown2",
	ORBRestart       = require "oil.dtests.kernel.ORBRestart",
	ServantLocator   = require "oil.dtests.kernel.ServantLocator",
	ServantManager   = require "oil.dtests.kernel.ServantManager",
	CORBA = Suite{
		ServantCreation  = require "oil.dtests.corba.ServantCreation",
		ObjectOperations = require "oil.dtests.corba.ObjectOperations",
		IDLChanges       = require "oil.dtests.corba.IDLChanges",
		InterceptedGIOP = Suite{
			InvocationCallInfo        = require "oil.dtests.corba.intercepted.InvocationInfo",
			ServerExceptionInfo       = require "oil.dtests.corba.intercepted.ServerExceptionInfo",
			ClientExceptionInfo       = require "oil.dtests.corba.intercepted.ClientExceptionInfo",
			RequestWithServiceContext = require "oil.dtests.corba.intercepted.RequestWithServiceContext",
			ReplyWithServiceContext   = require "oil.dtests.corba.intercepted.ReplyWithServiceContext",
			ClientCancelWithResults   = require "oil.dtests.corba.intercepted.ClientCancelWithResults",
			ClientCancelWithException = require "oil.dtests.corba.intercepted.ClientCancelWithException",
			ServerCancelWithResults   = require "oil.dtests.corba.intercepted.ServerCancelWithResults",
			ServerCancelWithException = require "oil.dtests.corba.intercepted.ServerCancelWithException",
			ClientForward             = require "oil.dtests.corba.intercepted.ClientForward",
			ServerForwardRequest      = require "oil.dtests.corba.intercepted.ServerForwardRequest",
			ServerForwardReply        = require "oil.dtests.corba.intercepted.ServerForwardReply",
		},
	},
}
