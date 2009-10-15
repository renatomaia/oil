# makefile for building OiL
# see INSTALL for installation instructions
# see config and ../Makefile for further customization

include ../config

PRECMP_LUA=	../lua/precompiler.lua
PRELDR_LUA=	../lua/preloader.lua

LUASOCKET_OBJ= \
	luasocket.o \
	timeout.o \
	buffer.o \
	io.o \
	auxiliar.o \
	options.o \
	inet.o \
	tcp.o \
	udp.o \
	except.o \
	select.o \
	usocket.o
OILBIT_OBJ= oilbit.o

LOOP_LUA= $(addprefix ../lua/, \
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
LUAIDL_LUA= $(addprefix ../lua/, \
	luaidl.lua \
	luaidl/lex.lua \
	luaidl/pre.lua \
	luaidl/sin.lua \
)
SOCKET_LUA= $(addprefix ../lua/, \
	socket.lua \
	socket/ftp.lua \
	socket/http.lua \
	socket/smtp.lua \
	socket/tp.lua \
	socket/url.lua \
)
OIL_LUA= $(addprefix ../lua/, \
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
	oil/corba/giop/Codec.lua \
	oil/corba/giop/CodecGen.lua \
	oil/corba/giop/Exception.lua \
	oil/corba/giop/Indexer.lua \
	oil/corba/giop/Listener.lua \
	oil/corba/giop/Messenger.lua \
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
	oil/kernel/base/Proxies/asynchronous.lua \
	oil/kernel/base/Proxies/protected.lua \
	oil/kernel/base/Proxies/synchronous.lua \
	oil/kernel/base/Proxies/utils.lua \
	oil/kernel/base/Proxies.lua \
	oil/kernel/base/Receiver.lua \
	oil/kernel/base/Servants.lua \
	oil/kernel/base/Sockets.lua \
	oil/kernel/cooperative/Receiver.lua \
	oil/kernel/intercepted/Listener.lua \
	oil/kernel/intercepted/Requester.lua \
	oil/kernel/lua/Dispatcher.lua \
	oil/kernel/lua/Proxies.lua \
	oil/kernel/typed/Dispatcher.lua \
	oil/kernel/typed/Proxies.lua \
	oil/kernel/typed/Servants.lua \
	oil/ludo/Codec.lua \
	oil/ludo/CodecByRef.lua \
	oil/ludo/Listener.lua \
	oil/ludo/Referrer.lua \
	oil/ludo/Requester.lua \
	oil/oo.lua \
	oil/port.lua \
	oil/properties.lua \
	oil/verbose.lua \
	oil.lua \
)

PCSRC= $(PCINC:.h=.c)
PCOBJ= $(PCINC:.h=.o)

PLSRC= $(PLINC:.h=.c)
PLOBJ= $(PLINC:.h=.o)

ALL_PRE=	$(PCINC) $(PCSRC) \
        	$(PLINC) $(PLSRC)
ALL_OBJ=	$(LUASOCKET_OBJ) $(OILBIT_OBJ) \
        	$(PCOBJ) $(PLOBJ) $(OILBIN_OBJ)
ALL_LIB=	$(TOLIB) $(PCLIB) $(PLLIB)
ALL_SOL=	$(TOSOL) $(PCSOL) $(PLSOL)
ALL_TRG=	$(ALL_LIB) $(ALL_SOL)

default: $(PLAT)

all:	$(ALL_TRG)

o:	$(ALL_OBJ)

a:	$(ALL_LIB)

so:	$(ALL_SOL)

clibs: $(TOLIB) $(TOSOL)

precomp: $(PCLIB) $(PCSOL)

preload: $(PLLIB) $(PLSOL)

# Script Compilation

$(LIBPFX)loop.c: $(PRECMP_LUA) $(LOOP_LUA)
	$(LUA) $< $(PC_FLAGS) -p LOOP_API      -o $(@:.c=) $(filter-out $<,$^)

$(LIBPFX)luaidl.c: $(PRECMP_LUA) $(LUAIDL_LUA)
	$(LUA) $< $(PC_FLAGS) -p LUAIDL_API    -o $(@:.c=) $(filter-out $<,$^)

$(LIBPFX)socket.c: $(PRECMP_LUA) $(SOCKET_LUA)
	$(LUA) $< $(PC_FLAGS) -p LUASOCKET_API -o $(@:.c=) $(filter-out $<,$^)

$(LIBPFX)oil.c: $(PRECMP_LUA) $(OIL_LUA)
	$(LUA) $< $(PC_FLAGS) -p OIL_API       -o $(@:.c=) $(filter-out $<,$^)

# Static Libraies

lib$(LUASOCKET).a: $(LUASOCKET_OBJ)
	$(AR) $@ $?; $(RANLIB) $@

lib$(OILBIT).a: $(OILBIT_OBJ)
	$(AR) $@ $?; $(RANLIB) $@

# Dynamic Libraies

lib$(LUASOCKET).$(vSOCK).so: $(LUASOCKET_OBJ)
	$(LD) $(LDFLAGS) -o $@ $?

lib$(OILBIT).$(vOIL).so: $(OILBIT_OBJ)
	$(LD) $(LDFLAGS) -o $@ $?

# Precompiled Static Libraries

lib$(LIBPFX)loop.a: $(LIBPFX)loop.o
	$(AR) $@ $?; $(RANLIB) $@

lib$(LIBPFX)luaidl.a: $(LIBPFX)luaidl.o
	$(AR) $@ $?; $(RANLIB) $@

lib$(LIBPFX)socket.a: $(LIBPFX)socket.o $(LUASOCKET_OBJ)
	$(AR) $@ $?; $(RANLIB) $@

lib$(LIBPFX)oil.a: $(LIBPFX)oil.o $(OILBIT_OBJ)
	$(AR) $@ $?; $(RANLIB) $@

# Precompiled Dynamic Libraries

lib$(LIBPFX)loop.$(vLOOP).so: $(LIBPFX)loop.o
	$(LD) $(LDFLAGS) -o $@ $^

lib$(LIBPFX)luaidl.$(vLIDL).so: $(LIBPFX)luaidl.o
	$(LD) $(LDFLAGS) -o $@ $^

lib$(LIBPFX)socket.$(vSOCK).so: $(LIBPFX)socket.o $(LUASOCKET_OBJ)
	$(LD) $(LDFLAGS) -o $@ $^

lib$(LIBPFX)oil.$(vOIL).so: $(LIBPFX)oil.o $(OILBIT_OBJ)
	$(LD) $(LDFLAGS) -o $@ $^

# Preload Libraries

$(PLSRC): $(PRELDR_LUA) $(TOINC) $(PCINC)
	$(LUA) $< $(PL_FLAGS) -o $(@:.c=) $(filter-out $<,$^)

$(PLLIB): $(PCOBJ) $(PLOBJ) $(LUASOCKET_OBJ) $(OILBIT_OBJ)
	$(AR) $@ $?; $(RANLIB) $@

$(PLSOL): $(PCOBJ) $(PLOBJ) $(LUASOCKET_OBJ) $(OILBIT_OBJ)
	$(LD) $(LDFLAGS) -o $@ $^

# STAND-ALONE CONSOLE

$(OILBIN_TRG): $(OILBIT_OBJ) $(PCOBJ) $(PLOBJ) $(OILBIN_OBJ)
	$(CC) $(LDFLAGS) -o $@ $? $(LIBS)

clean:
	$(RM) $(ALL_TRG) $(ALL_OBJ) $(ALL_PRE)

depend:
	$(CC) $(CFLAGS) -MM l*.c print.c

echo:
	@echo "CC = $(CC)"
	@echo "CFLAGS = $(CFLAGS)"
	@echo "AR = $(AR)"
	@echo "RANLIB = $(RANLIB)"
	@echo "RM = $(RM)"
	@echo "MYCFLAGS = $(MYCFLAGS)"
	@echo "MYLDFLAGS = $(MYLDFLAGS)"
	@echo "MYLIBS = $(MYLIBS)"

# convenience targets for usual platforms

none:
	@echo "Please choose a platform: $(PLATS)"

linux:
	$(MAKE) all LD="gcc" MYCFLAGS="-fpic $(MYCFLAGS)" \
	            MYLDFLAGS="-Wl,-E -O -shared $(MYLDFLAGS)"
#	$(MAKE) console LD="gcc" MYCFLAGS="-fpic $(MYCFLAGS)" \
#	            MYLDFLAGS="-Wl,-E -O $(MYLDFLAGS)"

solaris:
	$(MAKE) all LD="gcc" MYCFLAGS="-fpic $(MYCFLAGS)" \
	            MYLDFLAGS="-O -shared $(MYLDFLAGS)"

macosx:
	$(MAKE) all MYCFLAGS="-fno-common $(MYCFLAGS)" \
	            MYLDFLAGS="-bundle -undefined dynamic_lookup $(MYLDFLAGS)" \
	            LD='export MACOSX_DEPLOYMENT_TARGET="10.3"; gcc'

# DO NOT DELETE

$(LIBPFX)loop.o: $(LIBPFX)loop.h $(LIBPFX)loop.c
$(LIBPFX)luaidl.o: $(LIBPFX)luaidl.h $(LIBPFX)luaidl.c
$(LIBPFX)socket.o: $(LIBPFX)socket.h $(LIBPFX)socket.c
$(LIBPFX)oil.o: $(LIBPFX)oil.h $(LIBPFX)oil.c
$(PLOBJ): $(PCINC) $(PLINC)
console.o: $(PLINC) console.c
oilbit.o: oilbit.h oilbit.c
auxiliar.o: auxiliar.c auxiliar.h
buffer.o: buffer.c buffer.h io.h timeout.h
except.o: except.c except.h
inet.o: inet.c inet.h socket.h io.h timeout.h usocket.h
io.o: io.c io.h timeout.h
luasocket.o: luasocket.c luasocket.h auxiliar.h except.h timeout.h \
  buffer.h io.h inet.h socket.h usocket.h tcp.h udp.h select.h
options.o: options.c auxiliar.h options.h socket.h io.h timeout.h \
  usocket.h inet.h
select.o: select.c socket.h io.h timeout.h usocket.h select.h
tcp.o: tcp.c auxiliar.h socket.h io.h timeout.h usocket.h inet.h \
  options.h tcp.h buffer.h
timeout.o: timeout.c auxiliar.h timeout.h
udp.o: udp.c auxiliar.h socket.h io.h timeout.h usocket.h inet.h \
  options.h udp.h
unix.o: unix.c auxiliar.h socket.h io.h timeout.h usocket.h options.h \
  unix.h buffer.h
usocket.o: usocket.c socket.h io.h timeout.h usocket.h

# (end of Makefile)
