local require = require

module "oil.configs.CORBAConcurrentClientConcurrentServer"                                  

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local idl       = require "oil.idl"
local idlparser = require "oil.idl.compiler"
local assert    = require "oil.assert"
local iridl     = require "oil.ir.idl"

--------------------------------------------------------------------------------
-- binding components (test)
local arch = require "oil.arch.comm"

local scheduler         = require "oil.scheduler"

local corba_codec         = require "oil.corba.Codec"
local corba_protocol      = require "oil.corba.Protocol"
local corba_reference     = require "oil.corba.reference"

local proxy             = require "oil.corba.proxy"
local client_broker     = require "oil.ClientBroker"
local server_broker     = require "oil.ServerBroker"
local channel_factory   = require "oil.ChannelFactory"
local dispatcher        = require "oil.corba.ConcurrentDispatcher"
local manager           = require "oil.ir"
local access_point      = require "oil.ConcurrentAcceptor"

local Factory_Codec             = arch.CodecType{ corba_codec }
local Factory_InvokeProtocol    = arch.TypedInvokeProtocolType{ corba_protocol.InvokeProtocol }
local Factory_ListenProtocol    = arch.TypedListenProtocolType{ corba_protocol.ListenProtocol }

local Factory_PassiveChannel    = arch.ChannelFactoryType{ channel_factory.PassiveChannelFactory }
local Factory_ActiveChannel     = arch.ChannelFactoryType{ channel_factory.ActiveChannelFactory }

local Factory_Reference         = arch.ReferenceResolverType{ corba_reference }

local Factory_Manager           = arch.TypeManagerType{ manager }

local Factory_ClientBroker      = arch.ClientBrokerType{ client_broker }
local Factory_Proxy             = arch.TypedProxyFactoryType{ proxy }

local Factory_Dispatcher        = arch.TypedDispatcherType{ dispatcher }
local Factory_ServerBroker      = arch.ServerBrokerType{ server_broker }
local Factory_Acceptor          = arch.AcceptorType{ access_point }

local Factory_Scheduler         = arch.SchedulerType{ scheduler }
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
myManager = Factory_Manager()

myScheduler = Factory_Scheduler()

----------------------------------------
myInvokeProtocol.codec         = myCodec.codec
myInvokeProtocol.channels      = myActiveChannelFactory.factory
myInvokeProtocol.tasks         = myScheduler.threads

myListenProtocol.codec         = myCodec.codec
myListenProtocol.channels      = myPassiveChannelFactory.factory
myListenProtocol.objects       = myManager.mapping

myReferenceResolver.codec      = myCodec.codec

myClientBroker.protocol        = myInvokeProtocol.invoker
myClientBroker.reference       = myReferenceResolver.resolver
myClientBroker.factory         = myProxy.proxies

myProxy.interfaces             = myManager.registry

myAcceptor.listener            = myListenProtocol.listener
myAcceptor.dispatcher          = myDispatcher.dispatcher
myAcceptor.tasks               = myScheduler.threads

myDispatcher.tasks             = myScheduler.threads
myDispatcher.objects           = myManager.registry

myServerBroker.ports["corba"]        = myAcceptor.manager 
myServerBroker.objectmap       = myDispatcher.registry
myServerBroker.reference["corba"]       = myReferenceResolver.resolver

myPassiveChannelFactory.luasocket = myScheduler.socket
myActiveChannelFactory.luasocket  = myScheduler.socket

--------------------------------------------------------------------------------
-- Local module variables and functions ----------------------------------------
myManager:putiface(iridl.Repository             )
myManager:putiface(iridl.Container              )
myManager:putiface(iridl.ModuleDef              )
myManager:putiface(iridl.ConstantDef            )
myManager:putiface(iridl.IDLType                )
myManager:putiface(iridl.StructDef              )
myManager:putiface(iridl.UnionDef               )
myManager:putiface(iridl.EnumDef                )
myManager:putiface(iridl.AliasDef               )
myManager:putiface(iridl.InterfaceDef           )
myManager:putiface(iridl.ExceptionDef           )
myManager:putiface(iridl.NativeDef              )
myManager:putiface(iridl.ValueDef               )
myManager:putiface(iridl.ValueBoxDef            )
myManager:putiface(iridl.AbstractInterfaceDef   )
myManager:putiface(iridl.LocalInterfaceDef      )
myManager:putiface(iridl.ExtInterfaceDef        )
myManager:putiface(iridl.ExtValueDef            )
myManager:putiface(iridl.ExtAbstractInterfaceDef)
myManager:putiface(iridl.ExtLocalInterfaceDef   )
myManager:putiface(iridl.PrimitiveDef           )
myManager:putiface(iridl.StringDef              )
myManager:putiface(iridl.SequenceDef            )
myManager:putiface(iridl.ArrayDef               )
myManager:putiface(iridl.WstringDef             )
myManager:putiface(iridl.FixedDef               )
myManager:putiface(iridl.TypedefDef             )
myManager:putiface(iridl.AttributeDef           )
myManager:putiface(iridl.ExtAttributeDef        )
myManager:putiface(iridl.OperationDef           )
myManager:putiface(iridl.InterfaceAttrExtension )
myManager:putiface(iridl.ValueMemberDef         )

