PROJNAME = oil
LIBNAME = $(LIBPFX)oil

include base.mak

SRC=    $(PC_DIR)/$(LIBPFX)oil.c oilbit.c
EXPINC= $(PC_DIR)/$(LIBPFX)oil.h oilbit.h

ifeq "$(TEC_SYSNAME)" "Win32"
	DEFINES += OIL_API="__declspec(dllexport)"
endif
