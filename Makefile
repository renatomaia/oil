# makefile for installing OiL
# see INSTALL for installation instructions
# see config and src/Makefile for further customization

include config

# Installation directories
INSTALL_DIR= $(INSTALL_INC) $(INSTALL_LIB) \
             $(INSTALL_LMOD) $(INSTALL_CMOD) \
             $(INSTALL_CMOD)/socket $(INSTALL_CMOD)/oil

all: $(PLAT)

$(PLATS) all o a so clibs precomp preload clean:
	cd src; $(MAKE) $@

install: clibs $(INSTALL_DIR)
	cd lua; $(INSTALL_DATA) $(TOLUA) $(INSTALL_LMOD)
	cd src; $(INSTALL_DATA) $(TOINC) $(INSTALL_INC)
	cd src; $(INSTALL_DATA) $(TOLIB) $(INSTALL_LIB)
	cd src; $(INSTALL_EXEC) $(TOSOL) $(INSTALL_LIB)
	cd $(INSTALL_LIB); for n in $(TOSOL); do $(INSTALL_COPY) $$n $${n%%.*}.so; done
	cd $(INSTALL_CMOD)/socket; $(INSTALL_COPY) $(INSTALL_LIB)/libluasocket.$(vSOCK).so core.so;
	cd $(INSTALL_CMOD)/oil   ; $(INSTALL_COPY) $(INSTALL_LIB)/liboilbit.$(vOIL).so     bit.so;

install-precomp: precomp $(INSTALL_INC) $(INSTALL_LIB) $(INSTALL_CMOD)
	cd src; $(INSTALL_DATA) $(PCINC) $(TOINC) $(INSTALL_INC)
	cd src; $(INSTALL_DATA) $(PCLIB) $(INSTALL_LIB)
	cd src; $(INSTALL_EXEC) $(PCSOL) $(INSTALL_LIB)
	cd $(INSTALL_LIB); for n in $(PCSOL); do $(INSTALL_COPY) $$n $${n%%.*}.so; done
	cd $(INSTALL_CMOD); for n in $(LLIBS); do $(INSTALL_COPY) $(INSTALL_LIB)/lib$(LIBPFX)$$n.so $${n%%.*}.so; done

install-preload: preload $(INSTALL_INC) $(INSTALL_LIB)
	cd src; $(INSTALL_DATA) $(PLINC) $(INSTALL_INC)
	cd src; $(INSTALL_DATA) $(PLLIB) $(INSTALL_LIB)
	cd src; $(INSTALL_EXEC) $(PLSOL) $(INSTALL_LIB)
	cd $(INSTALL_LIB); $(INSTALL_COPY) $(PLSOL) $(call modname,$(PLSOL)).so

local:
	$(MAKE) install INSTALL_TOP=.. INSTALL_EXEC="cp -p" INSTALL_DATA="cp -p"

no-verbose:
	for f in `find lua/ -iname "*.lua"`; do sed -i -e "s/\-\-\[\[VERBOSE\]\]/-- [[VERBOSE]]/g" $$f; done
	for f in `find lua/ -iname "*.lua"`; do sed -i -e "s/\-\-\[\[DEBUG\]\]/-- [[DEBUG]]/g" $$f; done

verbose:
	for f in `find lua/ -iname "*.lua"`; do sed -i -e "s/\-\- \[\[VERBOSE\]\]/--[[VERBOSE]]/g" $$f; done
	for f in `find lua/ -iname "*.lua"`; do sed -i -e "s/\-\- \[\[DEBUG\]\]/--[[DEBUG]]/g" $$f; done

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
	@echo "Add the following paths to the proper enviroment variables to set up OiL $(vOIL):"
	@echo ""
	@echo "LUA_PATH  += ';$(INSTALL_LMOD)/?.lua'"
	@echo "LUA_CPATH += ';$(INSTALL_CMOD)/?.so'"
	@echo ""

# echo config parameters
echo:
	@echo ""
	@echo "These are the parameters currently set in src/Makefile to build OiL $(vOIL):"
	@echo ""
	@cd src; $(MAKE) -s echo
	@echo ""
	@echo "These are the parameters currently set in Makefile to install OiL $(vOIL):"
	@echo ""
	@echo "INSTALL_TOP = $(INSTALL_TOP)"
	@echo "INSTALL_BIN = $(INSTALL_BIN)"
	@echo "INSTALL_INC = $(INSTALL_INC)"
	@echo "INSTALL_LIB = $(INSTALL_LIB)"
	@echo "INSTALL_LMOD = $(INSTALL_LMOD)"
	@echo "INSTALL_CMOD = $(INSTALL_CMOD)"
	@echo "INSTALL_EXEC = $(INSTALL_EXEC)"
	@echo "INSTALL_DATA = $(INSTALL_DATA)"
	@echo "INSTALL_COPY = $(INSTALL_COPY)"
	@echo ""

# echo private config parameters
pecho:
	@echo "TOLUA = $(TOLUA)"
	@echo "TOINC = $(TOINC)"
	@echo "TOLIB = $(TOLIB)"
	@echo "TOSOL = $(TOSOL)"
	@echo "PCINC = $(PCINC)"
	@echo "PCLIB = $(PCLIB)"
	@echo "PCSOL = $(PCSOL)"
	@echo "PLINC = $(PCINC)"
	@echo "PLLIB = $(PCLIB)"
	@echo "PLSOL = $(PCSOL)"

# echo config parameters as OiL code
# uncomment the last sed expression if you want nil instead of empty strings
lecho:
	@echo "-- installation parameters for OiL $(vOIL)"
	@echo "VERSION = '$(vOIL)'"
	@$(MAKE) echo | grep = | sed -e 's/= /= "/' -e 's/$$/"/' #-e 's/""/nil/'
	@echo "-- EOF"

# show what has changed since we unpacked
newer:
	@find . -newer MANIFEST -type f

# (end of Makefile)
