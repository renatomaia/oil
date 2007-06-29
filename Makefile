# makefile for installing OiL
# see INSTALL for installation instructions
# see config and src/Makefile for further customization

include config

# What to install.
TO_INC= oilbit.h
TO_LIB= liboilbit.a
SO_LIB= liboilbit

TO_LUA=	loop luaidl oil scheduler

BND_INC=	loop.h luaidl.h oil.h scheduler.h
BND_LIB=	libloop.a libluaidl.a liboil.a libscheduler.a
BND_SOL=	loop luaidl oil scheduler

PLD_INC=	oilall.h
PLD_LIB=	liboilall.a
PLD_SOL=	liboilall

# Installation directories
INSTALL_DIR= $(INSTALL_INC) $(INSTALL_LIB) \
             $(INSTALL_LMOD) $(INSTALL_CMOD)/oil

all: $(PLAT)

$(PLATS) a so clean:
	cd src; $(MAKE) $@

test:	all
	src/lua test/hello.lua

install: all $(INSTALL_DIR) $(INSTALL_CMOD)/oil
	cd src; $(INSTALL_EXEC) $(SO_LIB).$V.so $(INSTALL_LIB)
	cd src; $(INSTALL_DATA) $(TO_INC) $(INSTALL_INC)
	cd src; $(INSTALL_DATA) $(TO_LIB) $(INSTALL_LIB)
	cd lua; $(INSTALL_DATA) $(TO_LUA) $(INSTALL_LMOD)
	cd $(INSTALL_LIB); ln -fs $(SO_LIB).$V.so $(SO_LIB).so;
	cd $(INSTALL_CMOD)/oil; ln -fs $(INSTALL_LIB)/$(SO_LIB).$V.so bit.so;

installb: bundles $(INSTALL_DIR)
	cd src; $(INSTALL_DATA) $(BND_INC) $(INSTALL_INC)
	cd src; $(INSTALL_DATA) $(BND_LIB) $(INSTALL_LIB)
	cd src; for n in $(BND_SOL); do $(INSTALL_EXEC) lib$$n.$V.so $(INSTALL_LIB); done
	cd $(INSTALL_LIB); for n in $(BND_SOL); do ln -fs lib$$n.$V.so lib$$n.so; done
	cd $(INSTALL_CMOD); for n in $(BND_SOL); do ln -fs $(INSTALL_LIB)/lib$$n.$V.so $$n.so; done

installp: preload $(INSTALL_DIR)
	cd src; $(INSTALL_EXEC) $(PLD_SOL).$V.so $(INSTALL_LIB)
	cd src; $(INSTALL_DATA) $(PLD_INC) $(INSTALL_INC)
	cd src; $(INSTALL_DATA) $(PLD_LIB) $(INSTALL_LIB)
	cd $(INSTALL_LIB); ln -fs $(PLD_SOL).$V.so $(PLD_SOL).so;

installc: console $(INSTALL_BIN)
	$(INSTALL_EXEC) src/console $(INSTALL_BIN)/oil

local:
	$(MAKE) install INSTALL_TOP=.. INSTALL_EXEC="cp -p" INSTALL_DATA="cp -p"

none:
	@echo "Please do"
	@echo "   make PLATFORM"
	@echo "where PLATFORM is one of these:"
	@echo "   $(PLATS)"
	@echo "See INSTALL for complete instructions."

# create installation dirs
$(INSTALL_DIR):
	mkdir -p $@

env:
	@echo ""
	@echo "Add the following paths to the proper enviroment variables to set up OiL $V:"
	@echo ""
	@echo "LUA_PATH  += ';$(INSTALL_LMOD)/?.lua;$(INSTALL_LMOD)/?/init.lua'"
	@echo "LUA_CPATH += ';$(INSTALL_CMOD)/?.so'"
	@echo ""

# echo config parameters
echo:
	@echo ""
	@echo "These are the parameters currently set in src/Makefile to build OiL $V:"
	@echo ""
	@cd src; $(MAKE) -s echo
	@echo ""
	@echo "These are the parameters currently set in Makefile to install OiL $V:"
	@echo ""
	@echo "INSTALL_TOP = $(INSTALL_TOP)"
	@echo "INSTALL_BIN = $(INSTALL_BIN)"
	@echo "INSTALL_INC = $(INSTALL_INC)"
	@echo "INSTALL_LIB = $(INSTALL_LIB)"
	@echo "INSTALL_LMOD = $(INSTALL_LMOD)"
	@echo "INSTALL_CMOD = $(INSTALL_CMOD)"
	@echo "INSTALL_EXEC = $(INSTALL_EXEC)"
	@echo "INSTALL_DATA = $(INSTALL_DATA)"
	@echo ""
	@echo "See also src/oilconf.h ."
	@echo ""

# echo private config parameters
pecho:
	@echo "V = $(V)"
	@echo "TO_BIN = $(TO_BIN)"
	@echo "TO_INC = $(TO_INC)"
	@echo "TO_LIB = $(TO_LIB)"
	@echo "TO_LUA = $(TO_LUA)"

# echo config parameters as OiL code
# uncomment the last sed expression if you want nil instead of empty strings
lecho:
	@echo "-- installation parameters for OiL $V"
	@echo "VERSION = '$V'"
	@$(MAKE) echo | grep = | sed -e 's/= /= "/' -e 's/$$/"/' #-e 's/""/nil/'
	@echo "-- EOF"

# show what has changed since we unpacked
newer:
	@find . -newer MANIFEST -type f

# (end of Makefile)
