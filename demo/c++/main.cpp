#include <iostream>
#include <string.h>

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <luasocket.h>
#include <oilbit.h>
}

#include "hello.hpp"

Hello::HelloWorld       *hello;
Hello::Wrapper          *wrappedHello;
Hello::Exported         *exportedClass;
Hello::Exported::Object *exportedHello;

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
	
	luaL_loadbuffer(L, "require 'oil'", 13, "OiL Require");
	lua_call(L, 0, 0);
	
	return L;
}

int main(int argc, char* argv[])
{
	hello        = new Hello::HelloWorld(true);
	wrappedHello = new Hello::Wrapper(hello);

	lua_State *state = new_oil_state();

	exportedClass = new Hello::Exported(state);
	exportedHello = exportedClass->newObject(wrappedHello);

	lua_pushliteral(state, "../hello/hello.idl");
	call_lua_function(state, "oil.loadidlfile", 1, 0);

	exportedHello->pushOnStack(state);
	lua_pushliteral(state, "IDL:Hello:1.0");
	call_lua_function(state, "oil.newobject", 2, 1);

	lua_pushliteral(state, "MyHelloC++Object");
	lua_insert(state, -2);
	lua_rawset(state, LUA_GLOBALSINDEX);
	char* code = " local file = io.open('../hello/hello.ior', 'w')"
		" if file then"
		"   file:write(_G['MyHelloC++Object']:_get_ior())"
		"   file:close()"
		" else"
		"   print(_G['MyHelloC++Object']:_get_ior())"
		" end"
		" _G['MyHelloC++Object'] = nil";
	luaL_loadbuffer(state, code, strlen(code), "write IOR");
	lua_call(state, 0, 0);

	call_lua_function(state, "oil.run", 0, 0);
	
	return 0;
}
