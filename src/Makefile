# makefile for building OiL
# see INSTALL for installation instructions
# see ../Makefile and luaconf.h for further customization

include ../config

PRECMP_LUA=	../lua/precompiler.lua
PRELDR_LUA=	../lua/preloader.lua

LOOP_PCK= loop/base.lua \
          loop/cached.lua \
          loop/init.lua \
          loop/multiple.lua \
          loop/scoped.lua \
          loop/simple.lua \
          loop/utils.lua \
          loop/collection/MapWithKeyArray.lua \
          loop/collection/ObjectCache.lua \
          loop/collection/OrderedSet.lua \
          loop/collection/PriorityQueue.lua \
          loop/collection/UnorderedArray.lua \
          loop/collection/UnorderedArraySet.lua \
          loop/compiler/Conditional.lua \
          loop/debug/verbose.lua \
          loop/debug/Viewer.lua \
          loop/extras/Exception.lua \
          loop/extras/Wrapper.lua
LUAIDL_PCK= luaidl/init.lua \
            luaidl/lex.lua \
            luaidl/pre.lua \
            luaidl/sin.lua
OIL_PCK= oil/assert.lua \
         oil/cdr.lua \
         oil/Exception.lua \
         oil/giop.lua \
         oil/idl.lua \
         oil/iiop.lua \
         oil/init.lua \
         oil/invoke.lua \
         oil/ior.lua \
         oil/manager.lua \
         oil/oo.lua \
         oil/orb.lua \
         oil/proxy.lua \
         oil/socket.lua \
         oil/tcode.lua \
         oil/verbose.lua \
         oil/ir/idl.lua \
         oil/ir/init.lua
SCHEDULER_PCK= scheduler/init.lua

OILBIT_INC=	oilbit.h
OILBIT_OBJ=	oilbit.o $(COMPAT_51)
OILBIT_LIB=	liboilbit.a
OILBIT_SOL=	liboilbit.$V.so

PRECMP_INC=	loop.h luaidl.h scheduler.h oil.h
PRECMP_SRC=	loop.c luaidl.c scheduler.c oil.c
PRECMP_OBJ=	loop.o luaidl.o scheduler.o oil.o
PRECMP_LIB=	libloop.a     libluaidl.a     libscheduler.a     liboil.a
PRECMP_SOL=	libloop.$V.so libluaidl.$V.so libscheduler.$V.so liboil.$V.so

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

all:	$(ALL_TRG)

o:	$(ALL_OBJ)

a:	$(ALL_LIB)

so:	$(ALL_SOL)

loop.c loop.h: $(PRECMP_LUA)
	$(LUAINT) $(PRECMP_LUA) $(PC_FLAGS) -l ../lua -f loop $(LOOP_PCK)

luaidl.c luaidl.h: $(PRECMP_LUA)
	$(LUAINT) $(PRECMP_LUA) $(PC_FLAGS) -l ../lua -f luaidl $(LUAIDL_PCK)

oil.c oil.h: $(PRECMP_LUA)
	$(LUAINT) $(PRECMP_LUA) $(PC_FLAGS) -l ../lua -f oil $(OIL_PCK)

scheduler.c scheduler.h: $(PRECMP_LUA)
	$(LUAINT) $(PRECMP_LUA) $(PC_FLAGS) -l ../lua -f scheduler $(SCHEDULER_PCK)

oilall.c oilall.h: $(PRELDR_LUA) $(PRECMP_INC) $(OILBIT_INC)
	$(LUAINT) $(PRELDR_LUA) $(PLD_FLAGS) -f oilall $(PRECMP_INC) $(OILBIT_INC)

$(OILBIT_LIB): $(OILBIT_OBJ)
	$(AR) $@ $?; $(RANLIB) $@

$(OILBIT_SOL): $(OILBIT_OBJ)
	$(LD) -shared -o $@ $(LDFLAGS) $?

$(PRELDR_LIB): $(OILBIT_OBJ) $(PRECMP_OBJ) $(PRELDR_OBJ)
	$(AR) $@ $?; $(RANLIB) $@

$(PRELDR_SOL): $(OILBIT_OBJ) $(PRECMP_OBJ) $(PRELDR_OBJ)
	$(LD) -shared -o $@ $(LDFLAGS) $?

$(OILBIN_TRG): $(COMPAT_51) $(OILBIT_OBJ) $(PRECMP_OBJ) $(PRELDR_OBJ) $(OILBIN_OBJ)
	$(CC) -o $@ -Wl,-E $(LDFLAGS) $? $(LIBS)

bundlelibs: $(OILBIT_OBJ) $(PRECMP_OBJ)
	$(AR) libloop.a loop.o            ; $(RANLIB) libloop.a
	$(AR) libluaidl.a luaidl.o        ; $(RANLIB) libluaidl.a
	$(AR) libscheduler.a scheduler.o  ; $(RANLIB) libscheduler.a
	$(AR) liboil.a oil.o $(OILBIT_OBJ); $(RANLIB) liboil.a

bundles: $(OILBIT_OBJ) $(PRECMP_OBJ)
	$(LD) -shared -o libloop.$V.so      loop.o
	$(LD) -shared -o libluaidl.$V.so    luaidl.o
	$(LD) -shared -o libscheduler.$V.so scheduler.o
	$(LD) -shared -o liboil.$V.so       oil.o $(OILBIT_OBJ)

preload: $(PRELDR_LIB) $(PRELDR_SOL)

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

# DO NOT DELETE

loop.o: loop.c loop.h
luaidl.o: luaidl.c luaidl.h
scheduler.o: scheduler.c scheduler.h
oilbit.o: oilbit.c oilbit.h
oil.o: oil.c oil.h
oilall.o: $(PRECMP_INC) $(PRELDR_INC)
console.o: $(PRELDR_INC) console-5.1.c console-5.0.2.c

# (end of Makefile)
