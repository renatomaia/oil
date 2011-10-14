PROJNAME= oil
LIBNAME= $(PROJNAME)

ifeq "$(TEC_SYSNAME)" "SunOS"
  USE_CC=Yes
  NO_LOCAL_LD=Yes
  AR=CC
  CFLAGS+= -KPIC
  STDLFLAGS= -xar
  CPPFLAGS= +p -KPIC -mt -D_REENTRANT
  ifeq ($(TEC_WORDSIZE), TEC_64)
    FLAGS+= -m64
    LFLAGS+= -m64
    STDLFLAGS+= -m64
  endif
  STDLFLAGS+= -o
endif

USE_LUA51= YES
NO_LUALINK=YES
USE_NODEPEND=YES

PRELOAD_DIR= ../obj/${TEC_UNAME}
INCLUDES= $(PRELOAD_DIR)

SRC= $(PRELOAD_DIR)/oil.c

LUADIR= ../lua
LUASRC= $(addprefix $(LUADIR)/, \
	oil/arch/basic/client.lua \
	oil/arch/basic/common.lua \
	oil/arch/basic/server.lua \
	oil/arch/cooperative/common.lua \
	oil/arch/cooperative/server.lua \
	oil/arch/corba/client.lua \
	oil/arch/corba/common.lua \
	oil/arch/corba/intercepted/client.lua \
	oil/arch/corba/intercepted/server.lua \
	oil/arch/corba/server.lua \
	oil/arch/ludo/byref.lua \
	oil/arch/ludo/client.lua \
	oil/arch/ludo/common.lua \
	oil/arch/ludo/server.lua \
	oil/arch/typed/client.lua \
	oil/arch/typed/common.lua \
	oil/arch/typed/server.lua \
	oil/arch.lua \
	oil/assert.lua \
	oil/builder/basic/client.lua \
	oil/builder/basic/common.lua \
	oil/builder/basic/server.lua \
	oil/builder/cooperative/common.lua \
	oil/builder/cooperative/server.lua \
	oil/builder/corba/client.lua \
	oil/builder/corba/common.lua \
	oil/builder/corba/gencode.lua \
	oil/builder/corba/intercepted/client.lua \
	oil/builder/corba/intercepted/server.lua \
	oil/builder/corba/server.lua \
	oil/builder/lua/client.lua \
	oil/builder/lua/server.lua \
	oil/builder/ludo/byref.lua \
	oil/builder/ludo/client.lua \
	oil/builder/ludo/common.lua \
	oil/builder/ludo/server.lua \
	oil/builder/typed/client.lua \
	oil/builder/typed/server.lua \
	oil/builder.lua \
	oil/component.lua \
	oil/corba/giop/Channel.lua \
	oil/corba/giop/Codec.lua \
	oil/corba/giop/CodecGen.lua \
	oil/corba/giop/Exception.lua \
	oil/corba/giop/Indexer.lua \
	oil/corba/giop/Listener.lua \
	oil/corba/giop/Referrer.lua \
	oil/corba/giop/Requester.lua \
	oil/corba/giop.lua \
	oil/corba/idl/Compiler.lua \
	oil/corba/idl/Importer.lua \
	oil/corba/idl/Indexer.lua \
	oil/corba/idl/ir.lua \
	oil/corba/idl/Registry.lua \
	oil/corba/idl/sysex.lua \
	oil/corba/idl.lua \
	oil/corba/iiop/Profiler.lua \
	oil/corba/intercepted/Listener.lua \
	oil/corba/intercepted/Requester.lua \
	oil/corba/services/event/ConsumerAdmin.lua \
	oil/corba/services/event/EventFactory.lua \
	oil/corba/services/event/EventQueue.lua \
	oil/corba/services/event/ProxyPushConsumer.lua \
	oil/corba/services/event/ProxyPushSupplier.lua \
	oil/corba/services/event/SingleDeferredDispatcher.lua \
	oil/corba/services/event/SingleSynchronousDispatcher.lua \
	oil/corba/services/event/SupplierAdmin.lua \
	oil/corba/services/event.lua \
	oil/corba/services/naming.lua \
	oil/Exception.lua \
	oil/kernel/base/Acceptor.lua \
	oil/kernel/base/Channels.lua \
	oil/kernel/base/Connector.lua \
	oil/kernel/base/Dispatcher.lua \
	oil/kernel/base/DNS.lua \
	oil/kernel/base/Proxies/asynchronous.lua \
	oil/kernel/base/Proxies/protected.lua \
	oil/kernel/base/Proxies/synchronous.lua \
	oil/kernel/base/Proxies/utils.lua \
	oil/kernel/base/Proxies.lua \
	oil/kernel/base/Receiver.lua \
	oil/kernel/base/Servants.lua \
	oil/kernel/base/Sockets.lua \
	oil/kernel/cooperative/Receiver.lua \
	oil/kernel/cooperative/Sockets.lua \
	oil/kernel/cooperative/Tasks.lua \
	oil/kernel/intercepted/Listener.lua \
	oil/kernel/intercepted/Requester.lua \
	oil/kernel/lua/Dispatcher.lua \
	oil/kernel/lua/Proxies.lua \
	oil/kernel/typed/Dispatcher.lua \
	oil/kernel/typed/Proxies.lua \
	oil/kernel/typed/Servants.lua \
	oil/ludo/Channel.lua \
	oil/ludo/Codec.lua \
	oil/ludo/CodecByRef.lua \
	oil/ludo/Listener.lua \
	oil/ludo/Referrer.lua \
	oil/ludo/Requester.lua \
	oil/oo.lua \
	oil/port.lua \
	oil/properties.lua \
	oil/protocol/Channel.lua \
	oil/protocol/Listener.lua \
	oil/protocol/Request.lua \
	oil/protocol/Requester.lua \
	oil/verbose.lua \
	oil.lua )

$(PRELOAD_DIR)/oil.c: ${LOOP_HOME}/lua/preloader.lua $(LUASRC)
	$(LUABIN) $< -l "$(LUADIR)/?.lua" -m -d $(PRELOAD_DIR) -h oil.h -o oil.c $(LUASRC)
