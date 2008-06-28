PROJNAME = oil
LIBNAME = $(LIBPFX)oil

include base.mak

USE_LUA51=yes

SRC=    $(PC_DIR)/$(LIBPFX)oil.c oilbit.c
EXPINC= $(PC_DIR)/$(LIBPFX)oil.h oilbit.h
