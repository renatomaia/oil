
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

local luaidl  = require "luaidl"
local idl     = require "oil.idl"
local assert  = require "oil.assert"

--------------------------------------------------------------------------------
-- binding components (test)
local arch = require "oil.arch.comm"


local dummy_codec         = require "oil.dummy.Codec"
local dummy_protocol      = require "oil.dummy.Protocol"
local dummy_reference     = require "oil.dummy.reference"

local proxy               = require "oil.proxy"
local channel_factory     = require "oil.ChannelFactory"
local dispatcher          = require "oil.orb"
local reference_handler   = require "oil.ReferenceHandler"
local manager             = require "oil.ir"
local access_point        = require "oil.AccessPoint"

local Factory_Codec             = arch.CodecType{ dummy_codec }
local Factory_Protocol          = arch.ProtocolType{ dummy_protocol }
local Factory_ReferenceResolver = arch.ReferenceResolverType{ dummy_reference }

local Factory_Manager           = arch.ManagerType{ manager }
local Factory_ReferenceHandler  = arch.ReferenceHandlerType{ reference_handler }
local Factory_ChannelFactory    = arch.ChannelFactoryType{ channel_factory }
local Factory_Dispatcher        = arch.DispatcherType{ dispatcher }
local Factory_Proxy             = arch.ProxyType{ proxy }
local Factory_Manager           = arch.ManagerType{ manager }
local Factory_AccessPoint       = arch.AccessPointType{ access_point }

----------------------------------------

myProtocol = Factory_Protocol()
myCodec = Factory_Codec()
myReferenceResolver = Factory_ReferenceResolver()
myAccessPoint = Factory_AccessPoint()

myReferenceHandler = Factory_ReferenceHandler()
myProxy = Factory_Proxy()
myChannelFactory = Factory_ChannelFactory()
myDispatcher = Factory_Dispatcher()
myManager = Factory_Manager()

----------------------------------------
myProtocol.codec         = myCodec.codec
myReferenceResolver.codec        = myCodec.codec

myReferenceHandler.reference_resolver["dummy"] = myReferenceResolver.resolver

myProtocol.channelFactory   = myChannelFactory.factory

myProxy.protocol       = myProtocol.protocol
myProxy.reference_handler      = myReferenceHandler.reference

myManager.proxy = myProxy.proxy

myDispatcher.protocol    = myProtocol.protocol
myDispatcher.point       = myAccessPoint.point
myDispatcher.reference_handler   = myReferenceHandler.reference

myAccessPoint.protocol["dummy"] = myProtocol.protocol

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
	if type(interface) == "string" then
		if Manager.lookup then
			interface = Manager:lookup(interface) or interface
		end
	end
	return init():object(object, interface, key)
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
	object = myReferenceResolver:decode_profile(object)
	
	object = myProxy:class(object)

	rawset(object, "_orb", init())
	return object
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
	if not MainORB then
		local except
		if not config then config = Config end
		MainORB, except = myDispatcher:init(config or Config)
		if not MainORB then assert.error(except) end
	end
	return MainORB
end

--------------------------------------------------------------------------------
-- Checks whether there is some request pending

-- Returns true if there is some ORB request pending or false otherwise.

function pending()
	return init():workpending()
end

--------------------------------------------------------------------------------
-- Waits for an ORB request and process it.

-- Process one single ORB request at each call. Returns true if success or nil
-- and an exception.

function step()
	return init():performwork()
end

--------------------------------------------------------------------------------
-- Runs the ORB main loop.

-- Requests the ORB to process remote CORBA requisitions repeatedly until some
-- error occours.

function run()
	return init():run()
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

