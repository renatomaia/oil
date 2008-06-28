PROJNAME = oil
LIBNAME = $(LIBPFX)luaidl

include base.mak

USE_LUA51=yes

SRC=    $(PC_DIR)/$(LIBPFX)luaidl.c
EXPINC= $(PC_DIR)/$(LIBPFX)luaidl.h
