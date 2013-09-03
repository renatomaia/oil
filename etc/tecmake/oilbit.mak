PROJNAME = oil
LIBNAME = oilbit

USE_LUA52=yes

SRC=    oilbit.c
EXPINC= oilbit.h

ifeq "$(TEC_SYSNAME)" "Win32"
	DEFINES += OIL_API="__declspec(dllexport)"
endif
