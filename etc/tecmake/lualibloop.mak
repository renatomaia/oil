PROJNAME = oil
LIBNAME = $(LIBPFX)loop

include base.mak

USE_LUA52=yes

SRC=    $(PC_DIR)/$(LIBPFX)loop.c
EXPINC= $(PC_DIR)/$(LIBPFX)loop.h

ifeq "$(TEC_SYSNAME)" "Win32"
	DEFINES += LOOP_API="__declspec(dllexport)"
endif
