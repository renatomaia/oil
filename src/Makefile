# makefile for building OiL
# see INSTALL for installation instructions
# see config and ../Makefile for further customization

include ../config

PRECMP_LUA=	../lua/precompiler.lua
PRELDR_LUA=	../lua/preloader.lua

LOOP_PCK= loop/base.lua                          \
          loop/cached.lua                        \
          loop/multiple.lua                      \
          loop/scoped.lua                        \
          loop/simple.lua                        \
          loop/table.lua                         \
          loop/collection/MapWithArrayOfKeys.lua \
          loop/collection/ObjectCache.lua        \
          loop/collection/OrderedSet.lua         \
          loop/collection/PriorityQueue.lua      \
          loop/collection/UnorderedArray.lua     \
          loop/collection/UnorderedArraySet.lua  \
          loop/compiler/Conditional.lua          \
          loop/compiler/Expression.lua           \
          loop/component/base.lua                \
          loop/component/contained.lua           \
          loop/component/dynamic.lua             \
          loop/component/intercepted.lua         \
          loop/component/introspection.lua       \
          loop/component/wrapped.lua             \
          loop/debug/Inspector.lua               \
          loop/debug/Matcher.lua                 \
          loop/debug/Verbose.lua                 \
          loop/debug/Viewer.lua                  \
          loop/object/Exception.lua              \
          loop/object/Wrapper.lua                \
          loop/serial/FileStream.lua             \
          loop/serial/Serializer.lua             \
          loop/serial/SocketStream.lua           \
          loop/serial/StringStream.lua           \
          loop/thread/CoSocket.lua               \
          loop/thread/IOScheduler.lua            \
          loop/thread/Scheduler.lua              \
          loop/thread/SocketScheduler.lua        \
          loop/thread/Timer.lua
LUAIDL_PCK= luaidl/init.lua \
            luaidl/lex.lua  \
            luaidl/pre.lua  \
            luaidl/sin.lua
OIL_PCK= oil/assert.lua                        \
         oil/component.lua                     \
         oil/Exception.lua                     \
         oil/init.lua                          \
         oil/oo.lua                            \
         oil/port.lua                          \
         oil/properties.lua                    \
         oil/verbose.lua                       \
         oil/arch/base.lua                     \
         oil/arch/cooperative.lua              \
         oil/arch/corba.lua                    \
         oil/arch/ludo.lua                     \
         oil/arch/typed.lua                    \
         oil/builder/base.lua                  \
         oil/builder/cooperative.lua           \
         oil/builder/corba.lua                 \
         oil/builder/init.lua                  \
         oil/builder/ludo.lua                  \
         oil/builder/typed.lua                 \
         oil/corba/giop/Codec.lua              \
         oil/corba/giop/Exception.lua          \
         oil/corba/giop/Indexer.lua            \
         oil/corba/giop/init.lua               \
         oil/corba/giop/Listener.lua           \
         oil/corba/giop/Messenger.lua          \
         oil/corba/giop/ProxyOps.lua           \
         oil/corba/giop/Referrer.lua           \
         oil/corba/giop/Requester.lua          \
         oil/corba/giop/ServantOps.lua         \
         oil/corba/idl/Compiler.lua            \
         oil/corba/idl/Importer.lua            \
         oil/corba/idl/Indexer.lua             \
         oil/corba/idl/init.lua                \
         oil/corba/idl/ir.lua                  \
         oil/corba/idl/Registry.lua            \
         oil/corba/iiop/Acceptor.lua           \
         oil/corba/iiop/Connector.lua          \
         oil/corba/iiop/Profiler.lua           \
         oil/corba/interceptors/ClientSide.lua \
         oil/corba/interceptors/ServerSide.lua \
         oil/cos/event/Dispatcher.lua          \
         oil/cos/event/Factory.lua             \
         oil/cos/event/init.lua                \
         oil/cos/event/Queue.lua               \
         oil/cos/event/Reaper.lua              \
         oil/cos/naming.lua                    \
         oil/kernel/base/Client.lua            \
         oil/kernel/base/Dispatcher.lua        \
         oil/kernel/base/Invoker.lua           \
         oil/kernel/base/Proxies.lua           \
         oil/kernel/base/Receiver.lua          \
         oil/kernel/base/Server.lua            \
         oil/kernel/base/Sockets.lua           \
         oil/kernel/cooperative/Invoker.lua    \
         oil/kernel/cooperative/Mutex.lua      \
         oil/kernel/cooperative/Receiver.lua   \
         oil/kernel/cooperative/Tasker.lua     \
         oil/kernel/typed/Client.lua           \
         oil/kernel/typed/Dispatcher.lua       \
         oil/kernel/typed/Proxies.lua          \
         oil/kernel/typed/Server.lua           \
         oil/ludo/Codec.lua                    \
         oil/ludo/Listener.lua                 \
         oil/ludo/Referrer.lua                 \
         oil/ludo/Requester.lua

OILBIT_INC=	oilbit.h
OILBIT_OBJ=	oilbit.o $(COMPAT_51)
OILBIT_LIB=	liboilbit.a
OILBIT_SOL=	liboilbit.$V.so

PRECMP_INC=	loop.h luaidl.h oil.h
PRECMP_SRC=	loop.c luaidl.c oil.c
PRECMP_OBJ=	loop.o luaidl.o oil.o
PRECMP_LIB=	libloop.a     libluaidl.a     liboil.a
PRECMP_SOL=	libloop.$V.so libluaidl.$V.so liboil.$V.so

PRELDR_INC=	oilall.h
PRELDR_SRC=	oilall.c
PRELDR_OBJ=	oilall.o
PRELDR_LIB=	liboilall.a
PRELDR_SOL=	liboilall.$V.so
                   
OILBIN_OBJ=	console.o
OILBIN_TRG=	console

ALL_PRE=	$(PRECMP_INC) $(PRECMP_SRC) $(PRECMP_LIB) $(PRECMP_SOL) \
        	$(PRELDR_INC) $(PRELDR_SRC) $(PRELDR_LIB) $(PRELDR_SOL) \
        	$(OILBIN_TRG)
ALL_OBJ=	$(OILBIT_OBJ) $(PRECMP_OBJ) $(PRELDR_OBJ) $(OILBIN_OBJ)
ALL_TRG=	$(OILBIT_LIB) $(OILBIT_SOL)
ALL_LIB=	$(OILBIT_LIB)
ALL_SOL=	$(OILBIT_SOL)

madefault: $(PLAT)

all:	$(ALL_TRG) bundle preload

o:	$(ALL_OBJ)

a:	$(ALL_LIB)

so:	$(ALL_SOL)

loop.c loop.h: $(PRECMP_LUA)
	$(LUAINT) $(PRECMP_LUA) $(PC_FLAGS) -l ../lua -f loop $(LOOP_PCK)

luaidl.c luaidl.h: $(PRECMP_LUA)
	$(LUAINT) $(PRECMP_LUA) $(PC_FLAGS) -l ../lua -f luaidl $(LUAIDL_PCK)

oil.c oil.h: $(PRECMP_LUA)
	$(LUAINT) $(PRECMP_LUA) $(PC_FLAGS) -l ../lua -f oil $(OIL_PCK)

oilall.c oilall.h: $(PRELDR_LUA) $(PRECMP_INC) $(OILBIT_INC)
	$(LUAINT) $(PRELDR_LUA) $(PLD_FLAGS) -f oilall $(PRECMP_INC) $(OILBIT_INC)

# OIL BIT LIBRARY

$(OILBIT_LIB): $(OILBIT_OBJ)
	$(AR) $@ $?; $(RANLIB) $@

$(OILBIT_SOL): $(OILBIT_OBJ)
	$(LD) $(LDFLAGS) -o $@ $?

# BUNDLED LIBRARIES

bundlelib: $(PRECMP_OBJ)
	$(AR) libloop.a loop.o            ; $(RANLIB) libloop.a
	$(AR) libluaidl.a luaidl.o        ; $(RANLIB) libluaidl.a
	$(AR) liboil.a oil.o $(OILBIT_OBJ); $(RANLIB) liboil.a

bundleso: $(OILBIT_OBJ) $(PRECMP_OBJ)
	$(LD) $(LDFLAGS) -o libloop.$V.so      loop.o
	$(LD) $(LDFLAGS) -o libluaidl.$V.so    luaidl.o
	$(LD) $(LDFLAGS) -o liboil.$V.so       oil.o $(OILBIT_OBJ)

bundle: bundlelib bundleso

# PRELOAD LIBRARY

$(PRELDR_LIB): $(OILBIT_OBJ) $(PRECMP_OBJ) $(PRELDR_OBJ)
	$(AR) $@ $?; $(RANLIB) $@

$(PRELDR_SOL): $(OILBIT_OBJ) $(PRECMP_OBJ) $(PRELDR_OBJ)
	$(LD) $(LDFLAGS) -o $@ $?

preload: $(PRELDR_LIB) $(PRELDR_SOL)

# STAND-ALONE CONSOLE

$(OILBIN_TRG): $(COMPAT_51) $(OILBIT_OBJ) $(PRECMP_OBJ) $(PRELDR_OBJ) $(OILBIN_OBJ)
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

macosx:
	$(MAKE) all MYCFLAGS="-fno-common $(MYCFLAGS)" \
	            MYLDFLAGS="-bundle -undefined dynamic_lookup $(MYLDFLAGS)" \
	            LD='export MACOSX_DEPLOYMENT_TARGET="10.3"; gcc'

# DO NOT DELETE

loop.o: loop.c loop.h
luaidl.o: luaidl.c luaidl.h
oilbit.o: oilbit.c oilbit.h
oil.o: oil.c oil.h
oilall.o: $(PRECMP_INC) $(PRELDR_INC)
console.o: $(PRELDR_INC) console-5.1.c console-5.0.2.c

# (end of Makefile)
