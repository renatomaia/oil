PROJNAME= luaidl
LIBNAME= $(PROJNAME)

ifeq "$(TEC_SYSNAME)" "SunOS"
  USE_CC=Yes
  NO_LOCAL_LD=Yes
  AR=CC
  CFLAGS+= -KPIC
  STDLFLAGS= -xar
  CPPFLAGS= +p -KPIC -mt -D_REENTRANT
  ifeq ($(TEC_WORDSIZE), TEC_64)
    FLAGS+= -m64
    LFLAGS+= -m64
    STDLFLAGS+= -m64
  endif
  STDLFLAGS+= -o
endif

PRELOAD_DIR= ../obj/${TEC_UNAME}
INCLUDES= . $(PRELOAD_DIR)

SRC= ${PRELOAD_DIR}/luaidl.c

LUADIR= ../lua
LUASRC= $(addprefix $(LUADIR)/, \
	luaidl/lex.lua \
	luaidl/pre.lua \
	luaidl/sin.lua \
	luaidl.lua )

${PRELOAD_DIR}/luaidl.c: ${LOOP_HOME}/lua/preloader.lua $(LUASRC)
	$(LUABIN) $< -l "$(LUADIR)/?.lua" -m -d $(PRELOAD_DIR) -h luaidl.h -o luaidl.c $(LUASRC)

USE_LUA51= YES
NO_LUALINK=YES
USE_NODEPEND=YES

