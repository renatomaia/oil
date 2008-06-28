PROJNAME = oil
LIBNAME = $(LIBPFX)socket

include base.mak

USE_LUA51=yes

ifeq "$(TEC_SYSNAME)" "Win32"
	LIBS += wsock32
endif

SRC=    $(PC_DIR)/$(LIBPFX)socket.c $(LUASOCKET_SRC)
EXPINC= $(PC_DIR)/$(LIBPFX)socket.h luasocket.h
