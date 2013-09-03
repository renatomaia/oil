PROJNAME = oil
LIBNAME = luasocket

include base.mak

USE_LUA52=yes

SRC=    $(LUASOCKET_SRC)
EXPINC= luasocket.h

ifeq "$(TEC_SYSNAME)" "Win32"
	LIBS    += wsock32
	DEFINES += LUASOCKET_API="__declspec(dllexport)"
endif
