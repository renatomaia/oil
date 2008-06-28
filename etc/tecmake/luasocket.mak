PROJNAME = oil
LIBNAME = luasocket

include base.mak

USE_LUA51=yes

SRC=    $(LUASOCKET_SRC)
EXPINC= luasocket.h

ifeq "$(TEC_SYSNAME)" "Win32"
	LIBS += wsock32
endif
