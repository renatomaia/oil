PROJNAME = oil
LIBNAME = $(LIBPFX)luaidl

include base.mak

SRC=    $(PC_DIR)/$(LIBPFX)luaidl.c
EXPINC= $(PC_DIR)/$(LIBPFX)luaidl.h

ifeq "$(TEC_SYSNAME)" "Win32"
	DEFINES += LUAIDL_API="__declspec(dllexport)"
endif
