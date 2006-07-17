
local type     = type
local pairs    = pairs
local ipairs   = ipairs
local tostring = tostring
local require  = require
local rawset   = rawset
local print    = print

local io = require "io"

--------------------------------------------------------------------------------
-- OiL main programming interface (API).

-- This API provides access to the basic functionalities of the OiL ORB.
-- More advanced features may be accessed through more speciatialized interfaces
-- that currently are only supported as part of the internal implementation and
-- therefore may change in the future.

module "oil"                                  

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local idl       = require "oil.idl"
local assert  = require "oil.assert"

--------------------------------------------------------------------------------
-- binding components
local arch = require "oil.arch.comm"


local dummy_codec         = require "oil.dummy.Codec"
local dummy_protocol      = require "oil.dummy.Protocol"
local dummy_reference     = require "oil.dummy.reference"

local proxy               = require "oil.dummy.proxy"

local client_broker       = require "oil.ClientBroker"
local server_broker       = require "oil.ServerBroker"
local channel_factory     = require "oil.ChannelFactory"
local dispatcher          = require "oil.dummy.Dispatcher"
local access_point        = require "oil.Acceptor"

local Factory_Codec             = arch.CodecType{ dummy_codec }
local Factory_InvokeProtocol    = arch.InvokeProtocolType{ dummy_protocol.InvokeProtocol }
local Factory_ListenProtocol    = arch.ListenProtocolType{ dummy_protocol.ListenProtocol }
local Factory_PassiveChannel    = arch.ChannelFactoryType{ channel_factory.PassiveChannelFactory }
local Factory_ActiveChannel     = arch.ChannelFactoryType{ channel_factory.ActiveChannelFactory }

local Factory_Reference = arch.ReferenceResolverType{ dummy_reference }

local Factory_ClientBroker      = arch.ClientBrokerType{ client_broker }
local Factory_Proxy             = arch.ProxyFactoryType{ proxy }

local Factory_Dispatcher        = arch.DispatcherType{ dispatcher }
local Factory_ServerBroker      = arch.ServerBrokerType{ server_broker }
local Factory_Acceptor          = arch.AcceptorType{ access_point }

----------------------------------------

myCodec = Factory_Codec()
myInvokeProtocol = Factory_InvokeProtocol()
myListenProtocol = Factory_ListenProtocol()
myReferenceResolver = Factory_Reference()
myAcceptor = Factory_Acceptor()

myClientBroker = Factory_ClientBroker()
myProxy = Factory_Proxy()
myPassiveChannelFactory = Factory_PassiveChannel()
myActiveChannelFactory = Factory_ActiveChannel()
myDispatcher = Factory_Dispatcher()
myServerBroker = Factory_ServerBroker()

----------------------------------------
myInvokeProtocol.codec         = myCodec.codec
myInvokeProtocol.channels      = myActiveChannelFactory.factory

myListenProtocol.codec         = myCodec.codec
myListenProtocol.channels      = myPassiveChannelFactory.factory

myReferenceResolver.codec        = myCodec.codec

myClientBroker.protocol       = myInvokeProtocol.invoker
myClientBroker.reference = myReferenceResolver.resolver
myClientBroker.factory = myProxy.proxies

myAcceptor.listener      = myListenProtocol.listener
myAcceptor.dispatcher      = myDispatcher.dispatcher
--myAcceptor.tasks       = myScheduler.tasks
--myDispatcher.tasks       = myScheduler.tasks

myServerBroker.ports = myAcceptor.manager 
myServerBroker.objectmap = myDispatcher.registry
myServerBroker.reference = myReferenceResolver.resolver

--------------------------------------------------------------------------------
-- Default configuration for creation of the default ORB instance.

-- The configuration values may differ accordingly to the IOP protocol.
-- For Internet IOP (IIOP) protocol the current options are the host name or IP
-- address and port that ORB must bind to, as well as the host name or IP
-- address and port that must be used in creation of object references.

-- @field protocoltag number Tag of the protocol the ORB shall use. Default is
-- tag 0, that indicates IIOP. (must be set before registration of any servant).
-- @field host string Host name or IP address (must be set before registration
-- of any servant).
-- @field host string Host name or IP address (must be set before registration
-- of any servant).
-- @field port number Port the ORB must listen (must be set before registration
-- of any servant).
-- @field iorhost string Host name or IP address informed in object references
-- (must be set before registration of any servant).
-- @field iorport number Port informed in object references (must be set before
-- registration of any servant).

-- @usage oil.Config.host = "middleware.inf.puc-rio.br"                        .
-- @usage oil.Config.host = "10.223.10.56"                                     .
-- @usage oil.Config.port = 8080                                               .
-- @usage oil.Config = {host = "10.223.10.56", port = 8080 }                   .

-- @see init

Config = {}

--------------------------------------------------------------------------------
-- Creates a new CORBA object implemented in Lua that supports some interface.

-- The value of object is used as the servant of a CORBA object that supports
-- the interface with repID (Interface Repository ID) defined in 'interface'.
-- Optionally, an object key value may be specified to create persistent
-- references.
-- The CORBA object returned by this function offers all servant attributes and
-- methods, as well as CORBA::Object basic operations like _ior().

-- @param object table Value used as the object servant (may be an indexable
-- value, e.g. userdata with a metatable that defined the __index field).
-- @param interface string Interface Repository ID or absolute name of the
-- interface the object supports.
-- @param key string [optional] User-defined object key used in creation of the
-- object reference.

-- @return table CORBA object created.

-- @usage oil.newobject({say_hello_to=print},"IDL:HelloWorld/Hello:1.0")       .
-- @usage oil.newobject({say_hello_to=print},"IDL:HelloWorld/Hello:1.0", "Key").

function newobject(object, interface, key)
	init({host="localhost", port=2809})
	return myServerBroker:register(object, interface, key)
end

--------------------------------------------------------------------------------
-- Creates a proxy for a CORBA object defined by an IOR (Inter-operable Object
-- Reference).

-- The value of object must be a string containing the IOR of the object the new
-- new proxy will represent.
-- Optionally, an interface supported by the CORBA object may be defined, in
-- this case no attempt is made to determine the actual object interface, i.e.
-- no network communication is made to check the object's interface.

-- @param object string Representation of Inter-operable Object Reference of the
-- object the new proxy will represent.
-- @param interface string [optional] Repository Interface ID or absolute name
-- of a interface the CORBA object supports (no interface or type check done).

-- @return table Proxy to the CORBA object.

-- @usage oil.newproxy("IOR:00000002B494...")                                  .
-- @usage oil.newproxy("IOR:00000002B494...", "HelloWorld::Hello")             .
-- @usage oil.newproxy("IOR:00000002B494...", "IDL:HelloWorld/Hello:1.0")      .
-- @usage oil.newproxy("corbaloc::host:8080/Key", "IDL:HelloWorld/Hello:1.0")  .

function newproxy(object, interface)
	return myClientBroker.proxies:newproxy(object, interface)
end

--------------------------------------------------------------------------------
-- Initialize the OiL main ORB.

-- Initialize the default ORB instance with the provided configurations. The
-- configuration values may differ accordingly to the IOP protocol.
-- For Internet IOP (IIOP) protocol the current options are the host name or IP
-- address and port that ORB must bind to, as well as the host name or IP
-- address and port that must be used in creation of object references.
-- If the default ORB already is created then this instance is returned.
-- This default ORB is used by all objects and proxies created by newobject and
-- newproxy functions.

-- @param config table Configurations used to create the default ORB instance.

-- @usage oil.init()                                                           .
-- @usage oil.init{ host = "middleware.inf.puc-rio.br" }                       .
-- @usage oil.init{ host = "10.223.10.56", port = 8080 }                       .

-- @see Config

function init(config)
	if not config then config = Config end
	myServerBroker:init(config)
end

--------------------------------------------------------------------------------
-- Checks whether there is some request pending

-- Returns true if there is some ORB request pending or false otherwise.

function pending()
	return myServerBroker:workpending()
end

--------------------------------------------------------------------------------
-- Waits for an ORB request and process it.

-- Process one single ORB request at each call. Returns true if success or nil
-- and an exception.

function step()
	return myServerBroker:performwork()
end

--------------------------------------------------------------------------------
-- Runs the ORB main loop.

-- Requests the ORB to process remote CORBA requisitions repeatedly until some
-- error occours.

function run()
	return myServerBroker:run()
end

--------------------------------------------------------------------------------
-- Alias of 'newobject' function.

-- For compatibility with LuaOrb applications.

-- @see newobject

createservant = newobject

--------------------------------------------------------------------------------
-- Alias of 'newproxy' function.

-- For compatibility with LuaOrb applications.

-- @see newproxy

createproxy = newproxy

--------------------------------------------------------------------------------
-- Gets reference from a servant

function getreference(servant)
	return myServerBroker:tostring(servant)
end

--------------------------------------------------------------------------------
-- Creates a file with the IOR of an object.

-- Utility function for writing stringfied References into a file.

function writeReference(object, file)
	file = io.open(file, "w")
	if file then
		file:write(object:_getreference())
		file:close()
		return true
	end
	assert.error("unable to write file '"..tostring(file).."'")
end

--------------------------------------------------------------------------------
-- Read the contents of a file.

-- Utility function for reading stringfied References from a file.

function readReference(filename)
	local file = io.open(filename)
	if file then
		local reference = file:read("*a")
		file:close()
		return reference
	end
	assert.error("unable to read from file '"..filename.."'")
end

