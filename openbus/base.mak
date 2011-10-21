include ${LOOP_HOME}/openbus/base.mak

OILBIN= $(LOOPBIN) -e "package.path=package.path..[[;${OIL_HOME}/lua/?.lua]]"
IDL2LUA= ${OIL_HOME}/lua/idl2lua.lua
