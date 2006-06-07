#include <stdio.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <luasocket.h>

#ifndef PRELOAD
#include <oilbit.h>
#else
#include <oilall.h>
#endif

int main(int argc, char* argv[])
{
	lua_State *L;
	
	if (argc != 2) {
		fprintf(stderr, "Usage: run <script file>\n");
		return 1;
	}
	
	L = lua_open();
	luaL_openlibs(L);

	luaopen_luasocket(L); // open the LuaSocket library

#ifndef PRELOAD
	luaopen_oil_bit(L);   // open the OiL bit library (only OiL C library)
#else
	luapreload_oilall(L); // preload all OiL libraries
#endif

	if (luaL_loadfile(L, argv[1]) || lua_pcall(L, 0, 0, 0))
		fprintf(stderr, "error in file '%s'\n", argv[1]);
		
	return 0;
}
