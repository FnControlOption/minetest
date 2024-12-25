#pragma once

#include "lua.h"

#define LUA_IOLIBNAME	"io"

LUALIB_API int (luaopen_io) (lua_State *L);
