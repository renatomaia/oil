/*=========================================================================*\
* Library for bit-manipulation in Lua
* Roberto Ierusalimschy
\*=========================================================================*/

#include "oilbit.h"

#include <string.h>
#include <lauxlib.h>

#ifdef COMPAT_51
#include "compat-5.1.h"
#endif

typedef unsigned long Bits;

typedef unsigned long uint32;

#define luaL_checkBits(L,arg)  ((Bits)luaL_checknumber(L,arg))

static int b_and (lua_State *L) {
  Bits arg1 = luaL_checkBits(L, 1);
  Bits arg2 = luaL_checkBits(L, 2);
  lua_pushnumber(L, arg1 & arg2);
  return 1;
}

static int b_shift (lua_State *L) {
  Bits arg1, result;
  int arg2;
  arg1 = luaL_checkBits(L, 1);
  arg2 = luaL_checkint(L, 2);
  result = (arg2 >= 0) ? arg1 << arg2 : arg1 >> -arg2;
  lua_pushnumber(L, result);
  return 1;
}

static int getendianess (const char **s, int *native_out) {
  int endian;  /* 0 = little; 1 = big */
  int native = 1;
  if (*(char *)&native == 1)
    native = 0;
  if (**s == '>') {
    endian = 1;
    (*s)++;
  }
  else if (**s == '<') {
    endian = 0;
    (*s)++;
  }
  else
    endian = native;
  *native_out = native;
  return endian;
}

static int formatproperties (char c) {
  switch (c) {
    case 'B': return ((1 << 2) | 0) | 1;  /* size = 1, no sign, integer */
    case 'b': return ((1 << 2) | 2) | 1;  /* size = 1, sign, integer */
    case 'S': return ((2 << 2) | 0) | 1;  /* size = 2, no sign, integer */
    case 's': return ((2 << 2) | 2) | 1;  /* size = 2, sign, integer */
    case 'L': return ((4 << 2) | 0) | 1;  /* size = 4, no sign, integer */
    case 'l': return ((4 << 2) | 2) | 1;  /* size = 4, sign, integer */
    case 'x': return (1 << 2) | 0;  /* size =1, no integer type */
    case 'f': return (sizeof(float) << 2) | 0;
    case 'd': return (sizeof(double) << 2) | 0;
    default: return 0;  /* invalid code */
  }
}

static void putinteger (lua_State *L, luaL_Buffer *b, int arg, int endian,
                        int size) {
  unsigned char buff[4];
  lua_Number n = luaL_checknumber(L, arg);
  unsigned long value;
  unsigned char *s;
  int inc, i;
  if (n < 0) {
    value = (unsigned long)(-n);
    value = (~value) + 1;  /* 2's complement */
  }
  else
    value = (unsigned long)n;
  if (endian == 0) {
    inc = 1;
    s = buff;
  }
  else {
    inc = -1;
    s = buff+(size-1);
  }
  for (i=0; i<size; i++) {
    *s = (unsigned char)(value & 0xff);
    s += inc;
    value >>= 8;
  }
  luaL_addlstring(b, (char *)buff, size);
}

static void invertbytes (char *b, int size) {
  int i = 0;
  while (i < --size) {
    char temp = b[i];
    b[i++] = b[size];
    b[size] = temp;
  }
}

static int b_pack (lua_State *L) {
  luaL_Buffer b;
  int native;
  const char *fmt = luaL_checkstring(L, 1);
  int endian = getendianess(&fmt, &native);
  int arg = 2;
  luaL_buffinit(L, &b);
  for (; *fmt; fmt++, arg++) {
    int p = formatproperties(*fmt);
    if (p & 1)
      putinteger(L, &b, arg, endian, p>>2);
    else { 
      switch (*fmt) {
        case 'f': {
          float f = (float)luaL_checknumber(L, arg);
          if (endian != native) invertbytes((char *)&f, sizeof(f));
          luaL_addlstring(&b, (char *)&f, sizeof(f));
          break;
        }
        case 'd': {
          double d = luaL_checknumber(L, arg);
          if (endian != native) invertbytes((char *)&d, sizeof(d));
          luaL_addlstring(&b, (char *)&d, sizeof(d));
          break;
        }
        case 'x': {
          arg--;  /* undo increment */
          luaL_putchar(&b, '\0');
          break;
        }
        default: luaL_argerror(L, 1, "invalid format option");
      }
    }
  }
  luaL_pushresult(&b);
  return 1;
}

static void getinteger (lua_State *L, const char *buff, int endian, int prop) {
  unsigned long l = 0;
  int size, i, inc;
  size = prop>>2;
  if (endian == 1)
    inc = 1;
  else {
    inc = -1;
    buff += size-1;
  }
  for (i=0; i<size; i++) {
    l = (l<<8) + (unsigned char)(*buff);
    buff += inc;
  }
  if (prop & 2) {  /* signed format? */
    unsigned long mask = ~(0UL) << (size*8 - 1);
    if (l & mask) {  /* negative value? */
      l = (l^~(mask<<1)) + 1;
      lua_pushnumber(L, -(lua_Number)l);
      return;
    }
  }
  lua_pushnumber(L, l);
}

static int b_unpack (lua_State *L) {
  int native;
  const char *fmt = luaL_checkstring(L, 1);
  size_t ld;
  const char *data = luaL_checklstring(L, 2, &ld);
  int pos = luaL_optint(L, 3, 1) - 1;
  int endian = getendianess(&fmt, &native);
  int arg = 2;
  lua_settop(L, 2);
  luaL_argcheck(L, pos < (int)ld, 3, "invalid offset");
  for (; *fmt; fmt++, arg++) {
    int p = formatproperties(*fmt);
    luaL_argcheck(L, pos+(p>>2) <= (int)ld, 2, "data string too short");
    if (p & 1) {
      getinteger(L, data+pos, endian, p);
      pos += (p>>2);
    }
    else { 
      switch (*fmt) {
        case 'f': {
          float f;
          memcpy(&f, data+pos, sizeof(f));
          if (endian != native) invertbytes((char *)&f, sizeof(f));
          pos += sizeof(f);
          lua_pushnumber(L, f);
          break;
        }
        case 'd': {
          double d;
          memcpy(&d, data+pos, sizeof(d));
          if (endian != native) invertbytes((char *)&d, sizeof(d));
          pos += sizeof(d);
          lua_pushnumber(L, d);
          break;
        }
        case 'x': {
          pos++;
          break;
        }
        default: luaL_argerror(L, 1, "invalid format option");
      }
    }
  }
  return lua_gettop(L) - 2;
}

static const struct luaL_reg funcs[] = {
  {"and",    b_and},
  {"shift",  b_shift},
  {"pack",   b_pack},
  {"unpack", b_unpack},
  {NULL, NULL}
};

OIL_API int luaopen_oil_bit (lua_State *L) {
  luaL_register(L, "oil.bit", funcs);
  return 1;
}
