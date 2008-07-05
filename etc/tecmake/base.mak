#file "config.mak"

LUASRC_DIR= ../lua
LUABIN_FLAGS= -epackage.path=[[$(LUASRC_DIR)/?.lua]]

LIBPFX= lualib

PC_DIR= ../obj/$(LIBNAME)/$(TEC_UNAME)
PC_LUA= $(LUASRC_DIR)/precompiler.lua
PC_FLAGS= -p OIL_API -l "$(LUASRC_DIR)/?.lua" -d $(PC_DIR)

# Precompiled Files

PC_FILES= $(addprefix $(PC_DIR)/$(LIBPFX),luaidl loop socket oil)
PC_INC= $(addsuffix .h,$(PC_FILES))
PC_SRC= $(addsuffix .c,$(PC_FILES))

# Object Files

LUASOCKET_SRC= \
	luasocket.c \
	timeout.c \
	buffer.c \
	io.c \
	auxiliar.c \
	options.c \
	inet.c \
	tcp.c \
	udp.c \
	except.c \
	select.c
ifeq "$(TEC_SYSNAME)" "Win32"
	LUASOCKET_SRC += wsocket.c
else
	LUASOCKET_SRC += usocket.c
endif

# Script Files

LOOP_LUA= $(addprefix $(LUASRC_DIR)/, \
	loop/base.lua \
	loop/cached.lua \
	loop/collection/MapWithArrayOfKeys.lua \
	loop/collection/ObjectCache.lua \
	loop/collection/OrderedSet.lua \
	loop/collection/PriorityQueue.lua \
	loop/collection/UnorderedArray.lua \
	loop/collection/UnorderedArraySet.lua \
	loop/compiler/Arguments.lua \
	loop/compiler/Conditional.lua \
	loop/compiler/Expression.lua \
	loop/component/base.lua \
	loop/component/contained.lua \
	loop/component/dynamic.lua \
	loop/component/intercepted.lua \
	loop/component/wrapped.lua \
	loop/debug/Inspector.lua \
	loop/debug/Matcher.lua \
	loop/debug/Verbose.lua \
	loop/debug/Viewer.lua \
	loop/multiple.lua \
	loop/object/Exception.lua \
	loop/object/Publisher.lua \
	loop/object/Wrapper.lua \
	loop/scoped.lua \
	loop/serial/FileStream.lua \
	loop/serial/Serializer.lua \
	loop/serial/SocketStream.lua \
	loop/serial/StringStream.lua \
	loop/simple.lua \
	loop/table.lua \
	loop/thread/CoSocket.lua \
	loop/thread/IOScheduler.lua \
	loop/thread/Scheduler.lua \
	loop/thread/SocketScheduler.lua \
	loop/thread/Timer.lua \
)
LUAIDL_LUA= $(addprefix $(LUASRC_DIR)/, \
	luaidl.lua \
	luaidl/lex.lua \
	luaidl/pre.lua \
	luaidl/sin.lua \
)
SOCKET_LUA= $(addprefix $(LUASRC_DIR)/, \
	socket.lua \
	socket/ftp.lua \
	socket/http.lua \
	socket/smtp.lua \
	socket/tp.lua \
	socket/url.lua \
)
OIL_LUA= $(addprefix $(LUASRC_DIR)/, \
	oil.lua \
	oil/arch.lua \
	oil/arch/base.lua \
	oil/arch/cooperative.lua \
	oil/arch/corba.lua \
	oil/arch/ludo.lua \
	oil/arch/typed.lua \
	oil/assert.lua \
	oil/builder.lua \
	oil/builder/base.lua \
	oil/builder/cooperative.lua \
	oil/builder/corba.lua \
	oil/builder/gencode.lua \
	oil/builder/intercepted.lua \
	oil/builder/ludo.lua \
	oil/builder/typed.lua \
	oil/compat.lua \
	oil/component.lua \
	oil/corba/giop.lua \
	oil/corba/giop/Codec.lua \
	oil/corba/giop/CodecGen.lua \
	oil/corba/giop/Exception.lua \
	oil/corba/giop/Indexer.lua \
	oil/corba/giop/Listener.lua \
	oil/corba/giop/Messenger.lua \
	oil/corba/giop/ProxyOps.lua \
	oil/corba/giop/Referrer.lua \
	oil/corba/giop/Requester.lua \
	oil/corba/giop/ServantOps.lua \
	oil/corba/idl.lua \
	oil/corba/idl/Compiler.lua \
	oil/corba/idl/Importer.lua \
	oil/corba/idl/Indexer.lua \
	oil/corba/idl/ir.lua \
	oil/corba/idl/Registry.lua \
	oil/corba/idl/sysex.lua \
	oil/corba/iiop/Profiler.lua \
	oil/corba/interceptors/ClientSide.lua \
	oil/corba/interceptors/ServerSide.lua \
	oil/corba/services/event.lua \
	oil/corba/services/event/ConsumerAdmin.lua \
	oil/corba/services/event/EventFactory.lua \
	oil/corba/services/event/EventQueue.lua \
	oil/corba/services/event/ProxyPushConsumer.lua \
	oil/corba/services/event/ProxyPushSupplier.lua \
	oil/corba/services/event/SingleDeferredDispatcher.lua \
	oil/corba/services/event/SingleSynchronousDispatcher.lua \
	oil/corba/services/event/SupplierAdmin.lua \
	oil/corba/services/naming.lua \
	oil/Exception.lua \
	oil/kernel/base/Acceptor.lua \
	oil/kernel/base/Client.lua \
	oil/kernel/base/Connector.lua \
	oil/kernel/base/Dispatcher.lua \
	oil/kernel/base/Invoker.lua \
	oil/kernel/base/Proxies.lua \
	oil/kernel/base/Receiver.lua \
	oil/kernel/base/Server.lua \
	oil/kernel/base/Sockets.lua \
	oil/kernel/cooperative/Invoker.lua \
	oil/kernel/cooperative/Mutex.lua \
	oil/kernel/cooperative/Receiver.lua \
	oil/kernel/typed/Client.lua \
	oil/kernel/typed/Dispatcher.lua \
	oil/kernel/typed/Proxies.lua \
	oil/kernel/typed/Server.lua \
	oil/ludo/Codec.lua \
	oil/ludo/Listener.lua \
	oil/ludo/Referrer.lua \
	oil/ludo/Requester.lua \
	oil/oo.lua \
	oil/port.lua \
	oil/properties.lua \
	oil/verbose.lua \
)

# Script Compilation

$(PC_DIR)/$(LIBPFX)loop.c: $(PC_LUA) $(LOOP_LUA)
	$(LUABIN) $(LUABIN_FLAGS) $< $(PC_FLAGS) -o $(LIBPFX)loop $(filter-out $<,$^)

$(PC_DIR)/$(LIBPFX)luaidl.c: $(PC_LUA) $(LUAIDL_LUA)
	$(LUABIN) $(LUABIN_FLAGS) $< $(PC_FLAGS) -o $(LIBPFX)luaidl $(filter-out $<,$^)

$(PC_DIR)/$(LIBPFX)socket.c: $(PC_LUA) $(SOCKET_LUA)
	$(LUABIN) $(LUABIN_FLAGS) $< $(PC_FLAGS) -o $(LIBPFX)socket $(filter-out $<,$^)

$(PC_DIR)/$(LIBPFX)oil.c: $(PC_LUA) $(OIL_LUA)
	$(LUABIN) $(LUABIN_FLAGS) $< $(PC_FLAGS) -o $(LIBPFX)oil $(filter-out $<,$^)

# Compiled Script Headers

$(LIBPFX)loop.h: $(PC_DIR)/$(LIBPFX)loop.c
	mv $(^:.c:.h) $@

$(LIBPFX)luaidl.h: $(PC_DIR)/$(LIBPFX)luaidl.c
	mv $(^:.c:.h) $@

$(LIBPFX)socket.h: $(PC_DIR)/$(LIBPFX)socket.c
	mv $(^:.c:.h) $@

$(LIBPFX)oil.h: $(PC_DIR)/$(LIBPFX)oil.c
	mv $(^:.c:.h) $@
