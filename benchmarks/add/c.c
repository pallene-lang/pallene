#include "lua.h"
#include "lauxlib.h"

static int l_add(lua_State *L) {
    lua_Number a = luaL_checknumber(L, 1);
    lua_Number b = luaL_checknumber(L, 2);
    lua_pushnumber(L, a + b);
    return 1;
}

static const luaL_Reg lib[] = {
    {"add", l_add},
    {NULL, NULL}
};

int luaopen_benchmarks_add_c(lua_State *L) {
    luaL_newlib(L, lib);
    return 1;
}
