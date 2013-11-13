PROJNAME = oil
LIBNAME = $(LIBPFX)socket

include base.mak

SRC=    $(PC_DIR)/$(LIBPFX)socket.c $(LUASOCKET_SRC)
EXPINC= $(PC_DIR)/$(LIBPFX)socket.h luasocket.h

ifeq "$(TEC_SYSNAME)" "Win32"
	LIBS    += wsock32
	DEFINES += LUASOCKET_API="__declspec(dllexport)"
endif
