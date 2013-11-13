PROJNAME = oil
LIBNAME = luasocket

include base.mak

SRC=    $(LUASOCKET_SRC)
EXPINC= luasocket.h

ifeq "$(TEC_SYSNAME)" "Win32"
	LIBS    += wsock32
	DEFINES += LUASOCKET_API="__declspec(dllexport)"
endif
