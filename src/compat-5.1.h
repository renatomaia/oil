/*
** Compat-5.1
** Code stripped from Lua 5.1 alpha
*/

#ifndef COMPAT_H

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#define LUA_QL(x)	"'" x "'"
#define LUA_QS		LUA_QL("%s")

#define luaL_Reg	luaL_reg

LUA_API void  (lua_getfield) (lua_State *L, int idx, const char *k);
LUA_API void  (lua_setfield) (lua_State *L, int idx, const char *k);

LUALIB_API const char *luaL_findtable (lua_State *L, int idx, const char *fname, int szhint);
LUALIB_API void (luaL_register) (lua_State *L, const char *libname, const luaL_Reg *l);
LUALIB_API void luaI_openlib (lua_State *L, const char *libname, const luaL_Reg *l, int nup);

#define luaL_openlib	luaI_openlib

#endif
