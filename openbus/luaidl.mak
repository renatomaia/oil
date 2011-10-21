PROJNAME= luaidl
LIBNAME= $(PROJNAME)

SRC= $(PRELOAD_DIR)/$(LIBNAME).c

LUADIR= ../lua
LUASRC= \
	$(LUADIR)/luaidl/lex.lua \
	$(LUADIR)/luaidl/pre.lua \
	$(LUADIR)/luaidl/sin.lua \
	$(LUADIR)/luaidl.lua

include ${LOOP_HOME}/openbus/base.mak
