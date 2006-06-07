#include <iostream>
#include <string.h>

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <luasocket.h>
#include <oilbit.h>
}

#ifndef TOLUA_API
#define TOLUA_API
#endif

#include "hello.hpp"
#include "bind.hpp"

Hello::HelloWorld       *hello;

////////////////////////////////////////////////////////////////////////////////

void luaL_pushfield(lua_State *L, int idx, const char *name)
{
    const char *end = strchr(name, '.');
    lua_pushvalue(L, idx);
    while (end) {
        lua_pushlstring(L, name, end - name);
        lua_gettable(L, -2);
        lua_remove(L, -2);
        if (lua_isnil(L, -1)) return;
        name = end+1;
        end = strchr(name, '.');
    }
    lua_pushstring(L, name);
    lua_gettable(L, -2);
    lua_remove(L, -2);
}

bool call_lua_function(lua_State *L, const char *name, int narg, int nres)
{
  luaL_pushfield(L, LUA_GLOBALSINDEX, name);
  int base = lua_gettop(L) - narg;  /* first arg index */
  lua_insert(L, base);  /* put function under args */
  lua_pushliteral(L, "_TRACEBACK");
  lua_rawget(L, LUA_GLOBALSINDEX);  /* get traceback function */
  lua_insert(L, base);  /* put it under chunk and args */
  int status = lua_pcall(L, narg, nres, base);
  lua_remove(L, base);  /* remove traceback function */
  if (status) {
    const char *msg = lua_tostring(L, -1);
    if (msg == NULL) msg = "(error with no message)";
    fprintf(stderr, "%s\n", msg);
    lua_pop(L, 1);
    return false;
  }
  return true;
} 

////////////////////////////////////////////////////////////////////////////////

lua_State *new_oil_state()
{
	lua_State *L = lua_open();

	luaL_openlibs(L);
	luaopen_luasocket(L);
	luaopen_oil_bit(L);
	
	return L;
}

int main(int argc, char* argv[])
{
	hello = new Hello::HelloWorld(true);

	lua_State *state = new_oil_state();
	tolua_hello_open(state);
	luaL_loadfile(state, "hello.lua");
	lua_call(L, 0, 0);

	return 0;
}

