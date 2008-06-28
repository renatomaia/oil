PROJNAME = oil
LIBNAME = $(LIBPFX)loop

include base.mak

USE_LUA51=yes

SRC=    $(PC_DIR)/$(LIBPFX)loop.c
EXPINC= $(PC_DIR)/$(LIBPFX)loop.h
