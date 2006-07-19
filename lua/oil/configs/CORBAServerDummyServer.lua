local require = require

module "oil.configs.CORBAServerDummyServer"                                  

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local idl       = require "oil.idl"
local idlparser = require "oil.idl.compiler"
local assert    = require "oil.assert"
local iridl     = require "oil.ir.idl"

--------------------------------------------------------------------------------
-- binding components (test)
local arch = require "oil.arch.comm"

local scheduler           = require "oil.scheduler"
local corba_codec         = require "oil.corba.Codec"
local corba_protocol      = require "oil.corba.Protocol"
local corba_reference     = require "oil.corba.reference"
local dummy_codec         = require "oil.dummy.Codec"
local dummy_protocol      = require "oil.dummy.Protocol"
local dummy_reference     = require "oil.dummy.reference"

local server_broker     = require "oil.ServerBroker"
local channel_factory   = require "oil.ChannelFactory"
local corba_dispatcher  = require "oil.corba.SimpleDispatcher"
local dummy_dispatcher  = require "oil.dummy.Dispatcher"
local manager           = require "oil.ir"
local access_point      = require "oil.ConcurrentAcceptor"

----------------------------------------
local Factory_CorbaCodec             = arch.CodecType{ corba_codec }
local Factory_DummyCodec             = arch.CodecType{ dummy_codec }
local Factory_CorbaListenProtocol = arch.TypedListenProtocolType{ corba_protocol.ListenProtocol }
local Factory_DummyListenProtocol = arch.ListenProtocolType{ dummy_protocol.ListenProtocol }

local Factory_PassiveChannel    = arch.ChannelFactoryType{ channel_factory.PassiveChannelFactory }

local Factory_CorbaReference         = arch.ReferenceResolverType{ corba_reference }
local Factory_DummyReference         = arch.ReferenceResolverType{ dummy_reference }

local Factory_Manager           = arch.TypeManagerType{ manager }

local Factory_CorbaDispatcher   = arch.TypedDispatcherType{ corba_dispatcher }
local Factory_DummyDispatcher   = arch.DispatcherType{ dummy_dispatcher }
local Factory_ServerBroker      = arch.ServerBrokerType{ server_broker }
local Factory_Acceptor          = arch.AcceptorType{ access_point }
local Factory_Scheduler         = arch.SchedulerType{ scheduler }

----------------------------------------
myCodecCorba                   = Factory_CorbaCodec()
myCodecDummy                   = Factory_DummyCodec()
myListenProtocolCorba          = Factory_CorbaListenProtocol()
myListenProtocolDummy          = Factory_DummyListenProtocol()
myAcceptorCorba                = Factory_Acceptor()
myAcceptorDummy                = Factory_Acceptor()

myReferenceResolverCorba       = Factory_CorbaReference()
myReferenceResolverDummy       = Factory_DummyReference()

myPassiveChannelFactory        = Factory_PassiveChannel()
myDispatcher                   = Factory_CorbaDispatcher()
myServerBroker                 = Factory_ServerBroker()
myManager                      = Factory_Manager()

myScheduler                    = Factory_Scheduler()
----------------------------------------
myListenProtocolCorba.codec    = myCodecCorba.codec
myListenProtocolCorba.channels = myPassiveChannelFactory.factory
myListenProtocolCorba.objects  = myManager.mapping

myListenProtocolDummy.codec    = myCodecDummy.codec
myListenProtocolDummy.channels = myPassiveChannelFactory.factory

myReferenceResolverCorba.codec = myCodecCorba.codec

myAcceptorCorba.listener       = myListenProtocolCorba.listener
myAcceptorCorba.dispatcher     = myDispatcher.dispatcher
myAcceptorCorba.tasks          = myScheduler.threads
myAcceptorDummy.listener       = myListenProtocolDummy.listener
myAcceptorDummy.dispatcher     = myDispatcher.dispatcher
myAcceptorDummy.tasks          = myScheduler.threads

myDispatcher.objects           = myManager.registry

myServerBroker.ports["corba"]  = myAcceptorCorba.manager 
myServerBroker.ports["dummy"]  = myAcceptorDummy.manager 
myServerBroker.objectmap       = myDispatcher.registry
myServerBroker.reference["corba"] = myReferenceResolverCorba.resolver
myServerBroker.reference["dummy"] = myReferenceResolverDummy.resolver

myPassiveChannelFactory.luasocket = myScheduler.socket

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

