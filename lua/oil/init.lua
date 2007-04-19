--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua: An Object Request Broker in Lua                 --
-- Release: 0.4 alpha                                                         --
-- Title  : OiL main programming interface (API)                              --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   loadidl(code)                                                            --
--   loadidlfile(path, pre)                                                   --
--                                                                            --
--   getLIR()                                                                 --
--   getIR()                                                                  --
--   setIR(ir)                                                                --
--                                                                            --
--   newobject(obj, iface, key)                                               --
--   newproxy(obj, iface)                                                     --
--   narrow(proxy, iface)                                                     --
--                                                                            --
--   init()                                                                   --
--   pending()                                                                --
--   step()                                                                   --
--   run()                                                                    --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--------------------------------------------------------------------------------

local module   = module
local luapcall = pcall
local require  = require

local io = require "io"

local builder   = require "oil.builder"
local assert    = require "oil.assert"
local Exception = require "oil.Exception"

local OIL_FLAVOR = OIL_FLAVOR

--------------------------------------------------------------------------------
-- OiL main programming interface (API).

-- This API provides access to the basic functionalities of the OiL ORB.
-- More advanced features may be accessed through more speciatialized interfaces
-- that currently are only supported as part of the internal implementation and
-- therefore may change in the future.

module "oil"

function assemble(flavor)
	assert.type(flavor, "string", "OiL flavor name")
	Components = builder.build(flavor)
	scheduler = Components.TaskManager
	pcall = scheduler and scheduler.pcall or luapcall
end

assemble(OIL_FLAVOR or "corba;typed;cooperative;base")

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
-- Loads an IDL code strip into the local Interface Repository.

-- @param idlspec string The IDL code strip to be loaded into the local IR.

-- @usage oil.loadidl [[
--          interface Hello {
--            attribute boolean quiet;
--            readonly attribute unsigned long count;
--            string say_hello_to(in string msg);
--          };
--        ]]                                                                   .

function loadidl(idlspec)
	assert.type(idlspec, "string", "IDL specification")
	return assert.results(Components.TypeRepository.compiler:load(idlspec))
end

--------------------------------------------------------------------------------
-- Loads an IDL file into the local Interface Repository.

-- The file specified will be optionally preprocessed by a command-line C++ pre-
-- processor prior to process directives like #include, #define, #ifdef and the
-- like.
-- The pre-processing is activated by parameter preprocess. 
-- In this case a new file is created in the path defined by the preprocess
-- parameter.

-- @param filename string The path to the IDL file that must be loaded.

-- @usage oil.loadidlfile "/usr/local/corba/idl/CosNaming.idl"                 .
-- @usage oil.loadidlfile("HelloWorld.idl", "/tmp/preprocessed.idl")           .

function loadidlfile(filepath)
	assert.type(filepath, "string", "IDL file path")
	return assert.results(Components.TypeRepository.compiler:loadfile(filepath))
end

--------------------------------------------------------------------------------
-- Get the local Interface Repository that exports local cached definitions.

-- @return 1 proxy CORBA object that exports the local Interface Repository.

function getLIR()
	return Components.TypeRepository.types
end

--------------------------------------------------------------------------------
-- Get the remote Interface Repository used to retrieve interface definitions.

-- @return 1 proxy Proxy for the remote IR currently used.

function getIR()
	return newobject(getLIR(), "IDL:omg.org/CORBA/Repository:1.0")
end

--------------------------------------------------------------------------------
-- Defines a remote Interface Repository used to retrieve interface definitions.

-- @param ir proxy Proxy for the remote IR to be used.

-- @usage oil.setIR(oil.newproxy("corbaloc::cos_host/InterfaceRepository",
--                               "IDL:omg.org/CORBA/Repository:1.0"))          .

function setIR(ir)
	Components.TypeRepository.remote = ir
end

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
	if Config then init(Config) end
	if not object then assert.illegal(object, "object implementation") end
	if not interface then assert.illegal(interface, "interface definition") end
	if key then assert.type(key, "string", "object key") end
	return assert.results(Components.ServerBroker.broker:object(object, key, interface))
end

function tostring(object)
	assert.type(object, "table", "servant object")
	return assert.results(Components.ServerBroker.broker:tostring(object))
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
	if Config then init(Config) end
	assert.type(object, "string", "object reference")
	return assert.results(Components.ClientBroker.broker:fromstring(object, interface))
end

--------------------------------------------------------------------------------
-- Narrow an object reference into some more specific interface supported by the
-- CORBA object.

-- The object reference is defined as a proxy object.
-- If you wish to create a proxy to an object specified by an IOR that must be
-- created already narrowed into some interface, use newproxy function.
-- The interface the object reference must be narrowed into is defined by the
-- Interface Repository ID stored in parameter 'interface'.
-- If no interface is defined, then the object reference is narrowed to the most
-- specific interface supported by the COBRA object.
-- Note that in the former case, no attempt is made to determine the actual
-- object interface, i.e. no network communication is made to check the object's
-- interface.

-- @param proxy table Proxy that represents the CORBA object which reference
-- must be narrowed.
-- @param interface string [optional] Repository Interface ID of the interface
-- the object reference must be narrowed into (no interface or type check is
-- made).

-- @return table New proxy to the CORBA object narrowed into some interface
-- supported by the CORBA object.

-- @usage oil.narrow(ns:resolve_str("HelloWorld"))                             .
-- @usage oil.narrow(ns:resolve_str("HelloWorld"), "IDL:HelloWorld/Hello:1.0") .

-- @see newproxy

function narrow(object, interface)
	assert.type(object, "table", "object proxy")
	if interface then assert.type(interface, "string", "interface definition") end
	return object and object:_narrow(interface)
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
	config, Config = config or Config, nil
	assert.type(config, "table", "ORB configuration")
	return assert.results(Components.ServerBroker.broker:initialize(config))
end

--------------------------------------------------------------------------------
-- Checks whether there is some request pending

-- Returns true if there is some ORB request pending or false otherwise.

function pending()
	return assert.results(Components.ServerBroker.broker:pending())
end

--------------------------------------------------------------------------------
-- Waits for an ORB request and process it.

-- Process one single ORB request at each call. Returns true if success or nil
-- and an exception.

function step()
	return assert.results(Components.ServerBroker.broker:step())
end

--------------------------------------------------------------------------------
-- Runs the ORB main loop.

-- Requests the ORB to process remote CORBA requisitions repeatedly until some
-- error occours.

function run()
	if Config then init(Config) end
	return assert.results(Components.ServerBroker.broker:run())
end

function main(main)
	assert.type(main, "function", "main function")
	if Components.TaskManager then
		local tasks = Components.TaskManager.tasks
		assert.results(tasks:register(tasks:new(main)))
		return Components.TaskManager.control:run()
	else
		return main()
	end
end

function newthread(body, ...)
	assert.type(body, "function", "thread body")
	return Components.TaskManager.tasks:start(body, ...)
end

function sleep(time)
	assert.type(time, "number", "time")
	return Components.OperatingSystem.sockets:sleep(time)
end

--------------------------------------------------------------------------------
-- Shuts down the ORB.

-- Stops the ORB main loop if it is executing and closes all connections.

function shutdown()
	return assert.results(Components.ServerBroker.broker:shutdown())
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

-- Utility function for writing stringfied IORs into a file.

function writeto(filepath, text)
	local result, errmsg = io.open(filepath, "w")
	if result then
		local file = result
		result, errmsg = file:write(text)
		file:close()
	end
	return result, errmsg
end

--------------------------------------------------------------------------------
-- Read the contents of a file.

-- Utility function for reading stringfied IORs from a file.

function readfrom(filepath)
	local result, errmsg = io.open(filepath)
	if result then
		local file = result
		result, errmsg = file:read("*a")
		file:close()
	end
	return result, errmsg
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function newencoder()
	return assert.results(Components.ValueEncoder.codec:encoder(true))
end

function newdecoder(stream)
	assert.type(stream, "string", "byte stream")
	return assert.results(Components.ValueEncoder.codec:decoder(stream, true))
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function newexcept(body)
	assert.type(body, "table", "exception body")
	return Exception(body)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local port       = require "oil.port"
local ClientSide = require "oil.corba.interceptors.ClientSide"
local ServerSide = require "oil.corba.interceptors.ServerSide"

function setclientinterceptor(iceptor)
	assert.results(port.intercept, "interceptors not supported")
	if iceptor then
		iceptor = ClientSide{ interceptor = iceptor }
	end
	port.intercept(Components.OperationRequester, "requests", "method", iceptor)
	port.intercept(Components.OperationRequester, "messenger", "method", iceptor)
end

function setserverinterceptor(iceptor)
	assert.results(port.intercept, "interceptors not supported")
	if iceptor then
		iceptor = ServerSide{ interceptor = iceptor }
	end
	port.intercept(Components.RequestListener, "messenger", "method", iceptor)
	port.intercept(Components.RequestDispatcher, "dispatcher", "method", iceptor)
end
