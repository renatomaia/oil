PROJNAME = oil
LIBNAME = oilall

include base.mak

USE_LUA51=yes

PL_LUA= $(LUASRC_DIR)/preloader.lua
PL_FLAGS= -p OIL_API

INC= $(PC_INC) oilall.h oilbit.h luasocket.h
SRC= $(PC_SRC) oilall.c oilbit.c $(LUASOCKET_SRC)
EXPINC= oilall.h

ifeq "$(TEC_SYSNAME)" "Win32"
	LIBS    += wsock32
	DEFINES += OILALL_API="__declspec(dllexport)"
endif

oilall.c oilall.h: $(PL_LUA) $(INC)
	$(LUABIN) $(LUABIN_FLAGS) $< $(PL_FLAGS) -o $(@:.c=) $(filter-out $<,$^)
