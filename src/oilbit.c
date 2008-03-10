/*
* Copyright (c) 2006 Tecgraf, PUC-Rio.
* All rights reserved.
*
* Module that exports support for conversion of numbers between different
* binary formats and also support for bit manipulation.
*/

#include "oilbit.h"

#include <string.h>
#include <lauxlib.h>

static const char svn_id[] = "$Id$";

/******************************************************************************/

typedef unsigned char byte;

#ifdef LARGE_NUMBERS
typedef unsigned long long bits;
#else
typedef unsigned long bits;
#endif

typedef void (*AddIntegerFunction)(luaL_Buffer*, lua_Number, size_t);

typedef bits (*GetIntegerFunction)(const byte*, size_t);

/******************************************************************************/

AddIntegerFunction add_integer, add_inverted_integer;
GetIntegerFunction get_integer, get_inverted_integer;

/******************************************************************************/

#define leastbyte(v,i) ((v>>(8*i))&0xff)

static bits to2comp(lua_Number value) {
	if (value < 0) return (~((bits)-value))+1;
	else           return (bits)value;
}

static lua_Number putsign(bits value, size_t size) {
#ifdef LARGE_NUMBERS
	bits mask = (~0ULL)<<(size*8-1);
#else
	bits mask = (~0UL)<<(size*8-1);
#endif
	if (value & mask) return -(lua_Number)((value ^ ~(mask<<1)) + 1);
	else              return  (lua_Number)value;
}

static int is_littleendian() {
#ifdef LARGE_NUMBERS
	bits i = 1ULL;
#else
	bits i = 1UL;
#endif
	return *((byte*)&i) == 1;
}

static void invert_bytes(byte *data, size_t size) {
	size_t i = 0;
	while (i < --size) {
		char temp = data[i];
		data[i++] = data[size];
		data[size] = temp;
	}
}

static void inverted_copy(const byte *source, byte *destiny, size_t size) {
	size_t i=0;
	for (--size; i<=size; ++i)
		destiny[i] = source[size-i];
}

/******************************************************************************/

static void add_littleendian_integer(luaL_Buffer *buffer, lua_Number number, size_t size) {
	bits value = to2comp(number);
	size_t i;
	for (i=0; i<size; ++i) {
		byte octet = (byte)leastbyte(value, i);
		luaL_addchar(buffer, *((char*)&octet));
	}
}

static void add_bigendian_integer(luaL_Buffer *buffer, lua_Number number, size_t size) {
	bits value = to2comp(number);
	int i;
	for (i=size-1; i>=0; --i) {
		byte octet = (byte)leastbyte(value, i);
		luaL_addchar(buffer, *((char*)&octet));
	}
}

static bits get_littleendian_integer(const byte *buffer, size_t size) {
	bits value = 0UL;
	int i;
	for (i=size-1; i>=0; --i) {
		value = (value<<8) + buffer[i];
	}
	return value;
}

static bits get_bigendian_integer(const byte *buffer, size_t size) {
	bits value = 0UL;
	size_t i;
	for (i=0; i<size; ++i) {
		value = (value<<8) + buffer[i];
	}
	return value;
}

/******************************************************************************/

static int b_not (lua_State *L) {
	bits arg = (bits)luaL_checknumber(L, 1);
	lua_pushnumber(L, ~arg);
	return 1;
}

static int b_and (lua_State *L) {
	bits arg1 = (bits)luaL_checknumber(L, 1);
	bits arg2 = (bits)luaL_checknumber(L, 2);
	lua_pushnumber(L, arg1 & arg2);
	return 1;
}

static int b_or (lua_State *L) {
	bits arg1 = (bits)luaL_checknumber(L, 1);
	bits arg2 = (bits)luaL_checknumber(L, 2);
	lua_pushnumber(L, arg1 | arg2);
	return 1;
}

static int b_xor (lua_State *L) {
	bits arg1 = (bits)luaL_checknumber(L, 1);
	bits arg2 = (bits)luaL_checknumber(L, 2);
	lua_pushnumber(L, arg1 ^ arg2);
	return 1;
}

static int b_shift (lua_State *L) {
	bits arg1 = (bits)luaL_checknumber(L, 1);
	lua_Integer arg2 = luaL_checkinteger(L, 2);
	lua_pushnumber(L, arg2 >= 0 ? arg1 << arg2 : arg1 >> -arg2);
	return 1;
}

/******************************************************************************/

static int b_pack(lua_State *L) {
	luaL_Buffer b;
	size_t lformat, i, last;
	const char *format = luaL_checklstring(L, 1, &lformat);
	if (lformat == 0) {
		lua_pushliteral(L, "");
		return 1;
	}
	luaL_checktype(L, 2, LUA_TTABLE);
	i    = luaL_optint(L, 3, 1);
	last = luaL_optint(L, 4, lformat);
	luaL_argcheck(L, i    > 0 && i    <= lformat, 3, "out of bounds");
	luaL_argcheck(L, last > 0 && last <= lformat, 4, "out of bounds");
	luaL_buffinit(L, &b);
	for (; i <= last; i++, format++) {
		size_t size = 1;
		lua_rawgeti(L, 2, i);
		switch (*format) {
#ifdef LARGE_NUMBERS
			case 'D':
#endif
			case 'f': case 'd': size = 0;
#ifdef LARGE_NUMBERS
			case 'g': case 'G': size *= 2;
#endif
			case 'l': case 'L': size *= 2;
			case 's': case 'S': size *= 2;
			case 'b': case 'B': {
				lua_Number number;
				luaL_argcheck(L, lua_isnumber(L, -1), 2, "table contains mismatched values");
				number = lua_tonumber(L, -1);
				lua_pop(L, 1);
				if (size) {
					add_integer(&b, number, size);
				} else {
					switch (*format) {
						case 'f': {
							float value;
							value = (float)number;
							luaL_addlstring(&b, (char*)&value, sizeof(value));
						} break;
						case 'd': {
							double value;
							value = (double)number;
							luaL_addlstring(&b, (char*)&value, sizeof(value));
						} break;
#ifdef LARGE_NUMBERS
						case 'D': {
							long double value;
							value = (long double)number;
							luaL_addlstring(&b, (char*)&value, sizeof(value));
						} break;
#endif
					}
				}
			}	break;
			case '"':
				luaL_argcheck(L, lua_isstring(L, -1), 2, "table contains mismatched values");
				luaL_addvalue(&b);
				break;
			default: luaL_error(L, "invalid format option, got '%c'", *format);
		}
	}
	luaL_pushresult(&b);
	return 1;
}

static int b_unpack(lua_State *L) {
	size_t lstream, lformat;
	const char *format = luaL_checklstring(L, 1, &lformat);
	const char *stream = luaL_checklstring(L, 2, &lstream);
	const char *strend = stream + lstream;
	const char *fmtend;
	size_t start = luaL_optint(L, 3, 1);
	size_t end   = luaL_optint(L, 4, lformat);
	size_t shift = luaL_optint(L, 5, 1);
	luaL_argcheck(L, start > 0 && start <= lformat, 3, "out of bounds");
	luaL_argcheck(L, end   > 0 && end   <= lformat, 4, "out of bounds");
	luaL_argcheck(L, shift > 0 && shift <= lstream, 5, "out of bounds");
	fmtend = format + end;
	stream += shift - 1;
	for (format += start - 1; format < fmtend; format++) {
		size_t size = 0;
		switch (*format) {
			case 'b': case 'B': size = 1; break;
			case 's': case 'S': size = 2; break;
			case 'l': case 'L': size = 4; break;
#ifdef LARGE_NUMBERS
			case 'g': case 'G': size = 8; break;
#endif
			case 'f': size = sizeof(float); break;
			case 'd': size = sizeof(double); break;
#ifdef LARGE_NUMBERS
			case 'D': size = sizeof(long double); break;
#endif
			default: luaL_error(L, "invalid format character, got '%c'", *format);
		}
		luaL_argcheck(L, stream + size <= strend, 2, "insufficient data in stream");
		switch (*format) {
			case 'b': case 's': case 'l':
#ifdef LARGE_NUMBERS
			case 'g':
#endif
				lua_pushnumber(L, putsign(get_integer((const byte*)stream, size), size));
				break;
			case 'B': case 'S': case 'L':
#ifdef LARGE_NUMBERS
			case 'G':
#endif
				lua_pushnumber(L, (lua_Number)get_integer((const byte*)stream, size));
				break;
			case 'f':
				lua_pushnumber(L, (lua_Number)*((float*)stream));
				break;
			case 'd':
				lua_pushnumber(L, (lua_Number)*((double*)stream));
				break;
#ifdef LARGE_NUMBERS
			case 'D':
				lua_pushnumber(L, (lua_Number)*((long double*)stream));
				break;
#endif
		}
		stream += size;
	}
	return 1 + start - end;
}

/******************************************************************************/

static int b_invpack(lua_State *L) {
	luaL_Buffer b;
	size_t lformat, i, last;
	const char *format = luaL_checklstring(L, 1, &lformat);
	if (lformat == 0) {
		lua_pushliteral(L, "");
		return 1;
	}
	luaL_checktype(L, 2, LUA_TTABLE);
	i    = luaL_optint(L, 3, 1);
	last = luaL_optint(L, 4, lformat);
	luaL_argcheck(L, i    > 0 && i    <= lformat, 3, "out of bounds");
	luaL_argcheck(L, last > 0 && last <= lformat, 4, "out of bounds");
	luaL_buffinit(L, &b);
	for (; i <= last; i++, format++) {
		size_t size = 1;
		lua_rawgeti(L, 2, i);
		switch (*format) {
#ifdef LARGE_NUMBERS
			case 'D':
#endif
			case 'f': case 'd': size = 0;
#ifdef LARGE_NUMBERS
			case 'g': case 'G': size *= 2;
#endif
			case 'l': case 'L': size *= 2;
			case 's': case 'S': size *= 2;
			case 'b': case 'B': {
				lua_Number number;
				luaL_argcheck(L, lua_isnumber(L, -1), 2, "table contains mismatched values");
				number = lua_tonumber(L, -1);
				lua_pop(L, 1);
				if (size) {
					add_inverted_integer(&b, number, size);
				} else {
					switch (*format) {
						case 'f': {
							float value;
							value = (float)number;
							invert_bytes((byte*)&value, sizeof(value));
							luaL_addlstring(&b, (char*)&value, sizeof(value));
						} break;
						case 'd': {
							double value;
							value = (double)number;
							invert_bytes((byte*)&value, sizeof(value));
							luaL_addlstring(&b, (char*)&value, sizeof(value));
						} break;
#ifdef LARGE_NUMBERS
						case 'D': {
							long double value;
							value = (long double)number;
							invert_bytes((byte*)&value, sizeof(value));
							luaL_addlstring(&b, (char*)&value, sizeof(value));
						} break;
#endif
					}
				}
			}	break;
			case '"':
				luaL_argcheck(L, lua_isstring(L, -1), 2, "table contains mismatched values");
				luaL_addvalue(&b);
				break;
			default: luaL_error(L, "invalid format character, got '%c'", *format);
		}
	}
	luaL_pushresult(&b);
	return 1;
}

static int b_invunpack(lua_State *L) {
	size_t lstream, lformat;
	const char *format = luaL_checklstring(L, 1, &lformat);
	const char *stream = luaL_checklstring(L, 2, &lstream);
	const char *strend = stream + lstream;
	const char *fmtend;
	size_t start = luaL_optint(L, 3, 1);
	size_t end   = luaL_optint(L, 4, lformat);
	size_t shift = luaL_optint(L, 5, 1);
	luaL_argcheck(L, start > 0 && start <= lformat, 3, "out of bounds");
	luaL_argcheck(L, end   > 0 && end   <= lformat, 4, "out of bounds");
	luaL_argcheck(L, shift > 0 && shift <= lstream, 5, "out of bounds");
	fmtend = format + end;
	stream += shift - 1;
	for (format += start - 1; format < fmtend; format++) {
		size_t size = 0;
		switch (*format) {
			case 'b': case 'B': size = 1; break;
			case 's': case 'S': size = 2; break;
			case 'l': case 'L': size = 4; break;
#ifdef LARGE_NUMBERS
			case 'g': case 'G': size = 8; break;
#endif
			case 'f': size = sizeof(float); break;
			case 'd': size = sizeof(double); break;
#ifdef LARGE_NUMBERS
			case 'D': size = sizeof(long double); break;
#endif
			default: luaL_error(L, "invalid format character, got '%c'", *format);
		}
		luaL_argcheck(L, stream + size <= strend, 2, "data string too short");
		switch (*format) {
			case 'b': case 's': case 'l':
#ifdef LARGE_NUMBERS
			case 'g':
#endif
				lua_pushnumber(L, putsign(get_inverted_integer((const byte*)stream, size), size));
				break;
			case 'B': case 'S': case 'L':
#ifdef LARGE_NUMBERS
			case 'G':
#endif
				lua_pushnumber(L, (lua_Number)get_inverted_integer((const byte*)stream, size));
				break;
			case 'f': {
				float value;
				inverted_copy((const byte*)stream, (byte*)&value, sizeof(value));
				lua_pushnumber(L, (lua_Number)value);
			} break;
			case 'd': {
				double value;
				inverted_copy((const byte*)stream, (byte*)&value, sizeof(value));
				lua_pushnumber(L, (lua_Number)value);
			} break;
#ifdef LARGE_NUMBERS
			case 'D': {
				long double value;
				inverted_copy((const byte*)stream, (byte*)&value, sizeof(value));
				lua_pushnumber(L, (lua_Number)value);
			} break;
#endif
		}
		stream += size;
	}
	return 1 + start - end;
}

/******************************************************************************/

int b_endianess(lua_State *L)
{
	if (is_littleendian()) lua_pushliteral(L, "little");
	else lua_pushliteral(L, "big");
	return 1;
}

/******************************************************************************/

static const struct luaL_reg funcs[] = {
  {"bwnot", b_not},
  {"bwand", b_and},
  {"bwor", b_or},
  {"bwxor", b_xor},
  {"bwshift", b_shift},
  {"pack", b_pack},
  {"unpack", b_unpack},
  {"invpack", b_invpack},
  {"invunpack", b_invunpack},
  {"endianess", b_endianess},
  {NULL, NULL}
};

OIL_API int luaopen_oil_bit(lua_State *L) {
	if (is_littleendian()) {
		add_integer = add_littleendian_integer;
		get_integer = get_littleendian_integer;
		add_inverted_integer = add_bigendian_integer;
		get_inverted_integer = get_bigendian_integer;
	} else {
		add_integer = add_bigendian_integer;
		get_integer = get_bigendian_integer;
		add_inverted_integer = add_littleendian_integer;
		get_inverted_integer = get_littleendian_integer;
	}
  luaL_register(L, "oil.bit", funcs);
  return 1;
}
