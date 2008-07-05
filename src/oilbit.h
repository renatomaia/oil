/*
* Copyright (c) 2006 Tecgraf, PUC-Rio.
* All rights reserved.
*
* Module that exports support for conversion of numbers between different
* binary formats and also support for bit manipulation.
*
* $Id$
*/

#ifndef OILBIT_H
#define OILBIT_H

#ifndef OIL_API
#define OIL_API
#endif

#include "lua.h"

OIL_API int luaopen_oil_bit (lua_State*);

#endif
