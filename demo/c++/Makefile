# makefile for O2 Pre-Compiled Test Application

OIL= ../..

include $(OIL)/config

OBJS= oilaccess.o \
      hello.o \
      main.o

INCS= -I$(LUA_INC) -I$(OIL)/src
LIBS= -L$(LUA_LIB) -L$(OIL)/src -lstdc++ -lm -ldl -llua -lluasocket -loilbit

CPPFLAGS= $(INCS)

T= servant

all: $T

$(OBJS): $(LOHS)

$T:	$(OBJS)
	$(CC) -o $@ $(OBJS) $(LIBS)
	
clean:
	rm -f $T $(OBJS)
